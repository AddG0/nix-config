#!/usr/bin/env bash

# Script to quickly test the plasmoid by copying it to the local plasma directory
# Usage: ./test-install.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLASMOID_DIR="$HOME/.local/share/plasma/plasmoids/com.github.timezonehover"

echo "� Installing timezone-hover plasmoid for testing..."

# Remove old installation if exists
if [ -d "$PLASMOID_DIR" ]; then
  echo "�  Removing old installation..."
  rm -rf "$PLASMOID_DIR"
fi

# Copy plasmoid files
echo "📦 Copying plasmoid files..."
mkdir -p "$PLASMOID_DIR"
cp -r "$SCRIPT_DIR/plasmoid/"* "$PLASMOID_DIR/"

echo "✅ Installation complete! Restart plasma to see the changes."
