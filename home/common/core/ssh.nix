{
  config,
  hostSpec,
  lib,
  ...
}: let
  cfg = config.programs.ssh;

  # Public halves of the keys served by the 1Password SSH agent.
  # Public keys aren't secret — committed under hosts/common/users/primary/keys.
  # The agent serves the private half by matching pubkey fingerprint.
  # Every *.pub file in that directory is auto-materialized at ~/.ssh/<name>.pub.
  primaryKeys = lib.custom.relativeToHosts "common/users/primary/keys";
  sshPublicKeyEntries = lib.attrsets.mapAttrs' (
    filename: _:
      lib.nameValuePair ".ssh/${filename}" {source = "${primaryKeys}/${filename}";}
  ) (builtins.readDir primaryKeys);

  hosts = [
    "ghost"
  ];
  # add my domain to each host
  hostDomains = map (h: "${h}.${config.hostSpec.domain}") hosts;
  hostAll = hosts ++ hostDomains;
  hostString = lib.concatStringsSep " " hostAll;

  # Generate SSH host entries from hostsAddr
  hostsAddrConfig =
    lib.attrsets.mapAttrs' (host: value: {
      name = host;
      value = lib.hm.dag.entryAfter ["ssh-hosts"] {
        inherit host;
        hostname = value.ipv4;
        port = hostSpec.networking.ports.tcp.ssh;
        forwardAgent = true;
      };
    })
    hostSpec.networking.hostsAddr;
  # VS Code Remote SSH workaround for hosts using nushell as login shell.
  # Generates <host>-vscode aliases for all hosts in hostsAddr.
  # Use these aliases in VS Code with remote.SSH.enableRemoteCommand setting.
  # Below is only needed if we're defaulting to a non posix shell.
  # vsCodeHostsConfig =
  #   lib.attrsets.mapAttrs' (host: value: {
  #     name = "${host}-vscode";
  #     value = lib.hm.dag.entryAfter ["ssh-hosts"] {
  #       host = "${host}-vscode";
  #       hostname = value.ipv4;
  #       port = hostSpec.networking.ports.tcp.ssh;
  #       extraOptions = {
  #         RemoteCommand = "bash -l";
  #         RequestTTY = "no";
  #       };
  #     };
  #   })
  #   hostSpec.networking.hostsAddr;
in {
  options.programs.ssh.enableTraditionalAgent = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Whether to enable the traditional SSH agent via oh-my-zsh plugin.
      Set to false when using alternative SSH agents like 1Password.
    '';
  };

  config = {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;

      extraConfig = ''
        AddKeysToAgent yes
      '';

      matchBlocks =
        {
          "*" = {
            controlMaster = "auto";
            # %n (alias as typed) instead of %h (resolved hostname) so two
            # match blocks that share HostName get distinct mux sockets.
            controlPath = "~/.ssh/sockets/S.%r@%n:%p";
            controlPersist = "10m";
            serverAliveInterval = 60;
            serverAliveCountMax = 3;
            # Try primary first, then fall back to other agent keys.
            identityFile = "~/.ssh/primary.pub";
            extraOptions = {
              TCPKeepAlive = "yes";
            };
          };

          "ssh-hosts" = lib.hm.dag.entryAfter ["*"] {
            host = "${hostString}";
            forwardAgent = true;
          };

          "git" = {
            host = "gitlab.com github.com";
            user = "git";
            identityFile = "~/.ssh/primary.pub";
            identitiesOnly = true;
          };
        }
        // hostsAddrConfig;
    };

    programs.zsh.oh-my-zsh.plugins =
      lib.optional cfg.enableTraditionalAgent "ssh-agent"
      ++ ["ssh"];

    # Enable agent-forwarding before oh-my-zsh loads (respects forwarded agents)
    programs.zsh.oh-my-zsh.extraConfig = lib.mkIf cfg.enableTraditionalAgent ''
      zstyle :omz:plugins:ssh-agent agent-forwarding yes
    '';

    home.file =
      {
        # Ensures ~/.ssh/sockets/ exists before ssh tries to bind a ControlMaster socket there.
        ".ssh/sockets/.keep".text = "# Managed by Home Manager";
      }
      // sshPublicKeyEntries;
  };
}
