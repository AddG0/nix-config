"""Render a flat logo PNG as a turning, floating 3D extrusion (one PNG per frame).

Depth is LAYERS copies of the face at evenly spaced z, back to front and
darkened with distance, so the stack's silhouette becomes the extruded side wall.
MOTION=rock never reaches edge-on, where a flat plate collapses to a sliver;
MOTION=spin does. Every motion is a whole number of sine periods over FRAMES, so
the loop closes seamlessly.
"""

import glob
import math
import os
import shutil
import subprocess
import sys
import tempfile

SRC, OUT = sys.argv[1], sys.argv[2]
MAGICK = os.environ.get("MAGICK", "magick")


def env(name, default, cast=float):
    return cast(os.environ.get(name, default))


MOTION = os.environ.get("MOTION", "rock")
MAX_ANGLE = math.radians(env("MAX_ANGLE", 42))  # rock only: turn amplitude
NOD = math.radians(env("NOD", 3))  # tilt wobble, keeps the float from looking mechanical
FRAMES = env("FRAMES", 96, int)
CANVAS = env("CANVAS", 480, int)
SRC_PX = env("SRC_PX", 400, int)
LAYERS = env("LAYERS", 22, int)
HALF_T = env("HALF_T", 0.10)  # half thickness, world units
TILT = math.radians(env("TILT", 14))
DIST = env("DIST", 4.6)  # camera distance
FOCAL = env("FOCAL", 4.6)
SCALE = env("SCALE", 118)  # px per world unit at z=0
BOB = env("BOB", 16)  # px of vertical float
# The rim lands on ~1px; darker than this reads as a gap, not depth.
DARK_BACK = env("DARK_BACK", 0.60)


def project(x, y, z, theta, tilt, dy):
    xs = x * math.cos(theta) + z * math.sin(theta)
    zs = -x * math.sin(theta) + z * math.cos(theta)
    yt = y * math.cos(tilt) - zs * math.sin(tilt)
    zt = y * math.sin(tilt) + zs * math.cos(tilt)
    w = DIST - zt
    return (
        CANVAS / 2 + FOCAL * xs / w * SCALE,
        CANVAS / 2 - FOCAL * yt / w * SCALE + dy,
    )


os.makedirs(OUT, exist_ok=True)
tmp = tempfile.mkdtemp()
try:
    # MPC is memory-mappable: decoding the source per layer instead cost ~40s.
    plate = os.path.join(tmp, "plate.mpc")
    subprocess.run(
        [MAGICK, SRC, "-resize", f"{SRC_PX}x{SRC_PX}!", "-alpha", "set", plate],
        check=True,
    )

    s = SRC_PX - 1
    corners = [(0, 0, -1, 1), (s, 0, 1, 1), (s, s, 1, -1), (0, s, -1, -1)]

    for f in range(FRAMES):
        u = 2 * math.pi * f / FRAMES
        if MOTION == "spin":
            # Half-step offset: exactly edge-on is a singular matrix.
            theta = 2 * math.pi * (f + 0.5) / FRAMES
        else:
            theta = MAX_ANGLE * math.sin(u)
        # Offset periods so the three motions never all peak together.
        dy = -BOB * math.cos(u)
        tilt = TILT + NOD * math.sin(2 * u)

        cmd = [MAGICK, "-size", f"{CANVAS}x{CANVAS}", "xc:none"]
        for i in range(LAYERS):
            t = i / (LAYERS - 1)
            z = -HALF_T + 2 * HALF_T * t
            shade = DARK_BACK + (1 - DARK_BACK) * t
            pts = " ".join(
                f"{sx},{sy} {px:.2f},{py:.2f}"
                for sx, sy, wx, wy in corners
                for px, py in [project(wx, wy, z, theta, tilt, dy)]
            )
            cmd += [
                "(", plate,
                "-channel", "RGB", "-evaluate", "multiply", f"{shade:.4f}", "+channel",
                # Near edge-on the horizon enters the viewport, which magick
                # would fill with mattecolor gray.
                "-virtual-pixel", "none", "-mattecolor", "none",
                "-set", "option:distort:viewport", f"{CANVAS}x{CANVAS}+0+0",
                "-distort", "Perspective", pts,
                ")", "-composite",
            ]
        cmd.append(os.path.join(OUT, f"f{f:03d}.png"))
        subprocess.run(cmd, check=True)
finally:
    shutil.rmtree(tmp, ignore_errors=True)

# Uncropped margin makes chafa scale the logo to about half the rows it is given.
# One box shared by every frame, or the logo would resize frame to frame.
paths = sorted(glob.glob(os.path.join(OUT, "f*.png")))
bbox = subprocess.run(
    [MAGICK, *paths, "-background", "none", "-flatten", "-format", "%@", "info:"],
    capture_output=True,
    check=True,
    text=True,
).stdout.strip()
for path in paths:
    subprocess.run([MAGICK, path, "-crop", bbox, "+repage", path], check=True)

print(f"rendered {FRAMES} frames to {OUT}, cropped to {bbox}")
