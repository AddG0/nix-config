{
  pkgs,
  lib,
  config,
  ...
}: let
  sshPort = config.hostSpec.networking.ports.tcp.ssh;

  # Sops needs access to the keys before the persist dirs are even mounted; so
  # just persisting the keys won't work, we must point at /persist
  #FIXME-impermanence refactor this to how fb did it
  hasOptinPersistence = false;
in {
  services.openssh = {
    enable = true;
    ports = [sshPort];

    settings = {
      # Publickey is the only acceptable auth method. PasswordAuthentication
      # alone leaves PAM-driven keyboard-interactive as a probe surface;
      # KbdInteractiveAuthentication=no + AuthenticationMethods=publickey
      # close that off explicitly.
      # Source: Mozilla OpenSSH Guidelines (Modern) —
      #   https://infosec.mozilla.org/guidelines/openssh
      # Source: NixOS Wiki — https://wiki.nixos.org/wiki/SSH
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      AuthenticationMethods = "publickey";

      # Conditional root login based on Colmena enable flag. mkOverride 999
      # is one priority above mkDefault — beats the upstream nixpkgs
      # google-compute-config (which sets mkDefault "prohibit-password")
      # without needing per-host mkForce, while still being overridable by
      # any plain host-level assignment (priority 100).
      PermitRootLogin = lib.mkOverride 999 (
        if config.hostSpec.colmena.enable
        then "prohibit-password"
        else "no"
      );

      # VERBOSE logs the SHA256 fingerprint of the key used to authenticate.
      # Without it, sshd records "Accepted publickey for $user" but not which
      # key — making post-hoc audits (which key got used, from where) much
      # harder. Trades a small amount of log volume for forensic traceability.
      # Source: Mozilla OpenSSH Guidelines (Modern), CIS Benchmark §5.2
      LogLevel = "VERBOSE";

      # Brute-force / connection-flood resistance.
      # MaxAuthTries: 3 auth attempts per TCP connection (default 6).
      # LoginGraceTime: kill pre-auth connections after 30s (default 120) —
      #   slow-loris protection. CIS-Ubuntu suggests 60, 2026 guides suggest
      #   20; 30 picked as middle ground.
      # MaxSessions: cap multiplexed channels per auth'd connection. CIS's
      #   ≤4 breaks VS Code Remote-SSH (each terminal pane, port forward,
      #   file-watcher, and the server process is a channel — typically 6–12).
      #   15 matches Microsoft's worked example in their MaxStartups/MaxSessions
      #   troubleshooting guide for multiplexing environments, leaving headroom
      #   over the OpenSSH default of 10.
      # PerSourcePenalties: OpenSSH 9.8+ native rate-limiting that progressively
      #   penalizes misbehaving source IPs in-daemon — supersedes fail2ban for
      #   most cases (no extra daemon, no iptables writes).
      # Source: CIS Benchmark §5.2; NixOS Wiki (PerSourcePenalties);
      #   Microsoft Learn — https://learn.microsoft.com/en-us/troubleshoot/windows-server/system-management-components/troubleshoot-openssh-connection-issues-maxstartups-maxsessions
      #   2026 hardening guides — https://ittavern.com/ssh-server-hardening/,
      #   https://linuxize.com/post/ssh-hardening-best-practices/
      MaxAuthTries = 3;
      LoginGraceTime = 30;
      MaxSessions = 15;
      PerSourcePenalties = "yes";

      # Reap half-open / abandoned sessions. Server sends a keepalive every
      # 5 minutes; after 2 missed replies (~10 min total) the connection is
      # dropped. Prevents ghost sessions accumulating on flaky links or after
      # laptops close.
      # Source: CIS Benchmark §5.2; 2026 hardening guides
      ClientAliveInterval = 300;
      ClientAliveCountMax = 2;

      # Automatically remove stale sockets
      StreamLocalBindUnlink = "yes";
      # Disable remote port forwarding to external interfaces (security hardening)
      GatewayPorts = "no";
    };

    # Host keys identify the SERVER to connecting clients (not users to the
    # server — that's authorized_keys). NixOS auto-generates anything listed
    # here on first boot via sshd-keygen-start.service if the file is missing.
    #
    # Deliberately ed25519-only:
    # - Modern, fast, 256-bit; smaller side-channel surface than RSA.
    # - Preferred by Mozilla OpenSSH Guidelines (Modern).
    # - Skipping RSA is a security/compat trade-off: legacy SSH relays that
    #   only know how to verify ssh-rsa host keys (Google's SSH-in-browser,
    #   IAP tunnel, older corporate jumphosts) cannot reach this server.
    #   Direct `ssh user@host` and `gcloud compute ssh --internal-ip` are
    #   unaffected — they negotiate ed25519 fine.
    # - To restore legacy-client reach, add a second entry with
    #   `type = "rsa"; bits = 4096;` — accepting a weaker host key in
    #   exchange for compatibility.
    #
    # Path note: when `hasOptinPersistence` is true the key sits under
    # `/persist/etc/ssh/...` so it survives an ephemeral root (impermanence).
    # Currently false (see FIXME above) — key lives at the standard
    # `/etc/ssh/...` location, which means it's regenerated if the disk is
    # wiped. Mitigation: known_hosts churn on rebuild. Acceptable for now;
    # the FIXME tracks moving to /persist properly.
    hostKeys = [
      {
        path = "${lib.optionalString hasOptinPersistence "/persist"}/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
  };

  # yubikey login / sudo
  # NOTE: We use rssh because sshAgentAuth is old and doesn't support yubikey:
  # https://github.com/jbeverly/pam_ssh_agent_auth/issues/23
  # https://github.com/z4yx/pam_rssh
  security.pam.services.sudo = {config, ...}: {
    rules.auth.rssh = {
      order = config.rules.auth.ssh_agent_auth.order - 1;
      control = "sufficient";
      modulePath = "${pkgs.pam_rssh}/lib/libpam_rssh.so";
      settings.authorized_keys_command = pkgs.writeShellScript "get-authorized-keys" ''
        cat "/etc/ssh/authorized_keys.d/$1"
      '';
    };
  };

  networking.firewall.allowedTCPPorts = [sshPort];
}
