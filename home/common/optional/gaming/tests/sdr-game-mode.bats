# The REAL sdr-game-mode daemon against a fake hyprctl (see ./script.nix): `-j`
# queries read ./<query>.json, every other command is appended to
# ./commands.log and answered `ok`, or $REJECT when set.

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert

  # socat's SYSTEM: and the fake hyprctl both work on paths relative to here.
  cd "$BATS_TEST_TMPDIR" || return 1
  export FIXTURE=$BATS_TEST_TMPDIR HYPRLAND_INSTANCE_SIGNATURE=test
  export XDG_RUNTIME_DIR=$BATS_TEST_TMPDIR/run
  mkdir -p "$XDG_RUNTIME_DIR/hypr/test"
  : >commands.log
  unset REJECT
  pids=()
  sdr_rule="DP-3,3840x2160@240.0,3840x0,1.000000,transform,0,vrr,0,bitdepth,10,cm,srgb"
}

teardown() {
  if [ "${#pids[@]}" -gt 0 ]; then
    kill "${pids[@]}" 2>/dev/null || true
  fi
  if [ -z "${BATS_TEST_COMPLETED:-}" ]; then
    echo "daemon output:"
    echo "${output:-}"
  fi
}

# scenario <case> [pid]: one reconcile pass on the case's state, then its event
# (if any) and a second pass, then the exit trap. [pid] fills a null client pid.
scenario() {
  local state sock=$XDG_RUNTIME_DIR/hypr/test/.socket2.sock
  state=$(jq -ec --arg c "$1" --argjson pid "${2:-null}" \
    '.[$c] | (.clients[] | select(.pid == null) | .pid) |= $pid' "$fixtures") ||
    fail "no fixture for case $1"
  jq '.monitors' <<<"$state" >monitors.json
  jq '.clients' <<<"$state" >clients.json
  jq '.workspaces' <<<"$state" >workspaces.json
  jq '.after.monitors // .monitors' <<<"$state" >monitors.after
  jq '.after.clients // .clients' <<<"$state" >clients.after
  jq -r '.after.event // empty' <<<"$state" >event

  # Every case gets an event socket, so the daemon exits 0 at EOF and a crash shows.
  # socat strips quotes from SYSTEM, so an echoed `>>` would become a redirect.
  socat UNIX-LISTEN:"$sock" SYSTEM:"cp monitors.after monitors.json; cp clients.after clients.json; cat event" 3>&- &
  pids+=("$!")
  local _
  for _ in $(seq 100); do
    [ -S "$sock" ] && break
    sleep 0.05
  done
  [ -S "$sock" ] || fail "the fake event socket never appeared at $sock"

  run "$sdrGameMode"
}

# expect_commands [line...]: the run exited cleanly and sent exactly these hyprctl commands.
expect_commands() {
  assert_success
  refute_output --partial "could not"
  if [ "$#" -eq 0 ]; then
    assert_equal "$(cat commands.log)" ""
  else
    assert_equal "$(cat commands.log)" "$(printf '%s\n' "$@")"
  fi
}

@test "switches an HDR monitor to sRGB for a fullscreen XWayland game" {
  scenario switches
  expect_commands "keyword monitor $sdr_rule"
}

@test "leaves the monitor in HDR for a game tagged keep-hdr" {
  scenario keep-hdr
  expect_commands
}

@test "leaves the monitor in HDR while the session toggle is paused" {
  touch "$XDG_RUNTIME_DIR/sdr-game-mode.paused"
  scenario paused
  expect_commands
}

@test "leaves the monitor in HDR for a Wayland game, which can carry HDR itself" {
  scenario wayland
  expect_commands
}

# Stand-ins for gamescope: the daemon reads HDR off its command line.
@test "switches to sRGB for a game in a gamescope started without HDR" {
  sleep 60 3>&- &
  pids+=("$!")
  scenario gamescope-sdr "$!"
  expect_commands "keyword monitor $sdr_rule"
}

@test "leaves the monitor in HDR for a game in a gamescope started with HDR" {
  bash -c 'sleep 60; :' gamescope --hdr-enabled 3>&- &
  pids+=("$!")
  scenario gamescope-hdr "$!"
  expect_commands
}

@test "leaves the monitor in HDR for a maximized game" {
  scenario maximized
  expect_commands
}

@test "ignores a fullscreen game on another workspace" {
  scenario other-workspace
  expect_commands
}

@test "moves a special workspace off the monitor before switching, since it blocks direct scanout" {
  scenario special
  expect_commands \
    "dispatch moveworkspacetomonitor special:special HDMI-A-1" \
    "keyword monitor $sdr_rule"
}

@test "keeps the monitor in sRGB when a notification takes the game out of fullscreen" {
  scenario unfullscreened
  expect_commands "keyword monitor $sdr_rule" reload
}

@test "restores HDR once the game that switched the monitor closes" {
  scenario closed
  expect_commands "keyword monitor $sdr_rule" reload reload
}

@test "restores HDR once the game that switched the monitor moves to another monitor" {
  scenario moved
  expect_commands "keyword monitor $sdr_rule" reload reload
}

@test "reloads to restore HDR once no SDR game is fullscreen" {
  scenario restore
  expect_commands reload reload
}

@test "never touches a monitor not declared HDR" {
  scenario sdr-monitor
  expect_commands
}

@test "reports a rejected switch instead of claiming it switched" {
  export REJECT="invalid resolution"
  scenario rejected
  expect_commands "keyword monitor $sdr_rule"
  assert_output --partial "was rejected: invalid resolution"
  refute_output --partial "switched it to sRGB"
}
