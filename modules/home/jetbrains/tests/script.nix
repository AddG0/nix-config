# Suites over the REAL merge-settings.py, driven through its CLI against a
# synthetic plugin jar: ./merge.bats.
#
# These exist because the theme was written into options/ui.lnf.xml — IntelliJ's
# UISettings storage, not its look-and-feel storage — and nothing failed loudly:
# the editor scheme landed correctly, so only the chrome fell back to stock.
{
  harness,
  pkgs,
  ...
}: let
  inherit (pkgs) coreutils diffutils gnugrep python3;

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
        z.writestr("keymaps/base.xml", (
            '<keymap version="1" name="Test Base" parent="$default">'
            '<action id="Keep"><keyboard-shortcut first-keystroke="ctrl k"/></action>'
            '<action id="Terminal.Paste"><keyboard-shortcut first-keystroke="ctrl alt v"/></action>'
            '</keymap>'
        ))
  '';
in
  harness.bats "jetbrains-settings-merge-tests" [./merge.bats] {
    nativeBuildInputs = [coreutils diffutils gnugrep python3];
    merge = "${../merge-settings.py}";
    inherit mkFixture;
  }
