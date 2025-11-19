#!/usr/bin/env bash

set -e

PLASMOID_DIR="$HOME/.local/share/plasma/plasmoids/com.github.timezonehover"

echo "Deleting timezone-hover plasmoid..."
if [ -d "$PLASMOID_DIR" ]; then
  rm -rf "$PLASMOID_DIR"
  echo "Timezone-hover plasmoid deleted."
else
  echo "Timezone-hover plasmoid not found."
fi

echo "Done."
