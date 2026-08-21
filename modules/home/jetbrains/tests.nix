# Suites over the REAL merge-settings.py, driven through its CLI against a
# synthetic plugin jar.
#
# These exist because the theme was written into options/ui.lnf.xml — IntelliJ's
# UISettings storage, not its look-and-feel storage — and nothing failed loudly:
# the editor scheme landed correctly, so only the chrome fell back to stock.
#
# Auto-discovered and wired into `nix flake check` by checks/module-tests.nix.
{pkgs, ...}: let
  inherit (pkgs) runCommand coreutils diffutils gnugrep python3;

  # Stand-in for the Catppuccin plugin: themeProvider -> theme json ->
  # bundledColorScheme is the indirection the editor scheme resolves through.
  mkFixture = pkgs.writeText "make-plugin-jar.py" ''
    import json, os, zipfile

    os.makedirs("pkg/lib", exist_ok=True)
    with zipfile.ZipFile("pkg/lib/theme.jar", "w") as z:
        z.writestr("META-INF/plugin.xml", (
            '<idea-plugin><extensions defaultExtensionNs="com.intellij">'
            '<themeProvider id="test.islands" path="/themes/islands.theme.json"/>'
            '<bundledColorScheme id="test.italics" path="/themes/italics"/>'
            '</extensions></idea-plugin>'
        ))
        z.writestr("themes/islands.theme.json", json.dumps(
            {"name": "Test Islands", "dark": True, "editorScheme": "/themes/italics.xml"}
        ))
        z.writestr("themes/italics.xml", (
            '<scheme name="Test Italics" version="142" parent_scheme="Darcula">'
            '<colors><option name="ADDED_LINES_COLOR" value="a6e3a1"/></colors>'
            '</scheme>'
        ))
  '';
in
  runCommand "jetbrains-settings-merge-tests" {
    nativeBuildInputs = [coreutils diffutils gnugrep python3];
  } ''
    py=${python3}/bin/python3
    merge=${./merge-settings.py}

    fail() { echo "FAIL: $1"; exit 1; }
    absent() { if grep -q "$2" "$1" 2>/dev/null; then fail "$3"; fi; }

    $py ${mkFixture}

    # Driven through the CLI so the rootDir -> options/ joining is covered too:
    # that join is exactly where the theme and the editor scheme diverged.
    cfg() {
      $py -c 'import json,sys; print(json.dumps({"ides":[{"rootDir":sys.argv[1],"packageDir":sys.argv[2],"theme":"test.islands","colorScheme":"Test Italics","ignoredFilePatterns":[],"keymap":None}]}))' "$1" "$PWD/pkg"
    }
    run() { $py "$merge" "$(cfg "$1")"; }

    echo "--- the UI theme lands in options/laf.xml, where the IDE reads it"
    rm -rf a; mkdir -p a
    run "$PWD/a"
    [ -f a/options/laf.xml ] || fail "no options/laf.xml written"
    grep -q 'name="LafManager"' a/options/laf.xml || fail "laf.xml carries no LafManager component"
    grep -q 'themeId="test.islands"' a/options/laf.xml || fail "laf.xml does not carry the requested theme"
    grep -q 'preferred-dark-laf themeId="test.islands"' a/options/laf.xml || fail "dark theme preference not recorded"
    grep -q 'preferred-dark-editor-scheme editorSchemeId="test.italics"' a/options/laf.xml || fail "editor scheme not resolved out of the plugin jar"

    echo "--- and nowhere else: a LafManager outside laf.xml is ignored by the IDE"
    for f in a/options/*.xml; do
      [ "$f" = "a/options/laf.xml" ] && continue
      absent "$f" 'name="LafManager"' "LafManager leaked into $f"
    done

    echo "--- the editor scheme is materialized and referenced by its id"
    grep -q 'global_color_scheme name="test.italics"' a/options/colors.scheme.xml || fail "colors.scheme.xml does not reference the resolved id"
    [ -f a/colors/test.italics.icls ] || fail "scheme was not materialized"
    grep -q 'name="test.italics"' a/colors/test.italics.icls || fail "materialized scheme was not renamed to its id"
    grep -q 'a6e3a1' a/colors/test.italics.icls || fail "materialized scheme lost its colors"

    echo "--- merging twice changes nothing and duplicates no children"
    cp a/options/laf.xml first
    run "$PWD/a"
    cmp -s first a/options/laf.xml || fail "second merge produced different output"
    n=$(grep -o '<laf ' a/options/laf.xml | wc -l)
    [ "$n" = 1 ] || fail "laf element duplicated ($n copies)"

    echo "--- state the IDE itself wrote into laf.xml survives the merge"
    rm -rf b; mkdir -p b/options
    printf '%s\n' '<application><component name="LafManager"><lafs-to-previous-schemes><laf-to-scheme laf="Islands Dark" scheme="keepme"/></lafs-to-previous-schemes></component></application>' > b/options/laf.xml
    run "$PWD/b"
    grep -q 'keepme' b/options/laf.xml || fail "clobbered the IDE's own LafManager state"
    grep -q 'themeId="test.islands"' b/options/laf.xml || fail "theme not applied alongside existing state"

    echo "--- a stale LafManager in ui.lnf.xml is purged, its neighbours kept"
    rm -rf c; mkdir -p c/options
    printf '%s\n' '<application><component name="LafManager"><laf themeId="old"/></component><component name="UISettings"><option name="X" value="1"/></component></application>' > c/options/ui.lnf.xml
    run "$PWD/c"
    [ -f c/options/ui.lnf.xml ] || fail "deleted ui.lnf.xml while it still held UISettings"
    absent c/options/ui.lnf.xml 'name="LafManager"' "stale LafManager was not purged"
    grep -q 'name="UISettings"' c/options/ui.lnf.xml || fail "purge took UISettings with it"

    echo "--- ui.lnf.xml is deleted when the stale block was all it held"
    rm -rf d; mkdir -p d/options
    printf '%s\n' '<application><component name="LafManager"><laf themeId="old"/></component></application>' > d/options/ui.lnf.xml
    run "$PWD/d"
    [ ! -e d/options/ui.lnf.xml ] || fail "left an empty ui.lnf.xml behind"

    echo "--- a home-manager symlink is never written through"
    rm -rf e; mkdir -p e/options
    printf '%s\n' '<application><component name="LafManager"><laf themeId="old"/></component></application>' > store-ui.xml
    chmod 444 store-ui.xml
    ln -s "$PWD/store-ui.xml" e/options/ui.lnf.xml
    run "$PWD/e"
    grep -q 'themeId="old"' store-ui.xml || fail "wrote through a symlink into the store"
    [ -L e/options/ui.lnf.xml ] || fail "replaced the symlink instead of leaving it alone"

    echo "all jetbrains settings-merge tests passed"
    touch $out
  ''
