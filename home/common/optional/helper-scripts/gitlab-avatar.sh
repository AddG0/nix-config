#!/usr/bin/env bash
# Optimize an image for GitLab group/project avatars: 192x192 pixels, max 200 KiB

set -euo pipefail

MAX_SIZE_KB=200
TARGET_SIZE=192

usage() {
    echo "Usage: gitlab-avatar <input-image> [output-image]"
    echo ""
    echo "Optimizes an image for GitLab group/project avatars."
    echo "Target: ${TARGET_SIZE}x${TARGET_SIZE} pixels, max ${MAX_SIZE_KB} KiB file size."
    echo "If no output is specified, creates <input>_gitlab.<ext> in the same directory."
    exit 1
}

if [[ $# -lt 1 ]]; then
    usage
fi

INPUT="$1"

if [[ ! -f "$INPUT" ]]; then
    echo "Error: Input file '$INPUT' does not exist."
    exit 1
fi

# Determine output filename
if [[ $# -ge 2 ]]; then
    OUTPUT="$2"
else
    DIR=$(dirname "$INPUT")
    BASENAME=$(basename "$INPUT")
    NAME="${BASENAME%.*}"
    EXT="${BASENAME##*.}"
    OUTPUT="${DIR}/${NAME}_gitlab.${EXT}"
fi

# Get input file info
echo "Input: $INPUT"
echo "Output: $OUTPUT"
echo "Target: ${TARGET_SIZE}x${TARGET_SIZE} pixels, max ${MAX_SIZE_KB} KiB"
echo ""

# Detect if input is PNG or other format
EXT_LOWER=$(echo "${INPUT##*.}" | tr '[:upper:]' '[:lower:]')

# Create a temporary file for testing
TEMP_FILE=$(mktemp --suffix=".${EXT_LOWER}")
trap 'rm -f "$TEMP_FILE"' EXIT

# First, resize the image to target dimensions
magick "$INPUT" -resize "${TARGET_SIZE}x${TARGET_SIZE}^" -gravity center -extent "${TARGET_SIZE}x${TARGET_SIZE}" "$TEMP_FILE"

# Check initial size
INITIAL_SIZE=$(stat -f%z "$TEMP_FILE" 2>/dev/null || stat -c%s "$TEMP_FILE")
INITIAL_SIZE_KB=$((INITIAL_SIZE / 1024))
echo "Size after resize: ${INITIAL_SIZE_KB} KiB"

if [[ $INITIAL_SIZE_KB -le $MAX_SIZE_KB ]]; then
    cp "$TEMP_FILE" "$OUTPUT"
    echo "Image already under ${MAX_SIZE_KB} KiB. Done!"
    exit 0
fi

# For PNG files, try different compression levels
if [[ "$EXT_LOWER" == "png" ]]; then
    echo "Optimizing PNG..."

    # Try with maximum compression
    magick "$INPUT" -resize "${TARGET_SIZE}x${TARGET_SIZE}^" -gravity center -extent "${TARGET_SIZE}x${TARGET_SIZE}" \
        -strip -define png:compression-level=9 -define png:compression-filter=5 "$TEMP_FILE"

    SIZE=$(stat -f%z "$TEMP_FILE" 2>/dev/null || stat -c%s "$TEMP_FILE")
    SIZE_KB=$((SIZE / 1024))
    echo "Size with max compression: ${SIZE_KB} KiB"

    if [[ $SIZE_KB -le $MAX_SIZE_KB ]]; then
        cp "$TEMP_FILE" "$OUTPUT"
        echo "Done! Final size: ${SIZE_KB} KiB"
        exit 0
    fi

    # If still too large, reduce colors
    for COLORS in 256 128 64 32; do
        magick "$INPUT" -resize "${TARGET_SIZE}x${TARGET_SIZE}^" -gravity center -extent "${TARGET_SIZE}x${TARGET_SIZE}" \
            -strip -colors "$COLORS" -define png:compression-level=9 "$TEMP_FILE"

        SIZE=$(stat -f%z "$TEMP_FILE" 2>/dev/null || stat -c%s "$TEMP_FILE")
        SIZE_KB=$((SIZE / 1024))
        echo "Size with $COLORS colors: ${SIZE_KB} KiB"

        if [[ $SIZE_KB -le $MAX_SIZE_KB ]]; then
            cp "$TEMP_FILE" "$OUTPUT"
            echo "Done! Final size: ${SIZE_KB} KiB (reduced to $COLORS colors)"
            exit 0
        fi
    done
fi

# For JPEG or as fallback, use quality reduction
echo "Optimizing with quality reduction..."
TEMP_JPG=$(mktemp --suffix=".jpg")
trap 'rm -f "$TEMP_FILE" "$TEMP_JPG"' EXIT

# Binary search for optimal quality
LOW=1
HIGH=100
BEST_QUALITY=0
BEST_SIZE=0

while [[ $LOW -le $HIGH ]]; do
    MID=$(( (LOW + HIGH) / 2 ))

    magick "$INPUT" -resize "${TARGET_SIZE}x${TARGET_SIZE}^" -gravity center -extent "${TARGET_SIZE}x${TARGET_SIZE}" \
        -strip -quality "$MID" "$TEMP_JPG"

    SIZE=$(stat -f%z "$TEMP_JPG" 2>/dev/null || stat -c%s "$TEMP_JPG")
    SIZE_KB=$((SIZE / 1024))

    if [[ $SIZE_KB -le $MAX_SIZE_KB ]]; then
        BEST_QUALITY=$MID
        BEST_SIZE=$SIZE_KB
        LOW=$((MID + 1))
    else
        HIGH=$((MID - 1))
    fi
done

if [[ $BEST_QUALITY -gt 0 ]]; then
    # Re-create with best quality found
    magick "$INPUT" -resize "${TARGET_SIZE}x${TARGET_SIZE}^" -gravity center -extent "${TARGET_SIZE}x${TARGET_SIZE}" \
        -strip -quality "$BEST_QUALITY" "$TEMP_JPG"

    # If output should be PNG but we had to use JPEG compression
    if [[ "$EXT_LOWER" == "png" ]]; then
        echo "Warning: PNG too large even with color reduction. Saving as optimized PNG from JPEG compression."
        magick "$TEMP_JPG" "$OUTPUT"
    else
        cp "$TEMP_JPG" "$OUTPUT"
    fi

    FINAL_SIZE=$(stat -f%z "$OUTPUT" 2>/dev/null || stat -c%s "$OUTPUT")
    FINAL_SIZE_KB=$((FINAL_SIZE / 1024))
    echo "Done! Final size: ${FINAL_SIZE_KB} KiB (quality: $BEST_QUALITY)"
else
    echo "Error: Could not reduce image to under ${MAX_SIZE_KB} KiB"
    exit 1
fi
