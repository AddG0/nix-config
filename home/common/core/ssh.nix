{
  config,
  hostSpec,
  lib,
  ...
}: let
  cfg = config.programs.ssh;

  hosts = [
    "ghost"
  ];
  # add my domain to each host
  hostDomains = map (h: "${h}.${config.hostSpec.domain}") hosts;
  hostAll = hosts ++ hostDomains;
  hostString = lib.concatStringsSep " " hostAll;

  pathtokeys = lib.custom.relativeToHosts "common/users/primary/keys";
  sshKeys =
    lib.lists.forEach (builtins.attrNames (builtins.readDir pathtokeys))
    # Remove the .pub suffix
    (key: lib.substring 0 (lib.stringLength key - lib.stringLength ".pub") key);
  sshPublicKeyEntries = lib.attrsets.mergeAttrsList (
    lib.lists.map
    # list of dicts
    (key: {".ssh/${key}.pub".source = "${pathtokeys}/${key}.pub";})
    sshKeys
  );

  identityFiles = [
    "id_ed25519"
  ];

  # Generate SSH host entries from hostsAddr
  hostsAddrConfig =
    lib.attrsets.mapAttrs' (host: value: {
      name = host;
      value = lib.hm.dag.entryAfter ["ssh-hosts"] {
        inherit host;
        hostname = value.ipv4;
        port = hostSpec.networking.ports.tcp.ssh;
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

      # AddKeysToAgent: automatically add keys to agent when used
      # IdentityFile: only set on non-servers (servers use forwarded agents)
      extraConfig =
        ''
          AddKeysToAgent yes
        ''
        + lib.optionalString (hostSpec.hostType != "server") ''
          IdentityFile ${config.home.homeDirectory}/.ssh/id_ed25519
        '';

      matchBlocks =
        {
          "*" = {
            controlMaster = "auto";
            controlPath = "~/.ssh/sockets/S.%r@%h:%p";
            controlPersist = "10m";
            serverAliveInterval = 60;
            serverAliveCountMax = 3;
            extraOptions = {
              TCPKeepAlive = "yes";
            };
          };

          # Not all of this systems I have access to can use yubikey.
          "ssh-hosts" = lib.hm.dag.entryAfter ["*"] {
            host = "${hostString}";
            forwardAgent = true;
            identitiesOnly = true;
            identityFile = lib.lists.forEach identityFiles (file: "${config.home.homeDirectory}/.ssh/${file}");
          };

          "gitlab-personal" = {
            host = "gitlab-personal";
            hostname = "gitlab.com";
            user = "git";
            forwardAgent = false;
            identitiesOnly = hostSpec.hostType != "server";
            identityFile = "${config.home.homeDirectory}/.ssh/id_ed25519_personal";
            identityAgent = "none";
            controlMaster = "no";
            controlPath = "none";
          };

          "git" = {
            host = "gitlab.com github.com";
            user = "git";
            # Servers use forwarded agents, so don't restrict to local identity files
            identitiesOnly = hostSpec.hostType != "server";
            identityFile = lib.lists.forEach identityFiles (file: "${config.home.homeDirectory}/.ssh/${file}");
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
        ".ssh/config.d/.keep".text = "# Managed by Home Manager";
        ".ssh/sockets/.keep".text = "# Managed by Home Manager";
      }
      // sshPublicKeyEntries;
  };
}
