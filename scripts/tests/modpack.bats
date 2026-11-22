# The REAL modpack.sh compat and upgrade-target against a fake curl that serves Modrinth answers from $MODRINTH.

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert

  export OUT=$BATS_TEST_TMPDIR
  export MODPACKS_DIR=$OUT/modpacks MODRINTH=$OUT/modrinth
  PACK=$MODPACKS_DIR/fixture
  mkdir -p "$PACK/mods" "$MODRINTH" "$OUT/bin"

  printf '#!%s\n' "$BASH" >"$OUT/bin/curl"
  cat >>"$OUT/bin/curl" <<'EOF'
url="${*: -1}"
echo "$url" >>"$OUT/curl-urls"
case "$url" in
*/tag/game_version) file=$MODRINTH/releases.json ;;
*/project/*/version*) id=${url#*/project/} && file=$MODRINTH/${id%%/*}.json ;;
esac
# curl -f's exit code for an HTTP error
[ -f "${file:-}" ] || exit 22
cat "$file"
EOF
  chmod +x "$OUT/bin/curl"
  export PATH="$OUT/bin:$PATH"

  pack_on fabric 1.21.11
  releases 26.4-snapshot-1 26.3 26.2 26.1 1.21.11 1.21.10
  add_mod alpha AAA 26.3 26.2 26.1 1.21.11
  # Never tagged for the pack's own version, though the pack runs it.
  add_mod beta BBB 26.2 26.1 1.21.10
  add_mod gamma CCC 26.2 1.21.11
}

pack_on() {
  printf 'name = "fixture"\n\n[versions]\n%s = "0.18.0"\nminecraft = "%s"\n' "$1" "$2" >"$PACK/pack.toml"
}

# Newest first, as Modrinth lists them; *-snapshot-* entries are typed as snapshots.
releases() {
  jq -n '[$ARGS.positional[] | {version: ., version_type: (if test("snapshot") then "snapshot" else "release" end)}]' \
    --args "$@" >"$MODRINTH/releases.json"
}

add_mod() {
  local slug=$1 id=$2
  shift 2
  printf 'name = "%s"\nfilename = "%s.jar"\n\n[update.modrinth]\nmod-id = "%s"\n' "$slug" "$slug" "$id" >"$PACK/mods/$slug.pw.toml"
  jq -n '[{game_versions: $ARGS.positional}]' --args "$@" >"$MODRINTH/$id.json"
}

modpack_plain() {
  run bash -c 'bash "$0" "$@" 2>&1 | sed "s/\x1b\[[0-9;]*m//g"; exit "${PIPESTATUS[0]}"' "$modpack" "$@"
}

@test "upgrade-target names the newest release every mod has a build for" {
  modpack_plain upgrade-target fixture
  assert_success
  assert_output --partial "Newest version all 3 mods support: 26.2 (pack is on 1.21.11)"
}

@test "upgrade-target lists the mods blocking each newer release" {
  modpack_plain upgrade-target fixture
  assert_success
  assert_output --partial "26.3 — 2 missing:
    ✗ beta
    ✗ gamma"
}

@test "upgrade-target stops at the pack's own version, even for a mod not tagged for it" {
  add_mod gamma CCC 1.21.11
  modpack_plain upgrade-target fixture
  assert_success
  assert_output --partial "No release newer than 1.21.11 is supported by all 3 mods; stay on 1.21.11."
  refute_output --partial "1.21.11 —"
}

@test "upgrade-target asks Modrinth for builds on the pack's loader" {
  pack_on quilt 1.21.11
  modpack_plain upgrade-target fixture
  assert_success
  run grep -c 'loaders=%5B%22quilt%22%5D' "$OUT/curl-urls"
  assert_output 3
}

@test "upgrade-target fails rather than answer when a mod's lookup fails" {
  rm "$MODRINTH/BBB.json"
  modpack_plain upgrade-target fixture
  assert_failure 1
  assert_output --partial "Error: Modrinth request failed for beta (BBB)"
  refute_output --partial "Newest version"
}

@test "compat reports each missing mod's newest supported release, 26.x included" {
  modpack_plain compat fixture 26.1
  assert_success
  assert_output --regexp "✗ gamma +\(newest release supported: 26.2\)"
  assert_output --partial "Summary: 2 supported, 1 unsupported"
}

@test "compat fails rather than count a mod unsupported when its lookup fails" {
  rm "$MODRINTH/CCC.json"
  modpack_plain compat fixture 26.1
  assert_failure 1
  assert_output --partial "Error: Modrinth request failed for gamma (CCC)"
  refute_output --partial "Summary"
}

@test "compat fails on a mod with no Modrinth mod-id instead of skipping it" {
  printf 'name = "local"\nfilename = "local.jar"\n' >"$PACK/mods/local.pw.toml"
  modpack_plain compat fixture 26.1
  assert_failure 1
  assert_output --partial "Error: local.pw.toml has no Modrinth mod-id; can't check it"
}
