# The watcher's passes on fixture /proc, cgroup, CPU and resctrl trees: 8 CPUs, V-Cache on cores 0,4 and 1,5, at least one core for the game; the fakes from ./script.nix log every call to $CALLS.

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert

  export PROC_ROOT=$BATS_TEST_TMPDIR/proc CGROUP_ROOT=$BATS_TEST_TMPDIR/cgroup CALLS=$BATS_TEST_TMPDIR/calls
  export CPU_ROOT=$BATS_TEST_TMPDIR/cpu RESCTRL_ROOT=$BATS_TEST_TMPDIR/resctrl XDG_RUNTIME_DIR=$BATS_TEST_TMPDIR/run
  mkdir -p "$XDG_RUNTIME_DIR" "$RESCTRL_ROOT/game" "$RESCTRL_ROOT/info/L3"
  : >"$CALLS"
  : >"$RESCTRL_ROOT/game/tasks"
  echo ffff >"$RESCTRL_ROOT/info/L3/cbm_mask"
  echo "L3:0=ffff;1=ffff" >"$RESCTRL_ROOT/schemata"
  mkdir -p "$CPU_ROOT"
  echo 0-7 >"$CPU_ROOT/online"
  for cpu in 0 1 2 3; do
    for thread in "$cpu" $((cpu + 4)); do
      mkdir -p "$CPU_ROOT/cpu$thread/topology"
      echo "$cpu,$((cpu + 4))" >"$CPU_ROOT/cpu$thread/topology/thread_siblings_list"
    done
  done
  uid=$(id -u)
  session=/user.slice/user-$uid.slice/user@$uid.service
  export USER_MANAGER_CGROUP=$session
  usage_sample=$XDG_RUNTIME_DIR/x3d-game-isolation.usage
  steam_scope=$session/app.slice/app-graphical.slice/app-steam@autostart.service
  mkdir -p "$CGROUP_ROOT$session"/{session.slice/session-graphical.slice,app.slice/app-graphical.slice,background.slice,init.scope,tmux-spawn-a.scope}
}

# process <pid> <cgroup> [parent pid]
process() {
  mkdir -p "$PROC_ROOT/$1/task/$1" "$CGROUP_ROOT$2"
  echo "0::$2" >"$PROC_ROOT/$1/cgroup"
  printf 'PPid:\t%s\n' "${3:-1}" >"$PROC_ROOT/$1/status"
  echo "$1" >>"$CGROUP_ROOT$2/cgroup.procs"
}

playing() {
  export GAMES_LISTING="([($1, objectpath '/com/feralinteractive/GameMode/Games/$1')],)"
}

# isolated_game <pid> <game cpus> <system cpus>: a game the watcher already moved and fenced, its threads in the cache group, the system split.
isolated_game() {
  process "$1" "$session/game.slice/x3d-game-$1.scope"
  printf '%s' "$2" >"$CGROUP_ROOT$session/game.slice/cpuset.cpus"
  echo "$1" >>"$RESCTRL_ROOT/game/tasks"
  mkdir -p "$CGROUP_ROOT/system.slice" "$CGROUP_ROOT/init.scope"
  printf '%s' "$3" >"$CGROUP_ROOT/system.slice/cpuset.cpus"
  printf '%s' "$3" >"$CGROUP_ROOT/init.scope/cpuset.cpus"
  echo "L3:0=f;1=ffff" >"$RESCTRL_ROOT/schemata"
  playing "$1"
}

# load <busy cores over the last second> [waiting %]: the game's CPU and stall time since a sample taken a second ago.
load() {
  usec=$(awk -v b="$1" 'BEGIN {printf "%d", b * 1e6}')
  stall=$(awk -v w="${2:-0}" 'BEGIN {printf "%d", w * 1e4}')
  echo "usage_usec $((10000000 + usec))" >"$CGROUP_ROOT$session/game.slice/cpu.stat"
  echo "some avg10=0.00 avg60=0.00 avg300=0.00 total=$((5000000 + stall))" >"$CGROUP_ROOT$session/game.slice/cpu.pressure"
  echo "$(awk -v now="$(date +%s.%N)" 'BEGIN {printf "%.6f", now - 1}') 10000000 5000000" >"$usage_sample"
}

game_exited() {
  unset GAMES_LISTING
  : >"$CGROUP_ROOT$session/game.slice/x3d-game-$1.scope/cgroup.procs"
}

fences() {
  printf 'systemctl --user set-property --runtime %s AllowedCPUs=%s\n' \
    app.slice "$1" background.slice "$1" init.scope "$1" tmux-spawn-a.scope "$1"
}

assert_calls() {
  run cat "$CALLS"
  assert_output "$1"
}

@test "while a game runs, gives it its first V-Cache core, splits the system and fences the session to the rest" {
  process 100 "$session/app.slice/app-steam-app252950-5.scope"
  process 101 "$session/app.slice/app-steam-app252950-5.scope"
  playing 100

  run "$watcher" reconcile

  assert_success
  assert_output playing
  assert_calls "sudo -n isolate split 0,4
busctl --user call org.freedesktop.systemd1 /org/freedesktop/systemd1 org.freedesktop.systemd1.Manager StartTransientUnit ssa(sv)a(sa(sv)) x3d-game-100.scope fail 2 Slice s game.slice PIDs au 2 100 101 0
systemctl --user set-property --runtime game.slice AllowedCPUs=0,4
taskset -a -pc 0,4 100
taskset -a -pc 0,4 101
$(fences 1-3,5-7)"
}

@test "puts every thread of the game in the cache group" {
  process 100 "$session/app.slice/app-steam-app252950-5.scope"
  process 101 "$session/app.slice/app-steam-app252950-5.scope"
  mkdir -p "$PROC_ROOT/100/task/102"
  playing 100

  run "$watcher" reconcile

  assert_success
  run sort -n "$RESCTRL_ROOT/game/tasks"
  assert_output "100
101
102"
}

@test "takes only the game and its children from a terminal's scope" {
  tmux=$session/app.slice/tmux-spawn-b.scope
  process 50 "$tmux"
  process 100 "$tmux" 50
  process 101 "$tmux" 100
  process 60 "$tmux" 50
  playing 100

  run "$watcher" reconcile

  assert_success
  run grep -c 'x3d-game-100.scope fail 2 Slice s game.slice PIDs au 2 100 101 0' "$CALLS"
  assert_output 1
}

@test "retries the move quietly when a launching game's process exits mid-move" {
  process 100 "$session/app.slice/app-steam-app252950-5.scope"
  playing 100
  export BUSCTL_FAIL_TIMES=2

  run "$watcher" reconcile

  assert_success
  assert_output playing
  run grep -c '^busctl.*x3d-game-100.scope' "$CALLS"
  assert_output 3
}

@test "reports why the move failed after three attempts, leaving the session unfenced" {
  process 100 "$session/app.slice/app-steam-app252950-5.scope"
  playing 100
  export BUSCTL_FAIL_TIMES=3

  run "$watcher" reconcile

  assert_failure
  assert_output --partial "could not move processes into game.slice after 3 attempts: Call failed"
  run grep -c 'AllowedCPUs=1-3,5-7' "$CALLS"
  assert_output 0
}

@test "moves the Steam client beside the compositor before fencing the session" {
  isolated_game 100 0,4 1-3,5-7
  process 200 "$steam_scope"
  process 201 "$steam_scope"
  export STEAM_PID=201

  run "$watcher" reconcile

  assert_success
  assert_calls "busctl --user call org.freedesktop.systemd1 /org/freedesktop/systemd1 org.freedesktop.systemd1.Manager StartTransientUnit ssa(sv)a(sa(sv)) x3d-steam-client-201.scope fail 2 Slice s session-graphical.slice PIDs au 2 201 200 0
$(fences 1-3,5-7)"
}

@test "reports a Steam client that did not move, and still fences the session" {
  isolated_game 100 0,4 1-3,5-7
  process 200 "$steam_scope"
  export STEAM_PID=200 BUSCTL_NO_MOVE=1

  run "$watcher" reconcile

  assert_failure
  assert_output --partial "did not move into session-graphical.slice"
  run grep -c 'AllowedCPUs=1-3,5-7' "$CALLS"
  assert_output 4
}

@test "changes nothing on later passes while the game's load fits its cores" {
  isolated_game 100 0,4 1-3,5-7

  "$watcher" reconcile
  : >"$CALLS"
  load 0.5
  run "$watcher" reconcile

  assert_success
  assert_calls ""
}

@test "gives the game another V-Cache core while its cores run full" {
  isolated_game 100 0,4 1-3,5-7
  "$watcher" reconcile
  : >"$CALLS"
  load 1.5

  run "$watcher" reconcile

  assert_success
  assert_calls "sudo -n isolate split 0-1,4-5
systemctl --user set-property --runtime game.slice AllowedCPUs=0-1,4-5
taskset -a -pc 0-1,4-5 100
$(fences 2-3,6-7)"
}

@test "gives the game another V-Cache core while its threads wait for a CPU" {
  isolated_game 100 0,4 1-3,5-7
  "$watcher" reconcile
  : >"$CALLS"
  load 0.5 12.00

  run "$watcher" reconcile

  assert_success
  run grep -c 'game.slice AllowedCPUs=0-1,4-5' "$CALLS"
  assert_output 1
}

@test "gives a core back once the game would stay well under its share without it" {
  isolated_game 100 0-1,4-5 2-3,6-7
  "$watcher" reconcile
  : >"$CALLS"
  load 0.5

  run "$watcher" reconcile

  assert_success
  assert_calls "sudo -n isolate split 0,4
systemctl --user set-property --runtime game.slice AllowedCPUs=0,4
taskset -a -pc 0,4 100
$(fences 1-3,5-7)"
}

@test "decides nothing on less load history than the sizing window" {
  isolated_game 100 0,4 1-3,5-7
  "$watcher" reconcile
  : >"$CALLS"
  load 1.5
  echo "$(date +%s.%N) 10000000 5000000" >"$usage_sample"
  before=$(cat "$usage_sample")

  run "$watcher" reconcile

  assert_success
  assert_calls ""
  [ "$(cat "$usage_sample")" = "$before" ]
}

@test "skips a registered launcher that has already exited" {
  process 100 "$session/app.slice/app-steam-app252950-5.scope"
  export GAMES_LISTING="([(99, objectpath '/com/feralinteractive/GameMode/Games/99'), (100, objectpath '/com/feralinteractive/GameMode/Games/100')],)"

  run "$watcher" reconcile

  assert_success
  assert_output playing
  run grep -c 'x3d-game-100.scope' "$CALLS"
  assert_output 1
}

@test "never grows the game past the V-Cache CCD" {
  isolated_game 100 0-1,4-5 2-3,6-7
  "$watcher" reconcile
  : >"$CALLS"
  load 1.9

  run "$watcher" reconcile

  assert_success
  assert_calls ""
}

@test "ignores a sample from a recreated slice instead of shrinking the game" {
  isolated_game 100 0-1,4-5 2-3,6-7
  "$watcher" reconcile
  : >"$CALLS"
  load 0.5
  echo "$(date +%s.%N) 99999999999 5000000" >"$usage_sample"

  run "$watcher" reconcile

  assert_success
  assert_calls ""
}

@test "splits the system again when only part of an earlier split took" {
  isolated_game 100 0,4 1-3,5-7
  : >"$CGROUP_ROOT/init.scope/cpuset.cpus"

  run "$watcher" reconcile

  assert_success
  run grep -c '^sudo -n isolate split 0,4' "$CALLS"
  assert_output 1
}

@test "splits the system again when the V-Cache split is missing" {
  isolated_game 100 0,4 1-3,5-7
  echo "L3:0=ffff;1=ffff" >"$RESCTRL_ROOT/schemata"

  run "$watcher" reconcile

  assert_success
  run grep -c '^sudo -n isolate split 0,4' "$CALLS"
  assert_output 1
}

@test "reports a fence the kernel did not apply, as before cpuset reaches the session" {
  isolated_game 100 0,4 1-3,5-7
  export SYSTEMCTL_NO_APPLY=1

  run "$watcher" reconcile

  assert_failure
  assert_output --partial "cpuset is delegated to the session only after logging in again"
}

@test "reports a cache group it cannot write, but still fences the session" {
  isolated_game 100 0,4 1-3,5-7
  : >"$RESCTRL_ROOT/game/tasks"
  chmod a-w "$RESCTRL_ROOT/game/tasks"

  run "$watcher" reconcile

  assert_failure
  assert_output --partial "the game gets the small share of the V-Cache"
  run grep -c 'AllowedCPUs=1-3,5-7' "$CALLS"
  assert_output 4
}

@test "reports a game outside this user's session" {
  process 100 /system.slice/some.service
  playing 100

  run "$watcher" reconcile

  assert_failure
  assert_output --partial "outside this user's session"
}

@test "leaves the session unfenced when the helper cannot split the system, and retries" {
  process 100 "$session/game.slice/x3d-game-100.scope"
  playing 100
  export SUDO_EXIT=1

  run "$watcher" reconcile

  assert_failure
  assert_calls "sudo -n isolate split 0,4"
}

@test "keeps fencing the other units when one fails, and retries it next pass" {
  isolated_game 100 0,4 1-3,5-7
  export SYSTEMCTL_FAIL_UNIT=background.slice

  run "$watcher" reconcile

  assert_failure
  assert_output --partial "could not set AllowedCPUs=1-3,5-7 on background.slice"
  : >"$CALLS"
  unset SYSTEMCTL_FAIL_UNIT
  run "$watcher" reconcile
  assert_success
  assert_calls "systemctl --user set-property --runtime background.slice AllowedCPUs=1-3,5-7"
}

@test "fails on a ListGames reply it cannot read instead of treating it as no game" {
  isolated_game 100 0,4 1-3,5-7
  export GAMES_LISTING="(something unexpected,)"

  run "$watcher" reconcile

  assert_failure
  assert_output --partial "cannot read gamemode's ListGames reply"
  assert_calls ""
}

@test "holds the split while the game's processes outlive its registration" {
  isolated_game 100 0,4 1-3,5-7
  "$watcher" reconcile
  : >"$CALLS"
  unset GAMES_LISTING

  run "$watcher" reconcile

  assert_success
  assert_output pending
  assert_calls ""
}

@test "after the game exits, gives the session every CPU back and releases the system" {
  isolated_game 100 0,4 1-3,5-7
  "$watcher" reconcile
  : >"$CALLS"
  game_exited 100

  run "$watcher" reconcile

  assert_success
  assert_output idle
  assert_calls "$(fences "")
sudo -n isolate release"
  [ ! -e "$usage_sample" ]
}

@test "releases a V-Cache split left behind after the fences were cleared" {
  echo "L3:0=f;1=ffff" >"$RESCTRL_ROOT/schemata"

  run "$watcher" reconcile

  assert_success
  assert_calls "sudo -n isolate release"
}

@test "release ends isolation even while a game runs" {
  isolated_game 100 0,4 1-3,5-7
  "$watcher" reconcile
  : >"$CALLS"

  run "$watcher" release

  assert_success
  assert_calls "$(fences "")
sudo -n isolate release"
}

@test "stays quiet while idle with nothing fenced" {
  run "$watcher" reconcile

  assert_success
  assert_output idle
  assert_calls ""
}

@test "watch reconciles at start and on each game event, then exits when gamemode's stream ends" {
  export GDBUS_LOG=$BATS_TEST_TMPDIR/gdbus.log
  export MONITOR_EVENTS="/com/feralinteractive/GameMode: com.feralinteractive.GameMode.GameRegistered (100, objectpath '/com/feralinteractive/GameMode/Games/100')
/com/feralinteractive/GameMode: org.freedesktop.DBus.Properties.PropertiesChanged ('com.feralinteractive.GameMode', {'ClientCount': <1>}, @as [])
/com/feralinteractive/GameMode: com.feralinteractive.GameMode.GameUnregistered (100, objectpath '/com/feralinteractive/GameMode/Games/100')
"

  run "$watcher" watch

  assert_failure 1
  assert_output --partial "signal stream ended"
  run grep -c ListGames "$GDBUS_LOG"
  assert_output 3
}

@test "watch retries a failed pass without waiting for an event" {
  # A quiet stream held open, so only the retry timer can start further passes.
  export GDBUS_LOG=$BATS_TEST_TMPDIR/gdbus.log GAMES_LISTING="(unreadable,)" MONITOR_HOLD=4

  run timeout 3 "$watcher" watch

  assert_failure 124
  run grep -c ListGames "$GDBUS_LOG"
  [ "$output" -ge 2 ]
}

@test "watch waits for an event while idle instead of polling" {
  export GDBUS_LOG=$BATS_TEST_TMPDIR/gdbus.log MONITOR_HOLD=4

  run timeout 3 "$watcher" watch

  assert_failure 124
  run grep -c ListGames "$GDBUS_LOG"
  assert_output 1
}

@test "does nothing on a CPU without a cache CCD" {
  export CCD_EXIT=3
  process 100 "$session/app.slice/app-steam-app252950-5.scope"
  playing 100

  run "$watcher" reconcile

  assert_success
  assert_calls ""
}
