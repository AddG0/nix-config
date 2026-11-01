# decky-follow-user restarts Decky only for a new console user, and the migration moves the shared plugin data once; ./follow-user.bats, ./migrate.bats.
{
  harness,
  pkgs,
  lib,
  ...
}: let
  stub = name: text: pkgs.writeShellScriptBin name text;

  followUser = import ../follow-user.nix {
    inherit pkgs;
    # Stubs first: coreutils has its own id.
    runtimeInputs = [
      (stub "id" ''if [ "$2" = greeter ]; then echo 980; else echo 1000; fi'')
      (stub "getent" ''if [ "$2" = homeless ]; then echo "$2:x:1000:100:::/bin/sh"; else echo "$2:x:1000:100::$HOMES/$2:/bin/sh"; fi'')
      (stub "systemctl" ''if [ -n "''${FAIL_RESTART:-}" ]; then exit 1; fi; echo "$*" >>"$CALLS"'')
      (stub "systemd-cat" ''cat >>"$LOG"'')
      pkgs.coreutils
    ];
  };
  migrate = import ../migrate-shared-data.nix {inherit pkgs;};
in
  harness.bats "decky-follow-user" [./follow-user.bats ./migrate.bats] {
    followUser = lib.getExe followUser;
    migrate = lib.getExe migrate;
  }
