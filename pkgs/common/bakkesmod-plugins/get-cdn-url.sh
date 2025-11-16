#!/usr/bin/env bash
# Helper script to get CDN URL for a BakkesMod plugin

if [ $# -ne 1 ]; then
    echo "Usage: $0 <plugin_id>"
    echo "Example: $0 282"
    exit 1
fi

PLUGIN_ID=$1

echo "Fetching CDN URL for plugin $PLUGIN_ID..."

CDN_URL=$(curl -s "https://bakkesplugins.com/api/plugins/$PLUGIN_ID/versions" | \
    jq -r '.[0].binaryDownloadUrl')

if [ -z "$CDN_URL" ] || [ "$CDN_URL" = "null" ]; then
    echo "Error: Could not fetch CDN URL for plugin $PLUGIN_ID"
    exit 1
fi

echo "CDN URL: $CDN_URL"
echo ""
echo "To get the sha256 hash, run:"
echo "nix-prefetch-url '$CDN_URL'"