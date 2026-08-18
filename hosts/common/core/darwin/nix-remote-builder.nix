# Nix Remote Builder User (Darwin)
#
# Darwin counterpart to hosts/common/core/nixos/nix-remote-builder.nix.
# Enabled automatically when this host appears in allBuilders there.
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.nix.remoteBuilder;

  # Free on all darwin hosts; nix-darwin has no uid allocator, so it's pinned here.
  builderId = 531;
in {
  config = mkIf cfg.enable {
    # nix-darwin only creates/deletes accounts it has been told it owns.
    users.knownUsers = ["builder"];
    users.knownGroups = ["builder"];

    users.groups.builder.gid = builderId;

    users.users.builder = {
      uid = builderId;
      gid = builderId;
      description = "Nix remote builder";
      home = "/var/lib/builder";
      createHome = true;

      # /etc/zshenv is sourced for non-interactive `zsh -c` too, which is how the
      # nix daemon's PATH gets `nix-daemon`; bash isn't built with SSH_SOURCE_BASHRC.
      shell = pkgs.zsh;

      openssh.authorizedKeys.keys = mkIf (cfg.publicKey != "") [cfg.publicKey];
    };

    nix.settings.trusted-users = ["builder"];

    # sshd runs `account required pam_sacl.so sacl_service=ssh`, and this host's
    # com.apple.access_ssh ACL only nests admin — builder is rejected before its
    # key is ever consulted.
    system.activationScripts.postActivation.text = ''
      if ! dseditgroup -o checkmember -m builder com.apple.access_ssh | grep -q '^yes'; then
        echo "adding builder to the com.apple.access_ssh ACL" >&2
        dseditgroup -o edit -a builder -t user com.apple.access_ssh
      fi
    '';
  };
}
