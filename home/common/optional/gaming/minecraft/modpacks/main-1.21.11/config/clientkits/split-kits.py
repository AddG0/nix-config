#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p "python3.withPackages(ps: [ps.pip])" -p gcc
"""Split a ClientKits mega-kit into individual kit files with slot remapping.

Usage: ./split-kits.py [input.json] [output-dir]

All item text is extracted directly from the source file (never serialized
through a library) to preserve ClientKits SNBT compatibility.
RapidNBT is used only for structural navigation.
"""
import re
import subprocess
import sys
import os
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
VENV_DIR = SCRIPT_DIR / ".venv"


def ensure_rapidnbt():
    try:
        import rapidnbt
        return
    except ImportError:
        pass
    python = VENV_DIR / "bin" / "python3"
    if not python.exists():
        print(f"Setting up venv at {VENV_DIR}...")
        subprocess.check_call([sys.executable, "-m", "venv", str(VENV_DIR)])
        subprocess.check_call([str(VENV_DIR / "bin" / "pip"), "install", "-q", "rapidnbt"])
    os.execv(str(python), [str(python)] + sys.argv)


ensure_rapidnbt()

import rapidnbt as nbt

# --- Config ---

TRIM_SNBT = {
    "_helmet":     '"minecraft:trim":{material:"minecraft:amethyst",pattern:"minecraft:flow"}',
    "_chestplate": '"minecraft:trim":{material:"minecraft:amethyst",pattern:"minecraft:dune"}',
    "_leggings":   '"minecraft:trim":{material:"minecraft:amethyst",pattern:"minecraft:flow"}',
    "_boots":      '"minecraft:trim":{material:"minecraft:amethyst",pattern:"minecraft:flow"}',
}

SLOT_MAP = {}
for i in range(4):
    SLOT_MAP[(0, i)] = 103 - i
SLOT_MAP[(0, 8)] = 40
for i in range(9):
    SLOT_MAP[(0, 18 + i)] = 9 + i
    SLOT_MAP[(1, i)] = 18 + i
    SLOT_MAP[(1, 9 + i)] = 27 + i
    SLOT_MAP[(1, 18 + i)] = i

FILLER_ITEMS = {"minecraft:gray_stained_glass_pane"}
STRIP_NAMES = ["Stacked"]

_heal_pot   = '{components:{"minecraft:potion_contents":{potion:"minecraft:strong_healing"}},count:1,id:"minecraft:splash_potion"}'
_str_pot    = '{components:{"minecraft:potion_contents":{potion:"minecraft:strong_strength"}},count:1,id:"minecraft:splash_potion"}'
_fire_pot   = '{components:{"minecraft:potion_contents":{potion:"minecraft:long_fire_resistance"}},count:1,id:"minecraft:splash_potion"}'
_harm_arrow = '{components:{"minecraft:potion_contents":{potion:"minecraft:strong_harming"}},count:1,id:"minecraft:tipped_arrow"}'
_slow_arrow = '{components:{"minecraft:potion_contents":{potion:"minecraft:strong_slowness"}},count:1,id:"minecraft:tipped_arrow"}'

MAP_ITEM_REPLACEMENTS = {
    "CPVP Kit":        {"kill_egg": '{count:1,id:"minecraft:totem_of_undying"}',  "reload": '{count:1,id:"minecraft:totem_of_undying"}',  "tp_bot": '{count:1,id:"minecraft:totem_of_undying"}'},
    "Tnt Cart Kit":    {"kill_egg": '{count:64,id:"minecraft:tnt_minecart"}',     "reload": '{count:64,id:"minecraft:arrow"}',            "tp_bot": '{count:64,id:"minecraft:tnt_minecart"}'},
    "Loka Pot Kit":    {"kill_egg": _heal_pot,                                    "reload": _heal_pot,                                    "tp_bot": _heal_pot},
    "SMP Kit":         {"kill_egg": '{count:16,id:"minecraft:ender_pearl"}',      "reload": _str_pot,                                     "tp_bot": '{count:16,id:"minecraft:ender_pearl"}'},
    "Neth Pot Kit":    {"kill_egg": _heal_pot,                                                                                            "tp_bot": '{count:64,id:"minecraft:experience_bottle"}'},
    "UHC Kit":         {                                                          "reload": '{count:1,id:"minecraft:golden_apple"}'},
    "BedPVP Kit":      {"kill_egg": '{count:16,id:"minecraft:ender_pearl"}',      "reload": '{count:1,id:"minecraft:purple_bed"}'},
    "Mace Kit":        {"kill_egg": '{count:64,id:"minecraft:wind_charge"}',      "reload": _str_pot,                                     "tp_bot": '{count:64,id:"minecraft:breeze_rod"}'},
    "Diamond SMP Kit": {"kill_egg": _fire_pot,                                    "reload": '{count:1,id:"minecraft:golden_apple"}',      "tp_bot": _fire_pot},
    "CPVP BPBoots Kit":{"kill_egg": '{count:1,id:"minecraft:totem_of_undying"}',  "reload": '{count:1,id:"minecraft:totem_of_undying"}',  "tp_bot": '{count:16,id:"minecraft:ender_pearl"}'},
    "Creeper PVP Kit": {"kill_egg": '{count:64,id:"minecraft:cobblestone"}',      "reload": _harm_arrow,                                  "tp_bot": _slow_arrow},
}

# --- Text helpers ---

def snbt_str(tag):
    return str(tag).strip('"')


def find_matching_brace(text, start):
    opener = text[start]
    closer = '}' if opener == '{' else ']'
    depth = 1
    i = start + 1
    in_str = False
    while i < len(text) and depth > 0:
        c = text[i]
        if c == '"' and (i == 0 or text[i-1] != '\\'):
            in_str = not in_str
        elif not in_str:
            if c == opener:
                depth += 1
            elif c == closer:
                depth -= 1
        i += 1
    return i


def detect_map_item(item):
    item_id = snbt_str(item["id"])
    if item_id == "minecraft:egg":
        return "kill_egg"
    if item.contains("components"):
        s = item["components"].to_snbt()
        if item_id == "minecraft:snowball" and ("BOT" in s or "Bot" in s or "Teleport" in s):
            return "tp_bot"
        if item_id == "minecraft:splash_potion" and ("Reload" in s or "Refill" in s):
            return "reload"
    return None


def get_trim(item_id):
    for suffix, trim in TRIM_SNBT.items():
        if item_id.endswith(suffix):
            return trim
    return None


def needs_name_strip(item):
    if not item.contains("components"):
        return False
    s = item["components"].to_snbt()
    return any(p in s for p in STRIP_NAMES)


def inject_trim(item_text, trim_snbt):
    if '"minecraft:trim"' in item_text:
        return item_text
    m = re.search(r'components:\s*\{', item_text)
    if not m:
        return item_text
    comp_start = m.end() - 1
    comp_end = find_matching_brace(item_text, comp_start)
    return item_text[:comp_end-1] + ',' + trim_snbt + item_text[comp_end-1:]


def strip_stacked_names(item_text):
    for p in STRIP_NAMES:
        item_text = re.sub(rf'"minecraft:item_name":\s*"[^"]*{p}[^"]*"', '"minecraft:item_name":""', item_text)
        item_text = re.sub(rf'"minecraft:custom_name":\s*"[^"]*{p}[^"]*"', '"minecraft:custom_name":""', item_text)
    item_text = re.sub(r',?"minecraft:enchantment_glint_override":\s*\w+,?',
                       lambda m: ',' if m.group().startswith(',') and m.group().endswith(',') else '', item_text)
    item_text = re.sub(r'\{,', '{', item_text)
    item_text = re.sub(r',\}', '}', item_text)
    return item_text


def extract_item_texts_from_container(source, container_text_start):
    """Find all {item:{...},slot:N} entries in a container region of the source text.
    Returns dict: slot_number -> item_text (the {...} after item:)
    """
    # Find the container array [ ... ]
    arr_match = re.search(r'"minecraft:container":\s*\[', source[container_text_start:])
    if not arr_match:
        return {}
    arr_start = container_text_start + arr_match.end() - 1
    arr_end = find_matching_brace(source, arr_start)
    region = source[arr_start:arr_end]

    result = {}
    pos = 0
    while pos < len(region):
        # Find item:{
        m = re.search(r'item:\s*\{', region[pos:])
        if not m:
            break
        item_brace = pos + m.end() - 1
        item_end = find_matching_brace(region, item_brace)
        item_text = region[item_brace:item_end]

        # Find slot:N near this item (in the enclosing entry compound)
        # Search after the item for slot:N
        after = region[item_end:item_end+30]
        slot_m = re.search(r'slot:\s*(\d+)', after)
        if slot_m:
            slot_num = int(slot_m.group(1))
            result[slot_num] = item_text

        pos = item_end

    return result


# --- Main ---

def main():
    input_path = Path(sys.argv[1]) if len(sys.argv) > 1 else SCRIPT_DIR / "kits" / "kits-no-trim.json"
    output_dir = Path(sys.argv[2]) if len(sys.argv) > 2 else SCRIPT_DIR / "kits"
    output_dir.mkdir(parents=True, exist_ok=True)

    source = input_path.read_text()
    root = nbt.CompoundTag.from_snbt(source)

    creator_m = re.search(r'creator:\s*"?(\w+)"?', source)
    dv_m = re.search(r'data_version:\s*(\d+)', source)
    mc_m = re.search(r'mc_version:\s*"([^"]+)"', source)
    creator = creator_m.group(1) if creator_m else "Unknown"
    data_version = dv_m.group(1) if dv_m else "4671"
    mc_version = mc_m.group(1) if mc_m else "1.21.11"

    # Find text positions of each bundle by searching for their unique names
    outer_container = root["inv"][0]["components"]["minecraft:container"]

    for bi in range(outer_container.size()):
        bundle = outer_container[bi]["item"]
        kit_name = snbt_str(bundle["components"]["minecraft:custom_name"])
        replacements = MAP_ITEM_REPLACEMENTS.get(kit_name, {})
        contents = bundle["components"]["minecraft:bundle_contents"]

        # Find this bundle's text region in source by its unique name
        name_pattern = f'"minecraft:custom_name":"{kit_name}"'
        name_pos = source.find(name_pattern)
        if name_pos == -1:
            print(f"  WARNING: Could not find {kit_name} in source text, skipping")
            continue

        # Find the bundle_contents region before this name
        # Search backwards for "minecraft:bundle_contents":[
        bundle_region_start = source.rfind('"minecraft:bundle_contents":[', max(0, name_pos - 50000), name_pos)
        if bundle_region_start == -1:
            print(f"  WARNING: Could not find bundle_contents for {kit_name}, skipping")
            continue

        inv_items = []

        for ci in range(contents.size()):
            chest = contents[ci]
            if not (chest.contains("components") and chest["components"].contains("minecraft:container")):
                continue

            chest_container = chest["components"]["minecraft:container"]

            # Find the Nth "minecraft:container":[ in the bundle region
            # ci=0 -> first container, ci=1 -> second container
            search_from = bundle_region_start
            for _ in range(ci + 1):
                cont_match = re.search(r'"minecraft:container":\s*\[', source[search_from:name_pos + 1000])
                if not cont_match:
                    break
                container_text_pos = search_from + cont_match.start()
                search_from = search_from + cont_match.end()

            # Extract all item texts from this container by slot number
            slot_to_text = extract_item_texts_from_container(source, container_text_pos)

            for j in range(chest_container.size()):
                entry = chest_container[j]
                if not entry.contains("item"):
                    continue

                chest_slot = int(str(entry["slot"])) if entry.contains("slot") else j
                inv_slot = SLOT_MAP.get((ci, chest_slot))
                if inv_slot is None:
                    continue

                item = entry["item"]
                item_id = snbt_str(item["id"])

                if item_id in FILLER_ITEMS:
                    continue

                # Map items -> raw replacement SNBT
                map_type = detect_map_item(item)
                if map_type:
                    if map_type in replacements:
                        inv_items.append(f'{{Slot:{inv_slot}b,{replacements[map_type][1:]}')
                    continue

                # Get original item text from source
                item_text = slot_to_text.get(chest_slot)
                if item_text is None:
                    continue

                # Apply text-level transforms
                trim = get_trim(item_id)
                if trim:
                    item_text = inject_trim(item_text, trim)
                if needs_name_strip(item):
                    item_text = strip_stacked_names(item_text)

                inv_items.append(f'{{Slot:{inv_slot}b,{item_text[1:]}')

        inv_text = '[' + ','.join(inv_items) + ']'
        kit_text = f'{{creator:"{creator}",data_version:{data_version},inv:{inv_text},mc_version:"{mc_version}"}}'

        filename = kit_name.replace(" ", "-").replace("/", "-").lower() + ".json"
        out_path = output_dir / filename
        out_path.write_text(kit_text)
        print(f"  {kit_name} -> {out_path}")

    print(f"\nExtracted {outer_container.size()} kits to {output_dir}")


if __name__ == "__main__":
    main()
