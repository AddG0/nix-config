# The KWin layout SDDM starts with, rendered from a fixture display.monitors
# (DP-1, primary DP-4, then HDMI-A-2 at y=-240, scale 1.5, rotated 90) against a
# fake /sys/class/drm in which each connector's edid file holds its name.

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert

  drm=$BATS_TEST_TMPDIR/drm
  out=$BATS_TEST_TMPDIR/out/kwinoutputconfig.json
  for connector in DP-1 DP-4 HDMI-A-2; do
    mkdir -p "$drm/card1-$connector"
    printf '%s' "$connector" >"$drm/card1-$connector/edid"
  done
}

md5() { printf '%s' "$1" | md5sum | cut -d' ' -f1; }

@test "each output carries its connector's EDID md5, scale and KWin transform name" {
  "$kwinOutputs" "$drm" "$out"
  run jq -c '.[0].data[] | [.connectorName, .edidHash, .scale, .transform]' "$out"
  assert_success
  assert_equal "${lines[0]}" "[\"DP-1\",\"$(md5 DP-1)\",1.0,\"Normal\"]"
  assert_equal "${lines[1]}" "[\"DP-4\",\"$(md5 DP-4)\",1.0,\"Normal\"]"
  assert_equal "${lines[2]}" "[\"HDMI-A-2\",\"$(md5 HDMI-A-2)\",1.5,\"Rotated90\"]"
  assert_equal "${#lines[@]}" 3
}

@test "the setup keeps display.monitors positions and makes the primary monitor priority 0" {
  "$kwinOutputs" "$drm" "$out"
  run jq -c '.[1].data[0].outputs[] | [.outputIndex, .position.x, .position.y, .priority, .enabled]' "$out"
  assert_success
  assert_equal "${lines[0]}" '[0,0,0,1,true]'
  assert_equal "${lines[1]}" '[1,1920,0,0,true]'
  assert_equal "${lines[2]}" '[2,4480,-240,2,true]'
  assert_equal "${#lines[@]}" 3
}

@test "a disconnected connector of the same name on another GPU does not hide the connected one's EDID" {
  # card0 sorts first, so taking the first match would pick the empty edid.
  mkdir -p "$drm/card0-DP-4"
  : >"$drm/card0-DP-4/edid"
  "$kwinOutputs" "$drm" "$out"
  run jq -r '.[0].data[1].edidHash' "$out"
  assert_output "$(md5 DP-4)"
}

@test "a single-monitor layout builds and carries its connector's EDID md5" {
  "$kwinOutputsSingle" "$drm" "$out"
  run jq -c '[.[0].data[] | [.connectorName, .edidHash]]' "$out"
  assert_output "[[\"HDMI-A-2\",\"$(md5 HDMI-A-2)\"]]"
}

@test "a connector with an empty EDID gets no hash" {
  : >"$drm/card1-HDMI-A-2/edid"
  "$kwinOutputs" "$drm" "$out" 2>/dev/null
  run jq -r '.[0].data[2].edidHash' "$out"
  assert_output ""
}

@test "a missing EDID is reported with its connector and sysfs dir" {
  : >"$drm/card1-HDMI-A-2/edid"
  "$kwinOutputs" "$drm" "$out" 2>"$BATS_TEST_TMPDIR/err"
  run cat "$BATS_TEST_TMPDIR/err"
  assert_output --partial "no EDID for HDMI-A-2 under $drm"
}
