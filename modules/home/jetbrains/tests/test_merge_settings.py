import tempfile
import unittest
import xml.etree.ElementTree as ET
import importlib.util
import zipfile
import json
from pathlib import Path


MODULE_PATH = Path(__file__).resolve().parents[1] / "merge-settings.py"
SPEC = importlib.util.spec_from_file_location("merge_settings", MODULE_PATH)
assert SPEC is not None
merge_settings = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(merge_settings)


class MergeThemeTests(unittest.TestCase):
    def test_merge_theme_updates_laf_manager_in_ui_lnf(self):
        with tempfile.TemporaryDirectory() as tmp:
            ide_dir = Path(tmp)
            target = ide_dir / "ui.lnf.xml"
            target.write_text(
                """
<application>
  <component name="ProjectViewFileNesting">
    <nesting-rules />
  </component>
</application>
""".strip()
            )

            merge_settings.merge_theme(str(ide_dir), "theme.test")

            root = ET.parse(target).getroot()
            nesting = root.find(".//component[@name='ProjectViewFileNesting']")
            self.assertIsNotNone(nesting)
            laf = root.find(".//component[@name='LafManager']/laf")
            self.assertIsNotNone(laf)
            assert laf is not None
            self.assertEqual(laf.get("themeId"), "theme.test")

    def test_find_theme_preferences_resolves_bundled_scheme_id(self):
        with tempfile.TemporaryDirectory() as tmp:
            package_dir = Path(tmp)
            archive_path = package_dir / "plugin.jar"
            with zipfile.ZipFile(archive_path, "w") as archive:
                archive.writestr(
                    "META-INF/plugin.xml",
                    """
<idea-plugin>
  <extensions defaultExtensionNs="com.intellij">
    <themeProvider id="theme.test" path="/themes/mocha.theme.json" />
    <bundledColorScheme id="scheme.test" path="/themes/mocha" />
  </extensions>
</idea-plugin>
""".strip(),
                )
                archive.writestr("themes/mocha.theme.json", json.dumps({"dark": True, "editorScheme": "/themes/mocha.xml"}))

            result = merge_settings.find_theme_preferences(str(package_dir), "theme.test")

            self.assertEqual(result, {"dark": True, "editor_scheme_id": "scheme.test"})

    def test_merge_theme_preferences_writes_preferred_dark_entries(self):
        with tempfile.TemporaryDirectory() as tmp:
            ide_dir = Path(tmp)
            target = ide_dir / "ui.lnf.xml"
            target.write_text("<application><component name=\"LafManager\"><laf themeId=\"theme.test\" /></component></application>")

            package_dir = ide_dir / "package"
            package_dir.mkdir()
            archive_path = package_dir / "plugin.jar"
            with zipfile.ZipFile(archive_path, "w") as archive:
                archive.writestr(
                    "META-INF/plugin.xml",
                    """
<idea-plugin>
  <extensions defaultExtensionNs="com.intellij">
    <themeProvider id="theme.test" path="/themes/mocha.theme.json" />
    <bundledColorScheme id="scheme.test" path="/themes/mocha" />
  </extensions>
</idea-plugin>
""".strip(),
                )
                archive.writestr("themes/mocha.theme.json", json.dumps({"dark": True, "editorScheme": "/themes/mocha.xml"}))

            merge_settings.merge_theme_preferences(str(ide_dir), str(package_dir), "theme.test")

            root = ET.parse(target).getroot()
            preferred_laf = root.find(".//component[@name='LafManager']/preferred-dark-laf")
            preferred_scheme = root.find(".//component[@name='LafManager']/preferred-dark-editor-scheme")
            self.assertIsNotNone(preferred_laf)
            self.assertIsNotNone(preferred_scheme)
            assert preferred_laf is not None
            assert preferred_scheme is not None
            self.assertEqual(preferred_laf.get("themeId"), "theme.test")
            self.assertEqual(preferred_scheme.get("editorSchemeId"), "scheme.test")

    def test_write_color_scheme_replaces_symlink_with_writable_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            ide_dir = Path(tmp)
            options_dir = ide_dir / "options"
            options_dir.mkdir(parents=True)
            store_file = ide_dir / "store-colors.xml"
            store_file.write_text("old")
            (options_dir / "colors.scheme.xml").symlink_to(store_file)

            package_dir = ide_dir / "package"
            package_dir.mkdir()
            archive_path = package_dir / "plugin.jar"
            with zipfile.ZipFile(archive_path, "w") as archive:
                archive.writestr(
                    "META-INF/plugin.xml",
                    """
<idea-plugin>
  <extensions defaultExtensionNs="com.intellij">
    <bundledColorScheme id="scheme.test" path="/themes/mocha" />
  </extensions>
</idea-plugin>
""".strip(),
                )
                archive.writestr("themes/mocha.xml", '<scheme name="Catppuccin Mocha" version="1" parent_scheme="Darcula" />')

            merge_settings.write_color_scheme(str(ide_dir), str(package_dir), "Catppuccin Mocha")

            target = options_dir / "colors.scheme.xml"
            self.assertFalse(target.is_symlink())
            root = ET.parse(target).getroot()
            scheme = root.find(".//component[@name='EditorColorsManagerImpl']/global_color_scheme")
            self.assertIsNotNone(scheme)
            assert scheme is not None
            self.assertEqual(scheme.get("name"), "scheme.test")

            materialized = ide_dir / "colors" / "scheme.test.icls"
            self.assertTrue(materialized.exists())
            materialized_root = ET.parse(materialized).getroot()
            self.assertEqual(materialized_root.get("name"), "scheme.test")

    def test_write_keymap_replaces_symlink_with_writable_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            ide_dir = Path(tmp)
            keymaps_dir = ide_dir / "keymaps"
            keymaps_dir.mkdir(parents=True)
            store_file = ide_dir / "store-keymap.xml"
            store_file.write_text("old")
            target = keymaps_dir / "VSCode Custom.xml"
            target.symlink_to(store_file)

            merge_settings.write_keymap(str(ide_dir), "VSCode Custom", "<keymap version=\"1\" name=\"VSCode Custom\" parent=\"VSCode\" />\n")

            self.assertFalse(target.is_symlink())
            root = ET.parse(target).getroot()
            self.assertEqual(root.tag, "keymap")
            self.assertEqual(root.get("name"), "VSCode Custom")


    def test_find_bundled_color_scheme_xml_reads_scheme_from_plugin_archive(self):
        with tempfile.TemporaryDirectory() as tmp:
            package_dir = Path(tmp)
            archive_path = package_dir / "plugin.jar"
            with zipfile.ZipFile(archive_path, "w") as archive:
                archive.writestr("themes/mocha.xml", '<scheme name="Catppuccin Mocha" version="1" parent_scheme="Darcula" />')

            result = merge_settings.find_bundled_color_scheme_xml(str(package_dir), "Catppuccin Mocha")

            self.assertIn('name="Catppuccin Mocha"', result)

    def test_find_bundled_color_scheme_id_reads_scheme_id_from_plugin_archive(self):
        with tempfile.TemporaryDirectory() as tmp:
            package_dir = Path(tmp)
            archive_path = package_dir / "plugin.jar"
            with zipfile.ZipFile(archive_path, "w") as archive:
                archive.writestr(
                    "META-INF/plugin.xml",
                    """
<idea-plugin>
  <extensions defaultExtensionNs="com.intellij">
    <bundledColorScheme id="scheme.test" path="/themes/mocha" />
  </extensions>
</idea-plugin>
""".strip(),
                )
                archive.writestr("themes/mocha.xml", '<scheme name="Catppuccin Mocha" version="1" parent_scheme="Darcula" />')

            result = merge_settings.find_bundled_color_scheme_id(str(package_dir), "Catppuccin Mocha")

            self.assertEqual(result, "scheme.test")

    def test_merge_keymap_materializes_bundled_parent_actions(self):
        base_root = ET.fromstring(
            '<keymap version="1" name="VSCode" parent="$default">'
            '<action id="Keep"><keyboard-shortcut first-keystroke="ctrl k" /></action>'
            '<action id="Terminal.Paste"><keyboard-shortcut first-keystroke="ctrl alt v" /></action>'
            '</keymap>'
        )

        merged_xml = merge_settings.merge_keymap(
            base_root,
            {
                "name": "VSCode Custom",
                "parent": "VSCode",
                "actions": {
                    "EditorEscape": [],
                    "Terminal.Paste": ["ctrl shift V"],
                },
            },
        )

        root = ET.fromstring(merged_xml)
        self.assertEqual(root.get("name"), "VSCode Custom")
        self.assertEqual(root.get("parent"), "$default")
        self.assertIsNotNone(root.find("action[@id='Keep']"))
        paste = root.find("action[@id='Terminal.Paste']/keyboard-shortcut")
        self.assertIsNotNone(paste)
        assert paste is not None
        self.assertEqual(paste.get("first-keystroke"), "ctrl shift V")


if __name__ == "__main__":
    unittest.main()
