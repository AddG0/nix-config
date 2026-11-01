# merge-settings.py's CLI against the plugin jar ./script.nix describes.

setup_file() {
  cd "$BATS_FILE_TMPDIR" || return
  python3 "$mkFixture"
  export PKG=$BATS_FILE_TMPDIR/pkg
}

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert
  bats_load_library bats-file

  cd "$BATS_TEST_TMPDIR" || return
}

# Driven through the CLI so the rootDir -> options/ joining is covered too:
# that join is exactly where the theme and the editor scheme diverged.
merge_into() {
  local cfg
  cfg=$(python3 -c 'import json,sys; print(json.dumps({"ides":[{"rootDir":sys.argv[1],"packageDir":sys.argv[2],"theme":"test.islands","colorScheme":"Test Italics","ignoredFilePatterns":[],"keymap":json.loads(sys.argv[3])}]}))' "$PWD/$1" "$PKG" "${2:-null}")
  python3 "$merge" "$cfg"
}

keymap='{"name":"Test Custom","parent":"Test Base","actions":{"EditorEscape":[],"Terminal.Paste":["ctrl shift V"]}}'

@test "the UI theme lands in options/laf.xml, where the IDE reads it" {
  mkdir a
  merge_into a
  assert_file_exists a/options/laf.xml
  run cat a/options/laf.xml
  assert_output --partial 'name="LafManager"'
  assert_output --partial 'themeId="test.islands"'
  assert_output --partial 'preferred-dark-laf themeId="test.islands"'
  assert_output --partial 'preferred-dark-editor-scheme editorSchemeId="test.italics"'
}

@test "no options file but laf.xml carries a LafManager, which the IDE would ignore" {
  mkdir a
  merge_into a
  local f others=0
  for f in a/options/*.xml; do
    [ "$f" = a/options/laf.xml ] && continue
    others=$((others + 1))
    run cat "$f"
    assert_success
    refute_output --partial 'name="LafManager"'
  done
  # Otherwise the loop proves nothing.
  assert [ "$others" -gt 0 ]
}

@test "the editor scheme is materialized and referenced by its id" {
  mkdir a
  merge_into a
  run cat a/options/colors.scheme.xml
  assert_success
  assert_output --partial 'global_color_scheme name="test.italics"'
  assert_file_exists a/colors/test.italics.icls
  run cat a/colors/test.italics.icls
  assert_output --partial 'name="test.italics"'
  assert_output --partial 'a6e3a1'
}

@test "merging twice changes nothing and duplicates no children" {
  mkdir a
  merge_into a
  cp a/options/laf.xml first
  merge_into a
  run diff -u first a/options/laf.xml
  assert_success
  assert_equal "$(grep -o '<laf ' a/options/laf.xml | wc -l)" 1
}

@test "state the IDE itself wrote into laf.xml survives the merge" {
  mkdir -p b/options
  printf '%s\n' '<application><component name="LafManager"><lafs-to-previous-schemes><laf-to-scheme laf="Islands Dark" scheme="keepme"/></lafs-to-previous-schemes></component></application>' >b/options/laf.xml
  merge_into b
  run cat b/options/laf.xml
  assert_output --partial 'scheme="keepme"'
  assert_output --partial 'themeId="test.islands"'
}

@test "a stale LafManager in ui.lnf.xml is purged and its neighbours kept" {
  mkdir -p c/options
  printf '%s\n' '<application><component name="LafManager"><laf themeId="old"/></component><component name="UISettings"><option name="X" value="1"/></component></application>' >c/options/ui.lnf.xml
  merge_into c
  assert_file_exists c/options/ui.lnf.xml
  run cat c/options/ui.lnf.xml
  assert_success
  refute_output --partial 'name="LafManager"'
  assert_output --partial 'name="UISettings"'
}

@test "ui.lnf.xml is deleted when the stale LafManager was all it held" {
  mkdir -p d/options
  printf '%s\n' '<application><component name="LafManager"><laf themeId="old"/></component></application>' >d/options/ui.lnf.xml
  merge_into d
  assert_not_exists d/options/ui.lnf.xml
}

@test "a home-manager symlink in place of ui.lnf.xml is never written through" {
  mkdir -p e/options
  printf '%s\n' '<application><component name="LafManager"><laf themeId="old"/></component></application>' >store-ui.xml
  chmod 444 store-ui.xml
  ln -s "$PWD/store-ui.xml" e/options/ui.lnf.xml
  merge_into e
  run cat store-ui.xml
  assert_output --partial 'themeId="old"'
  assert_link_exists e/options/ui.lnf.xml
  assert_symlink_to "$PWD/store-ui.xml" e/options/ui.lnf.xml
}

@test "a home-manager symlink in place of colors.scheme.xml is replaced, not written through" {
  mkdir -p f/options
  printf 'old\n' >store-colors.xml
  chmod 444 store-colors.xml
  ln -s "$PWD/store-colors.xml" f/options/colors.scheme.xml
  merge_into f
  assert [ ! -L f/options/colors.scheme.xml ]
  run cat f/options/colors.scheme.xml
  assert_output --partial 'global_color_scheme name="test.italics"'
  assert_equal "$(cat store-colors.xml)" old
}

@test "a keymap keeps its bundled parent's actions and overrides only the ones it sets" {
  mkdir g
  merge_into g "$keymap"
  assert_file_exists "g/keymaps/Test Custom.xml"
  run cat "g/keymaps/Test Custom.xml"
  assert_output --partial 'name="Test Custom"'
  # The bundled parent is inlined, so the keymap points past it.
  assert_output --partial 'parent="$default"'
  assert_output --partial '<action id="Keep"><keyboard-shortcut first-keystroke="ctrl k" /></action>'
  assert_output --partial '<action id="Terminal.Paste"><keyboard-shortcut first-keystroke="ctrl shift V" /></action>'
  refute_output --partial 'ctrl alt v'
  assert_output --partial '<action id="EditorEscape" />'
}

@test "a home-manager symlink in place of the keymap is replaced, not written through" {
  mkdir -p h/keymaps
  printf 'old\n' >store-keymap.xml
  chmod 444 store-keymap.xml
  ln -s "$PWD/store-keymap.xml" "h/keymaps/Test Custom.xml"
  merge_into h "$keymap"
  assert [ ! -L "h/keymaps/Test Custom.xml" ]
  run cat "h/keymaps/Test Custom.xml"
  assert_output --partial 'name="Test Custom"'
  assert_equal "$(cat store-keymap.xml)" old
}
