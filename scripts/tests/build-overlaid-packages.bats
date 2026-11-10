# The REAL build-overlaid-packages.sh's verdict, fed the JSON overlaid-packages.nix and nix-fast-build write.

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert
  source "$buildOverlaidPackages"

  overlaid="$BATS_TEST_TMPDIR/overlaid.json"
  results="$BATS_TEST_TMPDIR/result.json"
  cat >"$overlaid" <<'EOF'
{
  "overlaysByTarget": {
    "t3code": ["common/development/t3code/a.nix", "common/development/t3code/b.nix"],
    "lnav": ["common/development/lnav-json-append-bounds-check.nix"]
  },
  "nonPackageAttrPaths": [],
  "overlaysSettingNothing": []
}
EOF
}

results() {
  echo "{\"results\": [$1]}" >"$results"
}

ok() {
  echo "{\"type\": \"EVAL\", \"attr\": \"$1\", \"success\": true, \"error\": null}, {\"type\": \"BUILD\", \"attr\": \"$1\", \"success\": true, \"error\": null}"
}

@test "verdict passes when every target built or was cached" {
  results "$(ok t3code), $(ok lnav)"
  run verdict "$overlaid" "$results" 0
  assert_success
  assert_output --partial "✓ 2 built or cached"
}

@test "verdict fails on a failed build and names every overlay that patches it" {
  results "$(ok lnav), {\"type\": \"BUILD\", \"attr\": \"t3code\", \"success\": false, \"error\": \"build exited with 1\"}"
  run verdict "$overlaid" "$results" 1
  assert_failure
  assert_output --partial "✗ t3code  <- common/development/t3code/a.nix, common/development/t3code/b.nix"
  assert_output --partial "    build exited with 1"
}

@test "verdict shows the last error message of a failed evaluation" {
  results "$(ok lnav), {\"type\": \"EVAL\", \"attr\": \"t3code\", \"success\": false, \"error\": \"error:\\n       … while evaluating the attribute 'drvPath'\\n\\n       error: attribute 'gone' missing\"}"
  run verdict "$overlaid" "$results" 1
  assert_failure
  assert_output --partial "    error: attribute 'gone' missing"
}

@test "verdict fails when the result file cannot be read" {
  echo '{"results": null}' >"$results"
  run verdict "$overlaid" "$results" 0
  assert_failure
  assert_output --partial "✗ cannot read the build results"
}

@test "verdict fails when a target got no result at all" {
  results "$(ok lnav)"
  run verdict "$overlaid" "$results" 0
  assert_failure
  assert_output --partial "✗ t3code: no build result"
}

@test "verdict fails when nix-fast-build exited non-zero though no target failed" {
  results "$(ok t3code), $(ok lnav)"
  run verdict "$overlaid" "$results" 1
  assert_failure
  assert_output --partial "✗ nix-fast-build exited 1 without a failed target"
}

@test "verdict lists a target unsupported on this platform as skipped, not failed" {
  results "$(ok lnav), {\"type\": \"EVAL\", \"attr\": \"t3code\", \"success\": true, \"skipped\": true, \"error\": \"not available on the requested hostPlatform\"}"
  run verdict "$overlaid" "$results" 0
  assert_success
  assert_output --partial "– t3code: not built on this platform"
  assert_output --partial "✓ 1 built or cached"
}

@test "verdict lists what overlays set that is not a package, and overlays that set nothing themselves" {
  results "$(ok t3code), $(ok lnav)"
  jq '.nonPackageAttrPaths = ["common/input-packages/firefox-addons.nix: firefox-addons"] | .overlaysSettingNothing = ["common/input-packages/rust-overlay.nix"]' "$overlaid" >"$overlaid.new"
  mv "$overlaid.new" "$overlaid"
  run verdict "$overlaid" "$results" 0
  assert_success
  assert_output --partial "nothing to build: common/input-packages/firefox-addons.nix: firefox-addons"
  assert_output --partial "sets nothing itself here: common/input-packages/rust-overlay.nix"
}
