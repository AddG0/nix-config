# Regression suite for the stale-session sweep. Every case here is a bug that
# shipped: the timer could not reach the tmux server, ssh's client-attached hook
# overwrote this module's, continuum's fresh session_created restarted the
# countdown each boot, and a name with spaces lost all but its first word.
#
# Auto-discovered and wired into `nix flake check` by checks/module-tests.nix.
{
  pkgs,
  lib,
  self,
  ...
}: let
  inherit (pkgs) runCommand coreutils tmux util-linux gnugrep ncurses;
  testLib = self.lib.extend (_: _: {inherit (self.inputs.home-manager.lib) hm;});
  tmuxConfig =
    (self.inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      lib = testLib;
      extraSpecialArgs = {
        inherit self;
        hostSpec = {
          primaryUsername = "tester";
          home = "/home/tester";
          system.stateVersion = "24.05";
        };
      };
      modules = [
        {
          home = {
            username = "tester";
            homeDirectory = "/home/tester";
            stateVersion = "24.05";
          };
        }
        ./default.nix
        ../../../ssh/default.nix
      ];
    }).config;

  recordAttach = pkgs.callPackage ./record-attach.nix {};
  prune = pkgs.callPackage ./prune.nix {};

  preamble = ''
    # C, not UTF-8, on purpose: that is where tmux rewrites control characters
    # in -F output, which is how a delimiter-based parse broke here.
    export LC_ALL=C
    # tmux derives default-shell from SHELL; pin it so "idle" is well defined.
    export SHELL=${pkgs.bash}/bin/bash
    export HOME=$PWD/home TERM=xterm-256color
    export XDG_STATE_HOME=$HOME/.local/state
    export TMUX_TMPDIR=$PWD/run
    mkdir -p "$HOME" "$TMUX_TMPDIR"
    sd=$XDG_STATE_HOME/tmux/last-attached
    tm="tmux -f /dev/null"
    day=86400

    fail() { echo "FAIL: $*" >&2; exit 1; }
    key() { printf '%s' "$1" | basenc --base64url -w 0; }
    stamp() { cat "$sd/$(key "$1")" 2>/dev/null; }
    backdate() { printf '%s\n' "$(($(date +%s) - $2))" >"$sd/$(key "$1")"; }
    stale() { backdate "$1" $((4 * day)); }
    alive() { $tm list-sessions -F '#{session_name}' 2>/dev/null | grep -Fxq "$1"; }
  '';

  hooks =
    runCommand "tmux-stale-sessions-hooks" {
      nativeBuildInputs = [coreutils tmux util-linux gnugrep ncurses];
      hostConf = pkgs.writeText "tmux.conf" tmuxConfig.programs.tmux.extraConfig;
    } ''
      ${preamble}

      # The isolated module graph catches an accidental hook replacement.
      grep -E "^set-hook -ag client-attached" "$hostConf" >hooks.conf
      want=$(grep -c . hooks.conf)
      [ "$want" -ge 2 ] || fail "expected this module's and ssh's hooks in the module config, found $want"
      $tm new-session -d -s probe -x 80 -y 24
      $tm source-file hooks.conf
      got=$($tm show-hooks -g | grep -c "^client-attached")
      [ "$got" = "$want" ] || fail "$want hooks were set but tmux kept $got"
      $tm show-hooks -g | grep -q "tmux-record-session-attach" \
        || fail "this module's client-attached hook did not survive the other's"

      echo "--- should record the whole name when a client attaches to a session with spaces"
      $tm rename-session -t probe "Auth service Library"
      rm -f "$sd"/*
      mkfifo fifo
      script -q -c "$tm attach -t '=Auth service Library'" /dev/null <fifo >/dev/null 2>&1 &
      exec 3>fifo
      for _ in $(seq 100); do [ -n "$(stamp "Auth service Library")" ] && break; sleep 0.1; done
      [ -n "$(stamp "Auth service Library")" ] \
        || fail "attaching recorded no last-attached time for a name containing spaces"
      exec 3>&-

      $tm kill-server 2>/dev/null || true
      echo "hooks ok"
      touch $out
    '';
in
  runCommand "tmux-stale-sessions" {
    nativeBuildInputs = [coreutils tmux gnugrep ncurses];
  } ''
    ${preamble}

    echo "--- should seed a last-attached time for a session it has not seen before, and kill nothing"
    $tm new-session -d -s alpha
    ${prune}/bin/tmux-prune-stale-sessions
    [ -n "$(stamp alpha)" ] || fail "no last-attached time was written on first sighting"
    alive alpha || fail "killed a session the first time it was seen"

    echo "--- should keep a session last attached inside the window"
    backdate alpha $((2 * day))
    ${prune}/bin/tmux-prune-stale-sessions
    alive alpha || fail "killed a session attached two days ago"

    echo "--- should keep a session whose name is a prefix of the stale one"
    $tm new-session -d -s alp
    ${prune}/bin/tmux-prune-stale-sessions
    stale alp
    ${prune}/bin/tmux-prune-stale-sessions
    alive alpha || fail "killing 'alp' took 'alpha' with it"
    alive alp && fail "kept a session attached four days ago"

    echo "--- should kill on the last-attached time, not on session_created, across a restart"
    $tm new-session -d -s beta
    ${prune}/bin/tmux-prune-stale-sessions
    stale beta
    # What continuum does on every boot: same names, brand new creation times.
    $tm kill-server 2>/dev/null || true
    $tm new-session -d -s beta
    $tm new-session -d -s alpha
    ${prune}/bin/tmux-prune-stale-sessions
    alive beta && fail "a restore's fresh session_created reset the countdown"
    alive alpha || fail "the restore took a session that was still fresh"

    echo "--- should read back the last-attached time a hook wrote for a name with spaces"
    $tm new-session -d -s "Auth service Library"
    ${recordAttach}/bin/tmux-record-session-attach "Auth service Library"
    [ -n "$(stamp "Auth service Library")" ] || fail "record-attach stored nothing for a spaced name"
    stale "Auth service Library"
    ${prune}/bin/tmux-prune-stale-sessions
    alive "Auth service Library" && fail "prune could not read the time record-attach wrote"

    echo "--- should keep a detached session that is still running a command"
    $tm new-session -d -s working "sleep 600"
    ${prune}/bin/tmux-prune-stale-sessions
    stale working
    ${prune}/bin/tmux-prune-stale-sessions
    alive working || fail "pruned a session with a command still running"
    a_minute_ago=$(($(date +%s) - 60))
    [ "$(stamp working)" -gt "$a_minute_ago" ] \
      || fail "a running command did not restamp the session"

    echo "--- should kill a detached session sitting at a shell prompt"
    $tm new-session -d -s prompting
    ${prune}/bin/tmux-prune-stale-sessions
    stale prompting
    ${prune}/bin/tmux-prune-stale-sessions
    alive prompting && fail "kept a session idle at its shell prompt"

    echo "--- should leave recorded times alone when no tmux server is running"
    ${recordAttach}/bin/tmux-record-session-attach ghost
    before=$(ls "$sd" | wc -l)
    [ "$before" -gt 0 ] || fail "test bug: nothing to preserve"
    $tm kill-server 2>/dev/null || true
    ${prune}/bin/tmux-prune-stale-sessions
    [ "$(ls "$sd" | wc -l)" = "$before" ] || fail "an unreachable tmux was read as 'no sessions left'"

    echo "--- should not hand a new session the last-attached time of a dead one with the same name"
    # A second session so killing gamma does not take the whole server with it.
    $tm new-session -d -s keeper
    $tm new-session -d -s gamma
    ${prune}/bin/tmux-prune-stale-sessions
    stale gamma
    $tm kill-session -t "=gamma"
    ${prune}/bin/tmux-prune-stale-sessions
    [ -z "$(stamp gamma)" ] || fail "kept the last-attached time of a session that no longer exists"
    $tm new-session -d -s gamma
    ${prune}/bin/tmux-prune-stale-sessions
    alive gamma || fail "a reused name inherited the dead session's time and was pruned on sight"

    $tm kill-server 2>/dev/null || true
    echo "stale-session tests passed; hooks: ${hooks}"
    touch $out
  ''
