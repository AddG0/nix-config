# Root rollback: the old root is kept 30 days from archiving under its timestamp, older ones go, and old_roots itself stays.
{pkgs, ...}: let
  rollback = pkgs.writeShellScript "rollback-root" ''
    set -e
    ${import ../_rollback-root.nix {
      mountDir = "$TOP";
      device = "/dev/crypted";
    }}
  '';
  stubs = pkgs.writeShellScriptBin "btrfs" ''
    for target; do :; done
    case "$2" in
      create) mkdir "$target" ;;
      delete) rm -rf "$target" ;;
      *) echo "btrfs stub: unexpected $*" >&2; exit 1 ;;
    esac
  '';
  noop = name: pkgs.writeShellScriptBin name "true";
in
  pkgs.runCommand "rollback-root" {} ''
    fail() { echo "FAIL: $*" >&2; exit 1; }
    export PATH=${pkgs.lib.makeBinPath [stubs (noop "mount") (noop "umount") pkgs.coreutils pkgs.findutils]}
    export TZ=UTC

    export TOP=$PWD/boot1
    mkdir -p "$TOP/@root/etc" "$TOP/old_roots/ancient" "$TOP/old_roots/recent"
    echo kept >"$TOP/@root/etc/forgotten"
    touch -d "2026-01-02 03:04:05" "$TOP/@root"
    touch -d "40 days ago" "$TOP/old_roots/ancient"
    touch -d "5 days ago" "$TOP/old_roots/recent"
    ${rollback} || fail "rollback exited non-zero"
    [ "$(cat "$TOP/old_roots/2026-01-02_03:04:05/etc/forgotten")" = kept ] || fail "previous root from a boot over 30 days old not kept under its timestamp: $(ls "$TOP/old_roots")"
    [ -d "$TOP/@root" ] && [ -z "$(ls -A "$TOP/@root")" ] || fail "new @root missing or not empty"
    [ ! -e "$TOP/old_roots/ancient" ] || fail "a kept root older than 30 days was not deleted"
    [ -d "$TOP/old_roots/recent" ] || fail "a kept root younger than 30 days was deleted"

    export TOP=$PWD/boot2
    mkdir -p "$TOP/old_roots"
    touch -d "40 days ago" "$TOP/old_roots"
    ${rollback} || fail "rollback with no @root and a stale old_roots exited non-zero"
    [ -d "$TOP/old_roots" ] || fail "old_roots itself was deleted for being older than 30 days"
    [ -d "$TOP/@root" ] || fail "@root not created when none existed"

    touch "$out"
  ''
