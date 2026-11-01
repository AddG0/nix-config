# A ReShade preset's effect file names are lowercased to match nix-reshade's
# shader files, keeping the preset's Windows line endings.

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert
}

@test "a preset's effect file names are lowercased to match the shader files" {
  assert_equal "$(cat -v "$presetOut")" "$(cat -v "$presetWant")"
  # cat -v under $() drops trailing newlines; cmp catches a difference there.
  run cmp "$presetWant" "$presetOut"
  assert_success
}
