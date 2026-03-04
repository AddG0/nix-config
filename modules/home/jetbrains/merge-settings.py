import json
import os
import sys
import xml.etree.ElementTree as ET


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


def main():
    cfg = json.loads(sys.argv[1])

    for ide in cfg["ides"]:
        if ide["ignoredFilePatterns"]:
            merge_ignored(ide["configDir"], ide["ignoredFilePatterns"])


if __name__ == "__main__":
    main()
