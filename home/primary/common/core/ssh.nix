# My credential policy: the order my keys are offered in, and which hosts get
# my agent forwarded to them. Every host gets it, because the agent follows me
# over `ssh -A` and the order should not change with where I am sitting.
# Its sibling home/common/core/ssh is shared by every user on the machine.
{
  config,
  lib,
  ...
}: let
  # Public halves only, so they're safe to commit.
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
      # Mine, then whatever else the agent holds. Never a deny: a host
      # that knows any of my keys gets in. IdentityFile accumulates across
      # matching blocks, so a block naming its own key is tried ahead of this
      # one rather than instead of it.
      "*".IdentityFile = "~/.ssh/primary.pub";

      # Stable attr name for DAG ordering; the real pattern is in the header.
      "ssh-hosts" = lib.hm.dag.entryAfter ["*"] {
        header = "Host ${hostString}";
        ForwardAgent = true;
      };
      # The identity order from "*" already puts mine first here.
      "git" = {
        header = "Host gitlab.com github.com";
        User = "git";
      };
    }
    // hostsAddrConfig;

  home.file = sshPublicKeyEntries;
}
