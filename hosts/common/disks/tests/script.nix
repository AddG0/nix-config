# Root rollback: the old root is kept 30 days from archiving under its timestamp, older ones go, and old_roots itself stays.
{
  harness,
  pkgs,
  ...
}: let
  rollback = pkgs.writeShellScript "rollback-root" ''
    set -e
    ${import ../_rollback-root.nix {
      mountDir = "$TOP";
      device = "/dev/crypted";
    }}
  '';
  btrfs = pkgs.writeShellScriptBin "btrfs" ''
    for target; do :; done
    case "$2" in
      create) mkdir "$target" ;;
      delete) rm -rf "$target" ;;
      *) echo "btrfs stub: unexpected $*" >&2; exit 1 ;;
    esac
  '';
  noop = name: pkgs.writeShellScriptBin name "true";
in
  harness.bats "rollback-root" [./rollback-root.bats] {
    inherit rollback;
    stubPath = pkgs.lib.makeBinPath [btrfs (noop "mount") (noop "umount")];
  }
