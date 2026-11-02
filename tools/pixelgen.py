"""Shared pixel-art primitives for the greenhouse art tools.

Palette + drawing helpers used by tools/make_palette.py and tools/make_sprites.py.
Every shape is drawn 1:1 with hard edges - no anti-aliasing anywhere.
"""

import json
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PALETTE_PATH = os.path.join(ROOT, "assets", "palette", "palette.json")

with open(PALETTE_PATH) as fh:
    PALETTE = json.load(fh)

RAMPS = PALETTE["ramps"]


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def ink(i=0):
    return rgb(RAMPS["ink"][i])


BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def bayer(x, y):
    return BAYER[y % 4][x % 4] / 16.0


def pick(x, y, a, b, t):
    """Dither between two colours by fraction t."""
    return a if t > bayer(x, y) else b


def shade(ramp, idx):
    return rgb(RAMPS[ramp][max(0, min(len(RAMPS[ramp]) - 1, idx))])


def canvas(w, h):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def ellipse(d, cx, cy, rx, ry, fill, outline=None):
    d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=fill, outline=outline)


def leaf(d, cx, cy, w, h, ramp="leaf", tilt=0):
    """One foliage leaf: a pointed diamond, lit top-left, dark bottom-right."""
    mid, lit, dark = shade(ramp, 2), shade(ramp, 4), shade(ramp, 0)
    d.polygon([(cx - w, cy), (cx, cy - h), (cx + w, cy), (cx, cy + h)], fill=mid)
    d.point((cx - 1, cy - 1), fill=lit)
    d.point((cx, cy - 1), fill=lit)
    d.point((cx + 1, cy + 1), fill=dark)
    d.point((cx, cy + 1), fill=dark)


def stem(d, x, y0, y1, ramp="leaf", idx=1):
    d.line([(x, y0), (x, y1)], fill=shade(ramp, idx))
    d.point((x + 1, y0), fill=shade(ramp, 0))
