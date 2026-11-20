# The REAL listener against stand-in socat and hyprctl (see ./script.nix).
#   $EVENTS      Hyprland events the listener reads, one per line
#   $CLIENTS     what `hyprctl -j clients` answers
#   $DISPATCHED  every dispatch the listener sent, one per line

setup() {
  bats_require_minimum_version 1.5.0
  bats_load_library bats-support
  bats_load_library bats-assert

  export XDG_RUNTIME_DIR=$BATS_TEST_TMPDIR HYPRLAND_INSTANCE_SIGNATURE=test
  export EVENTS=$BATS_TEST_TMPDIR/events CLIENTS=$BATS_TEST_TMPDIR/clients DISPATCHED=$BATS_TEST_TMPDIR/dispatched
  : >"$DISPATCHED"
}

# client ADDRESS WORKSPACE FLOATING FULLSCREEN [PINNED]
client() {
  printf '{"address":"%s","workspace":{"id":%s},"floating":%s,"fullscreen":%s,"pinned":%s}\n' \
    "$1" "$2" "$3" "$4" "${5:-false}"
}

clients() { jq -s . >"$CLIENTS"; }

opens() { printf 'openwindow>>%s,%s,%s,%s\n' "${1#0x}" "$2" "$3" "$4" >>"$EVENTS"; }

video_fullscreen_on_6() { client 0xvideo 6 false 2; }

@test "lowers a floating window that opens on a workspace showing a fullscreen window" {
  {
    video_fullscreen_on_6
    client 0xprompt 6 true 0
  } | clients
  opens 0xprompt 6 com.onepassword.OnePassword 1Password

  run "$listener"

  assert_equal "$(cat "$DISPATCHED")" "alterzorder bottom,address:0xprompt"
}

@test "leaves a floating window above when its workspace has no fullscreen window" {
  {
    client 0xvideo 6 false 0
    client 0xprompt 6 true 0
  } | clients
  opens 0xprompt 6 com.onepassword.OnePassword 1Password

  run "$listener"

  assert_equal "$(cat "$DISPATCHED")" ""
}

@test "leaves a floating window above when the fullscreen window is on another workspace" {
  {
    video_fullscreen_on_6
    client 0xprompt 2 true 0
  } | clients
  opens 0xprompt 2 com.onepassword.OnePassword 1Password

  run "$listener"

  assert_equal "$(cat "$DISPATCHED")" ""
}

@test "leaves a tiled window alone, since Hyprland already maps it under the fullscreen window" {
  {
    video_fullscreen_on_6
    client 0xterm 6 false 0
  } | clients
  opens 0xterm 6 com.mitchellh.ghostty Ghostty

  run "$listener"

  assert_equal "$(cat "$DISPATCHED")" ""
}

@test "leaves a pinned picture-in-picture window above the fullscreen window" {
  {
    video_fullscreen_on_6
    client 0xpip 6 true 0 true
  } | clients
  opens 0xpip 6 zen-beta Picture-in-Picture

  run "$listener"

  assert_equal "$(cat "$DISPATCHED")" ""
}

@test "leaves a Safe Eyes break above the fullscreen window" {
  {
    video_fullscreen_on_6
    client 0xbreak 6 true 0
  } | clients
  opens 0xbreak 6 io.github.slgobinath.SafeEyes SafeEyes-HDMI-A-1

  run "$listener"

  assert_equal "$(cat "$DISPATCHED")" ""
}

@test "reports a refused lowering and keeps handling later windows" {
  {
    video_fullscreen_on_6
    client 0xfirst 6 true 0
    client 0xsecond 6 true 0
  } | clients
  opens 0xfirst 6 zenity first
  opens 0xsecond 6 zenity second
  export DISPATCH_REPLY="window not found"

  run --separate-stderr "$listener"

  assert_stderr --partial "lowering window 0xfirst under fullscreen failed (hyprctl exit 0): window not found"
  assert_equal "$(cat "$DISPATCHED")" $'alterzorder bottom,address:0xfirst\nalterzorder bottom,address:0xsecond'
}

@test "reports a failed client listing and keeps listening" {
  {
    video_fullscreen_on_6
    client 0xprompt 6 true 0
  } | clients
  opens 0xprompt 6 zenity prompt
  export CLIENTS_FAIL=1

  run --separate-stderr "$listener"

  assert_stderr --partial "listing clients for new window 0xprompt failed"
  assert_stderr --partial "Hyprland event socket"
  assert_equal "$(cat "$DISPATCHED")" ""
}

@test "reports unreadable client data and keeps handling later windows" {
  echo 'not json' >"$CLIENTS"
  opens 0xfirst 6 zenity first
  opens 0xsecond 6 zenity second

  run --separate-stderr "$listener"

  assert_stderr --partial "reading clients for new window 0xfirst failed (jq exit"
  assert_stderr --partial "reading clients for new window 0xsecond failed (jq exit"
  assert_equal "$(cat "$DISPATCHED")" ""
}

@test "exits with an error when the event socket closes, so systemd restarts it" {
  echo '[]' >"$CLIENTS"
  : >"$EVENTS"

  run --separate-stderr "$listener"

  assert_failure 1
  assert_stderr "Hyprland event socket $BATS_TEST_TMPDIR/hypr/test/.socket2.sock closed"
}
