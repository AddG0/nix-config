import json
import os
import sys
import xml.etree.ElementTree as ET
import zipfile


def read_manifest(path):
    if not os.path.exists(path):
        return set()
    with open(path) as f:
        return {line.strip() for line in f if line.strip()}


def write_manifest(path, entries):
    with open(path, "w") as f:
        f.write("\n".join(sorted(entries)) + "\n")


def merge_ignored(ide_dir, patterns):
    target = os.path.join(ide_dir, "filetypes.xml")
    manifest_dir = os.path.join(ide_dir, ".nix-managed")
    manifest = os.path.join(manifest_dir, "filetypes.ignoreFiles.manifest")

    os.makedirs(manifest_dir, exist_ok=True)

    old_managed = read_manifest(manifest)
    new_managed = set(patterns)

    if not os.path.exists(target):
        root = ET.Element("application")
        ET.SubElement(root, "component", name="FileTypeManager", version="19")
    else:
        root = ET.parse(target).getroot()

    ftm = root.find(".//component[@name='FileTypeManager']")
    if ftm is None:
        return

    ignore_elem = ftm.find("ignoreFiles")
    if ignore_elem is None:
        ignore_elem = ET.SubElement(ftm, "ignoreFiles")
        current = set()
    else:
        current = set(ignore_elem.get("list", "").split(";")) - {""}

    merged = (current - old_managed) | new_managed
    ignore_elem.set("list", ";".join(sorted(merged)))

    ET.ElementTree(root).write(target, xml_declaration=False)
    write_manifest(manifest, merged)


def write_text_file(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if os.path.islink(path):
        os.unlink(path)
    with open(path, "w") as f:
        f.write(content)


def iter_plugin_archives(package_dir):
    for dirpath, _, filenames in os.walk(package_dir, followlinks=True):
        for filename in filenames:
            if filename.endswith(".jar"):
                yield os.path.join(dirpath, filename)


def normalize_resource_path(path):
    if path.startswith("/"):
        path = path[1:]
    return path


def resource_stem(path):
    normalized = normalize_resource_path(path)
    if normalized.endswith(".xml"):
        normalized = normalized[:-4]
    return normalized


def find_theme_preferences(package_dir, theme_id):
    for archive_path in iter_plugin_archives(package_dir):
        with zipfile.ZipFile(archive_path) as archive:
            if "META-INF/plugin.xml" not in archive.namelist():
                continue

            try:
                plugin_root = ET.fromstring(archive.read("META-INF/plugin.xml"))
            except ET.ParseError:
                continue

            extensions = plugin_root.find("extensions")
            if extensions is None:
                continue

            theme_provider = None
            bundled_schemes = {}
            for child in extensions:
                if child.tag == "themeProvider" and child.get("id") == theme_id:
                    theme_provider = child
                elif child.tag == "bundledColorScheme":
                    path = child.get("path")
                    scheme_id = child.get("id")
                    if path and scheme_id:
                        bundled_schemes[resource_stem(path)] = scheme_id

            if theme_provider is None:
                continue

            theme_path = theme_provider.get("path")
            if not theme_path:
                continue

            theme_json_path = normalize_resource_path(theme_path)
            if theme_json_path not in archive.namelist():
                continue

            metadata = json.loads(archive.read(theme_json_path))
            editor_scheme = metadata.get("editorScheme")
            if not editor_scheme:
                return {"dark": bool(metadata.get("dark")), "editor_scheme_id": None}

            return {
                "dark": bool(metadata.get("dark")),
                "editor_scheme_id": bundled_schemes.get(resource_stem(editor_scheme)),
            }

    return None


def find_bundled_color_scheme_id(package_dir, scheme_name):
    for archive_path in iter_plugin_archives(package_dir):
        with zipfile.ZipFile(archive_path) as archive:
            if "META-INF/plugin.xml" not in archive.namelist():
                continue

            try:
                plugin_root = ET.fromstring(archive.read("META-INF/plugin.xml"))
            except ET.ParseError:
                continue

            extensions = plugin_root.find("extensions")
            if extensions is None:
                continue

            for child in extensions:
                if child.tag != "bundledColorScheme":
                    continue
                path = child.get("path")
                scheme_id = child.get("id")
                if not path or not scheme_id:
                    continue

                xml_path = f"{resource_stem(path)}.xml"
                if xml_path not in archive.namelist():
                    continue

                try:
                    root = ET.fromstring(archive.read(xml_path))
                except ET.ParseError:
                    continue

                if root.tag == "scheme" and root.get("name") == scheme_name:
                    return scheme_id

    return None


def find_bundled_color_scheme_xml(package_dir, scheme_name):
    for archive_path in iter_plugin_archives(package_dir):
        with zipfile.ZipFile(archive_path) as archive:
            for name in archive.namelist():
                if not name.startswith("themes/") or not name.endswith(".xml"):
                    continue
                try:
                    root = ET.fromstring(archive.read(name))
                except ET.ParseError:
                    continue
                if root.tag == "scheme" and root.get("name") == scheme_name:
                    return ET.tostring(root, encoding="unicode") + "\n"
    return None


def write_materialized_color_scheme(ide_dir, package_dir, scheme_name):
    scheme_id = find_bundled_color_scheme_id(package_dir, scheme_name)
    content = find_bundled_color_scheme_xml(package_dir, scheme_name)
    if scheme_id is None or content is None:
        return None

    root = ET.fromstring(content)
    root.set("name", scheme_id)
    target = os.path.join(ide_dir, "colors", f"{scheme_id}.icls")
    write_text_file(target, ET.tostring(root, encoding="unicode") + "\n")
    return scheme_id


def find_bundled_keymap(package_dir, keymap_name):
    for archive_path in iter_plugin_archives(package_dir):
        with zipfile.ZipFile(archive_path) as archive:
            for name in archive.namelist():
                if not name.startswith("keymaps/") or not name.endswith(".xml"):
                    continue
                try:
                    root = ET.fromstring(archive.read(name))
                except ET.ParseError:
                    continue
                if root.tag == "keymap" and root.get("name") == keymap_name:
                    return root
    return None


def find_or_create_component(root, name):
    component = root.find(f".//component[@name='{name}']")
    if component is None:
        component = ET.SubElement(root, "component", name=name)
    return component


def set_unique_child(element, tag, attributes):
    children = element.findall(tag)
    child = children[0] if children else ET.SubElement(element, tag)
    for extra in children[1:]:
        element.remove(extra)

    for key in list(child.attrib):
        if key not in attributes:
            del child.attrib[key]
    for key, value in attributes.items():
        child.set(key, value)
    for nested in list(child):
        child.remove(nested)
    return child


def replace_children(element, children):
    for child in list(element):
        element.remove(child)
    for child in children:
        element.append(child)


def merge_theme(ide_dir, theme):
    target = os.path.join(ide_dir, "ui.lnf.xml")

    if not os.path.exists(target):
        root = ET.Element("application")
    else:
        root = ET.parse(target).getroot()

    component = find_or_create_component(root, "LafManager")
    set_unique_child(component, "laf", {"themeId": theme})

    ET.ElementTree(root).write(target, xml_declaration=False)


def merge_theme_preferences(ide_dir, package_dir, theme):
    preferences = find_theme_preferences(package_dir, theme)
    if preferences is None:
        return

    target = os.path.join(ide_dir, "ui.lnf.xml")
    if not os.path.exists(target):
        root = ET.Element("application")
    else:
        root = ET.parse(target).getroot()

    component = find_or_create_component(root, "LafManager")
    theme_tag = "preferred-dark-laf" if preferences["dark"] else "preferred-light-laf"
    set_unique_child(component, theme_tag, {"themeId": theme})

    editor_scheme_id = preferences.get("editor_scheme_id")
    if editor_scheme_id:
        scheme_tag = "preferred-dark-editor-scheme" if preferences["dark"] else "preferred-light-editor-scheme"
        set_unique_child(component, scheme_tag, {"editorSchemeId": editor_scheme_id})

    ET.ElementTree(root).write(target, xml_declaration=False)


def write_color_scheme(ide_dir, package_dir, scheme_name):
    target = os.path.join(ide_dir, "options", "colors.scheme.xml")
    resolved_scheme = write_materialized_color_scheme(ide_dir, package_dir, scheme_name)
    if resolved_scheme is None:
        resolved_scheme = find_bundled_color_scheme_id(package_dir, scheme_name) or scheme_name
    content = f"""<application>
<component name=\"EditorColorsManagerImpl\">
  <global_color_scheme name=\"{resolved_scheme}\" />
</component>
</application>
"""
    write_text_file(target, content)


def merge_keymap(base_root, keymap):
    if base_root is None:
        root = ET.Element("keymap", version="1", name=keymap["name"], parent=keymap["parent"])
    else:
        root = ET.Element(
            "keymap",
            version=base_root.get("version", "1"),
            name=keymap["name"],
            parent=base_root.get("parent", "$default"),
        )
        for child in list(base_root):
            root.append(child)

    for action_id, keys in keymap["actions"].items():
        for existing in list(root.findall(f"action[@id='{action_id}']")):
            root.remove(existing)

        action = ET.SubElement(root, "action", id=action_id)
        for stroke in keys:
            ET.SubElement(action, "keyboard-shortcut", **{"first-keystroke": stroke})

    return ET.tostring(root, encoding="unicode") + "\n"


def write_keymap(ide_dir, keymap_name, keymap_xml):
    target = os.path.join(ide_dir, "keymaps", f"{keymap_name}.xml")
    write_text_file(target, keymap_xml)


def main():
    cfg = json.loads(sys.argv[1])

    for ide in cfg["ides"]:
        if ide["ignoredFilePatterns"]:
            merge_ignored(os.path.join(ide["rootDir"], "options"), ide["ignoredFilePatterns"])
        if ide.get("theme"):
            merge_theme(os.path.join(ide["rootDir"], "options"), ide["theme"])
            merge_theme_preferences(os.path.join(ide["rootDir"], "options"), ide["packageDir"], ide["theme"])
        if ide.get("colorScheme"):
            write_color_scheme(ide["rootDir"], ide["packageDir"], ide["colorScheme"])
        if ide.get("keymap"):
            base_keymap = find_bundled_keymap(ide["packageDir"], ide["keymap"]["parent"])
            write_keymap(ide["rootDir"], ide["keymap"]["name"], merge_keymap(base_keymap, ide["keymap"]))


if __name__ == "__main__":
    main()
