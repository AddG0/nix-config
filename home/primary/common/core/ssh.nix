# My credential policy: which hosts get one of my keys and my forwarded agent.
# Its sibling home/common/core/ssh is shared by every user on the machine.
{
  config,
  lib,
  ...
}: let
  # Public keys aren't secret, so they're committed; the agent serves the
  # private half by matching pubkey fingerprint.
  primaryKeys = lib.custom.relativeToHosts "common/users/primary/keys";
  sshPublicKeyEntries = lib.attrsets.mapAttrs' (
    filename: _:
      lib.nameValuePair ".ssh/${filename}" {source = "${primaryKeys}/${filename}";}
  ) (builtins.readDir primaryKeys);

  hosts = [
    "ghost"
  ];
  hostDomains = map (h: "${h}.${config.hostSpec.domain}") hosts;
  hostAll = hosts ++ hostDomains;
  hostString = lib.concatStringsSep " " hostAll;

  hostsAddrConfig =
    lib.attrsets.mapAttrs' (host: value: {
      name = host;
      # Attribute name is the `Host` pattern (header defaults to "Host ${name}").
      value = lib.hm.dag.entryAfter ["ssh-hosts"] {
        HostName = value.ipv4;
        Port = config.hostSpec.networking.ports.tcp.ssh;
        ForwardAgent = true;
      };
    })
    config.hostSpec.networking.hostsAddr;
in {
  programs.ssh.settings =
    {
      "*" = {
        # Try primary first, then fall back to other agent keys.
        IdentityFile = "~/.ssh/primary.pub";
      };

      # Stable attr name for DAG ordering; the real pattern is in the header.
      "ssh-hosts" = lib.hm.dag.entryAfter ["*"] {
        header = "Host ${hostString}";
        ForwardAgent = true;
      };

      "git" = {
        header = "Host gitlab.com github.com";
        User = "git";
        IdentityFile = "~/.ssh/primary.pub";
        IdentitiesOnly = true;
      };
    }
    // hostsAddrConfig;

  home.file = sshPublicKeyEntries;
}
