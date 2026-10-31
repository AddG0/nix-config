# decky-follow-user restarts Decky only for a new console user, and the migration moves the shared plugin data once.
{
  pkgs,
  lib,
  ...
}: let
  stub = name: text: pkgs.writeShellScriptBin name text;

  followUser = import ../follow-user.nix {
    inherit pkgs;
    runtimeInputs = [
      pkgs.coreutils
      (stub "id" ''if [ "$2" = greeter ]; then echo 980; else echo 1000; fi'')
      (stub "getent" ''if [ "$2" = homeless ]; then echo "$2:x:1000:100:::/bin/sh"; else echo "$2:x:1000:100::$HOMES/$2:/bin/sh"; fi'')
      (stub "systemctl" ''if [ -n "''${FAIL_RESTART:-}" ]; then exit 1; fi; echo "$*" >>"$CALLS"'')
      (stub "systemd-cat" ''cat >>"$LOG"'')
    ];
  };
  migrate = import ../migrate-shared-data.nix {inherit pkgs;};
in
  pkgs.runCommand "decky-follow-user" {} ''
    fail() { echo "FAIL: $*" >&2; exit 1; }
    export HOMES=$PWD/homes CALLS=$PWD/calls LOG=$PWD/log
    boot=$PWD/boot.env user=$PWD/run/user.env
    mkdir -p "$HOMES/gamer/.local/share/decky" "$HOMES/addg/.local/share/decky"
    printf 'UNPRIVILEGED_USER=gamer\nUNPRIVILEGED_PATH=%s\n' "$HOMES/gamer/.local/share/decky" >"$boot"
    login() { PAM_USER=$1 ${lib.getExe followUser} "$boot" "$user"; }
    restarts() { cat "$CALLS" 2>/dev/null | grep -c . || true; }
    # The hook logs through a process substitution that can outlive it.
    logged() { for _ in $(seq 50); do grep -q "$1" "$LOG" 2>/dev/null && return; sleep 0.1; done; return 1; }

    login greeter
    [ ! -e "$user" ] || fail "a system user's login wrote $user"

    login gamer
    [ ! -e "$user" ] || fail "the boot user's login rewrote the env it already runs with"
    [ "$(restarts)" = 0 ] || fail "the boot user's login restarted Decky"

    login addg
    [ "$(cat "$user")" = "$(printf 'UNPRIVILEGED_USER=addg\nUNPRIVILEGED_PATH=%s' "$HOMES/addg/.local/share/decky")" ] \
      || fail "addg's login wrote: $(cat "$user")"
    [ "$(cat "$CALLS")" = "restart --no-block decky-loader.service" ] || fail "restart call: $(cat "$CALLS")"

    login addg
    [ "$(restarts)" = 1 ] || fail "the same user logging in again restarted Decky"

    login gamer
    [ "$(restarts)" = 2 ] || fail "switching back to the boot user did not restart Decky"

    if FAIL_RESTART=1 login addg; then fail "a login whose restart failed reported success"; fi
    grep -q "UNPRIVILEGED_USER=gamer" "$user" || fail "a failed restart left the new user's env: $(cat "$user")"
    login addg
    [ "$(restarts)" = 3 ] || fail "the login after a failed restart did not retry it"
    login gamer

    mkdir -p "$HOMES/nodata"
    if login nodata; then fail "a user without a decky data dir took Decky"; fi
    logged "nodata/.local/share/decky is missing" || fail "missing data dir was not logged: $(cat "$LOG")"
    grep -q "UNPRIVILEGED_USER=gamer" "$user" || fail "a failed login changed the env: $(cat "$user")"

    if login homeless; then fail "a user with no home in passwd took Decky"; fi
    logged "no home directory for homeless" || fail "a missing home was not logged: $(cat "$LOG")"
    grep -q "UNPRIVILEGED_USER=gamer" "$user" || fail "a homeless login changed the env: $(cat "$user")"

    state=$PWD/state data=$HOMES/gamer/.local/share/decky
    mkdir -p "$state/settings/Deckify" "$state/data/Deckify" "$state/themes/Kept" "$data/themes/Kept"
    echo creds >"$state/settings/Deckify/settings.json"
    echo '{}' >"$state/settings/loader.json"
    echo shared >"$state/themes/Kept/theme.json"
    ${lib.getExe migrate} "$state" "$data"
    [ "$(cat "$data/settings/Deckify/settings.json")" = creds ] || fail "plugin settings did not move"
    [ -d "$data/data/Deckify" ] && [ ! -e "$state/data" ] || fail "plugin data did not move, or left an empty dir"
    [ -f "$state/settings/loader.json" ] && [ ! -e "$data/settings/loader.json" ] || fail "loader.json moved; it stays shared"
    [ -f "$state/themes/Kept/theme.json" ] && [ ! -e "$data/themes/Kept/theme.json" ] \
      || fail "a theme the user already has was overwritten or dropped"
    ${lib.getExe migrate} "$state" "$data" || fail "a second run failed once the data had moved"

    ${lib.getExe migrate} "$state" "$HOMES/absent/.local/share/decky" || fail "a missing boot data dir stopped Decky's start"

    blocked=$HOMES/blocked
    mkdir -p "$state/logs/Deckify" "$state/data/Deckcord" "$blocked"
    touch "$blocked/logs"
    if ${lib.getExe migrate} "$state" "$blocked" 2>"$PWD/migrate.err"; then fail "a move that failed reported success"; fi
    grep -q "could not move $state/logs/Deckify" "$PWD/migrate.err" || fail "the failed move was not reported: $(cat "$PWD/migrate.err")"
    [ -d "$state/logs/Deckify" ] || fail "a failed move lost the source"
    [ -d "$blocked/data/Deckcord" ] || fail "one failed move stopped the rest"

    touch "$out"
  ''
