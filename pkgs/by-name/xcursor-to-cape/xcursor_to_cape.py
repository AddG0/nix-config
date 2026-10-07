"""Convert an XCursor theme into a Mousecape .cape file for macOS."""

import argparse
import math
import plistlib
import struct
import sys
import zlib
from pathlib import Path

IMAGE_CHUNK = 0xFFFD0002
# CGSRegisterCursorWithImages rejects more frames than this; see mousecloak MCDefs.m.
MAX_FRAMES = 24

# macOS cursor identifier -> XCursor names to try, in order of preference.
CURSOR_MAP = {
    "com.apple.coregraphics.Arrow": ["left_ptr", "default", "arrow"],
    "com.apple.coregraphics.ArrowCtx": ["context-menu", "left_ptr"],
    "com.apple.coregraphics.IBeam": ["xterm", "text", "ibeam"],
    "com.apple.coregraphics.IBeamXOR": ["xterm", "text", "ibeam"],
    "com.apple.coregraphics.Alias": ["alias", "dnd-link", "link"],
    "com.apple.coregraphics.Copy": ["copy", "dnd-copy"],
    "com.apple.coregraphics.Wait": ["wait", "watch"],
    "com.apple.cursor.2": ["alias", "dnd-link", "link"],
    "com.apple.cursor.3": ["not-allowed", "crossed_circle", "no-drop"],
    "com.apple.cursor.4": ["progress", "left_ptr_watch"],
    "com.apple.cursor.5": ["copy", "dnd-copy"],
    "com.apple.cursor.7": ["crosshair", "cross"],
    "com.apple.cursor.8": ["crosshair", "cross"],
    "com.apple.cursor.11": ["grabbing", "closedhand", "dnd-move"],
    "com.apple.cursor.12": ["grab", "openhand", "hand1"],
    "com.apple.cursor.13": ["pointer", "hand2", "pointing_hand"],
    "com.apple.cursor.17": ["w-resize", "left_side"],
    "com.apple.cursor.18": ["e-resize", "right_side"],
    "com.apple.cursor.19": ["col-resize", "ew-resize", "sb_h_double_arrow"],
    "com.apple.cursor.20": ["cell", "plus"],
    "com.apple.cursor.21": ["n-resize", "top_side"],
    "com.apple.cursor.22": ["s-resize", "bottom_side"],
    "com.apple.cursor.23": ["row-resize", "ns-resize", "sb_v_double_arrow"],
    "com.apple.cursor.24": ["context-menu", "left_ptr"],
    "com.apple.cursor.26": ["vertical-text", "xterm"],
    "com.apple.cursor.27": ["e-resize", "right_side"],
    "com.apple.cursor.28": ["ew-resize", "sb_h_double_arrow"],
    "com.apple.cursor.29": ["ne-resize", "top_right_corner"],
    "com.apple.cursor.30": ["nesw-resize", "fd_double_arrow"],
    "com.apple.cursor.31": ["n-resize", "top_side"],
    "com.apple.cursor.32": ["ns-resize", "sb_v_double_arrow"],
    "com.apple.cursor.33": ["nw-resize", "top_left_corner"],
    "com.apple.cursor.34": ["nwse-resize", "bd_double_arrow"],
    "com.apple.cursor.35": ["se-resize", "bottom_right_corner"],
    "com.apple.cursor.36": ["s-resize", "bottom_side"],
    "com.apple.cursor.37": ["sw-resize", "bottom_left_corner"],
    "com.apple.cursor.38": ["w-resize", "left_side"],
    "com.apple.cursor.39": ["all-scroll", "move", "fleur"],
    "com.apple.cursor.40": ["help", "question_arrow"],
    "com.apple.cursor.41": ["cell", "plus"],
    "com.apple.cursor.42": ["zoom-in"],
    "com.apple.cursor.43": ["zoom-out"],
}


class Frame:
    def __init__(self, width, height, xhot, yhot, delay_ms, argb):
        self.width = width
        self.height = height
        self.xhot = xhot
        self.yhot = yhot
        self.delay_ms = delay_ms
        self.argb = argb


def read_xcursor(path):
    """Return {nominal size: [Frame, ...]} for every image in an XCursor file."""
    data = Path(path).read_bytes()
    if data[:4] != b"Xcur":
        raise ValueError(f"{path}: not an XCursor file (magic {data[:4]!r})")
    sizes = {}
    try:
        (ntoc,) = struct.unpack_from("<I", data, 12)
        for i in range(ntoc):
            chunk_type, nominal, pos = struct.unpack_from("<III", data, 16 + i * 12)
            if chunk_type != IMAGE_CHUNK:
                continue
            width, height, xhot, yhot, delay = struct.unpack_from("<5I", data, pos + 16)
            argb = struct.unpack_from(f"<{width * height}I", data, pos + 36)
            sizes.setdefault(nominal, []).append(Frame(width, height, xhot, yhot, delay, argb))
    except struct.error as e:
        raise ValueError(f"{path}: truncated XCursor file ({e})") from e
    return sizes


def encode_png(width, height, rgba_rows):
    def chunk(tag, body):
        return struct.pack(">I", len(body)) + tag + body + struct.pack(">I", zlib.crc32(tag + body))

    raw = b"".join(b"\x00" + row for row in rgba_rows)
    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")


def unpremultiply_row(pixels):
    out = bytearray()
    for p in pixels:
        a = p >> 24
        r, g, b = (p >> 16) & 0xFF, (p >> 8) & 0xFF, p & 0xFF
        if a and a != 255:
            r, g, b = (min(255, c * 255 // a) for c in (r, g, b))
        out += bytes((r, g, b, a))
    return bytes(out)


def frame_strip_png(frames):
    """Stack frames vertically, the layout mousecloak slices animations from."""
    width = frames[0].width
    rows = []
    for f in frames:
        if f.width != width:
            raise ValueError(f"animation frames differ in width: {f.width} != {width}")
        rows += [unpremultiply_row(f.argb[y * f.width:(y + 1) * f.width]) for y in range(f.height)]
    return encode_png(width, len(rows), rows)


def subsample(frames):
    step = math.ceil(len(frames) / MAX_FRAMES)
    kept = frames[::step]
    duration = sum(f.delay_ms for f in frames) / len(kept) / 1000
    return kept, duration


def build_cursor(theme_dir, names, size):
    for name in names:
        path = Path(theme_dir) / name
        if not path.exists():
            continue
        sizes = read_xcursor(path)
        if size not in sizes or size * 2 not in sizes:
            raise ValueError(f"{path}: needs {size}px and {size * 2}px images, has {sorted(sizes)}")
        frames_1x, duration = subsample(sizes[size])
        frames_2x, _ = subsample(sizes[size * 2])
        if len(frames_1x) != len(frames_2x):
            raise ValueError(f"{path}: {size}px has {len(sizes[size])} frames but "
                             f"{size * 2}px has {len(sizes[size * 2])}")
        first = frames_1x[0]
        return {
            "FrameCount": len(frames_1x),
            "FrameDuration": duration if len(frames_1x) > 1 else 1.0,
            "HotSpotX": float(first.xhot),
            "HotSpotY": float(first.yhot),
            "PointsWide": float(first.width),
            "PointsHigh": float(first.height),
            "Representations": [frame_strip_png(frames_1x), frame_strip_png(frames_2x)],
        }
    return None


def build_cape(theme_dir, name, size):
    cursors = {}
    for ident, names in CURSOR_MAP.items():
        cursor = build_cursor(theme_dir, names, size)
        if cursor is not None:
            cursors[ident] = cursor
    if "com.apple.coregraphics.Arrow" not in cursors:
        raise ValueError(f"{theme_dir}: no arrow cursor among {CURSOR_MAP['com.apple.coregraphics.Arrow']}")
    return {
        "Author": "xcursor-to-cape",
        "CapeName": name,
        "CapeVersion": 1.0,
        "Cloud": False,
        "Cursors": cursors,
        "HiDPI": True,
        "Identifier": f"local.xcursor-to-cape.{name}",
        "MinimumVersion": 2.0,
        "Version": 2.0,
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("theme_dir", help="XCursor theme directory, e.g. share/icons/<theme>")
    parser.add_argument("output", help="Path of the .cape file to write")
    parser.add_argument("--size", type=int, default=24, help="Cursor size in points (default 24)")
    args = parser.parse_args(argv)

    theme = Path(args.theme_dir)
    cape = build_cape(theme / "cursors", theme.name, args.size)
    with open(args.output, "wb") as fh:
        plistlib.dump(cape, fh, fmt=plistlib.FMT_XML)
    print(f"wrote {len(cape['Cursors'])} cursors from {theme} to {args.output}", file=sys.stderr)


if __name__ == "__main__":
    main()
