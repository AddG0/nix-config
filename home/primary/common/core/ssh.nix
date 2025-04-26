{
  config,
  hostSpec,
  lib,
  ...
}: let
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

  # Lots of hosts have the same default config, so don't duplicate
  vanillaHosts = [
    "ghost"
    "zephy"
  ];
  vanillaHostsConfig = lib.attrsets.mergeAttrsList (
    lib.lists.map (host: {
      "${host}" = lib.hm.dag.entryAfter ["ssh-hosts"] {
        host = host;
        hostname = "${host}.${hostSpec.domain}";
        port = hostSpec.networking.ports.tcp.ssh;
      };
    })
    vanillaHosts
  );
in {
  programs.ssh = {
    enable = true;

    # FIXME: This should probably be for git systems only?
    controlMaster = "auto";
    controlPath = "~/.ssh/sockets/S.%r@%h:%p";
    controlPersist = "10m";

    # req'd for enabling yubikey-agent
    extraConfig = ''
      AddKeysToAgent yes
      IdentityFile ${config.home.homeDirectory}/.ssh/id_ed25519
      ${hostSpec.networking.ssh.extraConfig}
    '';

    matchBlocks =
      {
        # Not all of this systems I have access to can use yubikey.
        "ssh-hosts" = lib.hm.dag.entryAfter ["*"] {
          host = "${hostString}";
          forwardAgent = true;
          identitiesOnly = true;
          identityFile = lib.lists.forEach identityFiles (file: "${config.home.homeDirectory}/.ssh/${file}");
        };

        "git" = {
          host = "gitlab.com github.com";
          user = "git";
          forwardAgent = true;
          identitiesOnly = true;
          identityFile = lib.lists.forEach identityFiles (file: "${config.home.homeDirectory}/.ssh/${file}");
        };
      }
      // vanillaHostsConfig;
  };

  programs.zsh.oh-my-zsh.plugins = [
    "ssh-agent"
    "ssh"
  ];

  home.file =
    {
      ".ssh/config.d/.keep".text = "# Managed by Home Manager";
      ".ssh/sockets/.keep".text = "# Managed by Home Manager";
    }
    // sshPublicKeyEntries;
}
