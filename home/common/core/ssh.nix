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

      extraConfig = ''
        AddKeysToAgent yes
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

          "ssh-hosts" = lib.hm.dag.entryAfter ["*"] {
            host = "${hostString}";
            forwardAgent = true;
          };

          "git" = {
            host = "gitlab.com github.com";
            user = "git";
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

    # Ensures ~/.ssh/sockets/ exists before ssh tries to bind a ControlMaster socket there.
    home.file.".ssh/sockets/.keep".text = "# Managed by Home Manager";
  };
}
