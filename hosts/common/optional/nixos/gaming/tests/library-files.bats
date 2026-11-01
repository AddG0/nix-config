# library-files against a one-game library whose dxgi.dll the game shipped itself.

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert
  bats_load_library bats-file
  bats_require_minimum_version 1.5.0

  export XDG_DATA_HOME=$BATS_TEST_TMPDIR/state
  library=$BATS_TEST_TMPDIR/library
  game=$library/steamapps/common/Game
  mkdir -p "$game"
  printf '"AppState"\n{\n\t"appid"\t\t"10"\n\t"installdir"\t\t"Game"\n}\n' >"$library/steamapps/appmanifest_10.acf"
  echo shipped >"$game/dxgi.dll"
}

@test "declared files are placed over the game's own" {
  "$place" "$library" "$declared"
  assert_equal "$(cat "$game/dxgi.dll")" reshade
  assert_equal "$(cat "$game/reshade-shaders/sweetfx/dpx.fx")" "technique DPX {}"
}

@test "a seed file is group-writable for the player and an enforced one keeps 644" {
  "$place" "$library" "$declared"
  assert_equal "$(stat -c %a "$game/Look.ini")" 664
  assert_equal "$(stat -c %a "$game/dxgi.dll")" 644
}

@test "a rerun with the same list changes no placed file" {
  "$place" "$library" "$declared"
  "$place" "$library" "$declared"
  assert_equal "$(cat "$game/dxgi.dll")" reshade
}

@test "an empty list restores the game's own file and removes placed ones" {
  "$place" "$library" "$declared"
  "$place" "$library" "$nothing"
  assert_equal "$(cat "$game/dxgi.dll")" shipped
  assert_not_exists "$game/reshade-shaders/sweetfx/dpx.fx"
}

@test "a reinstalled game gets its declared files back" {
  "$place" "$library" "$declared"
  rm -rf "$game"
  mkdir -p "$game"
  "$place" "$library" "$declared"
  assert_equal "$(cat "$game/dxgi.dll")" reshade
}

@test "a file that cannot be placed fails the run and is named on stderr" {
  run --separate-stderr "$place" "$library" "$unplaceable"
  assert_failure
  assert_equal "${stderr_lines[-1]}" "library-files: app 10: game/missing.dll"
}
