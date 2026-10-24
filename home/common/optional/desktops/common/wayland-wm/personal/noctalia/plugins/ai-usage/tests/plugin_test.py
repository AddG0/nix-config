import tomllib
from pathlib import Path
from sys import argv


plugin = tomllib.loads(Path(argv[1]).read_text())
entries = [entry["id"] for kind in ("service", "widget", "panel") for entry in plugin.get(kind, [])]

assert len(entries) == len(set(entries)), f"duplicate plugin entry IDs: {entries}"
