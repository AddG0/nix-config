# Places the shared Steam library's declared game files with steam-config-nix's own logic, as their only writer.
# Usage: library-files <library> <ops.json>; an empty list reverts everything placed before.
import json
import logging
import os
import sys
from pathlib import Path

from steam_config_patcher.files import apply_file_ops
from steam_config_patcher.steam import find_app_install_dir
from steam_config_patcher.types import FileOp

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")

library = Path(sys.argv[1])
ops = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))

# The library doubles as the Steam dir: steam-config-nix always searches the Steam dir's own steamapps.
failures = apply_file_ops(
    library,
    [
        FileOp(
            app_id=op["appId"],
            location="game",
            target=op["target"],
            source=Path(op["source"]),
            mode=op["mode"],
            executable=op["executable"],
        )
        for op in ops
    ],
    [],
)

# Placed files come out 0644; seed files are the ones the player's ReShade edits, so the group gets write.
for op in ops:
    if op["mode"] != "seed":
        continue
    root = find_app_install_dir(library, op["appId"])
    placed = root / op["target"] if root else None
    if placed is None or not placed.exists():
        continue
    for path in [placed] if placed.is_file() else [p for p in placed.rglob("*") if p.is_file()]:
        if path.stat().st_uid == os.getuid():
            path.chmod(path.stat().st_mode | 0o020)

for failure in failures:
    print(f"library-files: {failure}", file=sys.stderr)
sys.exit(1 if failures else 0)
