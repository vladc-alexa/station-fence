"""First-person views: shop floor + greenhouse aisle.

    python3 tools/make_views.py [--out assets/sprites]

Pots and props stay separate sprites so the scene can place them at runtime.
"""

import argparse
import os

from PIL import Image
from pixelgen import canvas, ellipse, ink, leaf, rgb, shade

W, H = 480, 270

def pot_big(w=44, h=34):
    """Large soil-filled planter seen from standing height."""
    img, d = canvas(w, h)
    d.polygon([(6, 6), (38, 6), (34, 33), (10, 33)], fill=shade("brass", 1), outline=ink(0))
    for x in range(9, 36, 5):
        d.line([(x, 9), (x + 1, 31)], fill=shade("brass", 2))
    d.rectangle([3, 3, 41, 8], fill=shade("brass", 3), outline=ink(0))
    ellipse(d, 22, 6, 17, 4, shade("soil", 2))
    ellipse(d, 18, 5, 9, 2, shade("soil", 3))
    for i in range(6):
        d.point((10 + (i * 5) % 26, 4 + (i * 3) % 4), fill=shade("soil", 1))
    return img


def counter_view():
    """Looking across the sales counter at the shop door; greenhouse to the right."""
    img, d = canvas(W, H)
    for y in range(0, 190):
        t = y / 190.0
        c = shade("void", 0) if t < 0.35 else shade("void", 1) if t < 0.7 else shade("void", 2)
        d.line([(0, y), (W, y)], fill=c)
    # window with the moon and a passing hauler
    d.rectangle([16, 20, 196, 116], fill=shade("void", 0), outline=ink(0))
    d.rectangle([20, 24, 192, 112], fill=shade("void", 1), outline=shade("glass", 0))
    for i in range(46):
        x = 26 + (i * 41) % 160
        y = 28 + (i * 29) % 78
        d.point((x, y), fill=shade("paper", 1))
    ellipse(d, 62, 52, 16, 16, shade("paper", 0))
    ellipse(d, 57, 47, 5, 5, shade("glass", 2))
    d.line([(120, 62), (150, 58)], fill=shade("metal", 2))
    d.polygon([(140, 54), (152, 57), (140, 62)], fill=shade("metal", 1))
    d.line([(16, 68), (196, 68)], fill=shade("brass", 0))
    # open doorway into the greenhouse: bright interior, dark frame
    d.rectangle([294, 30, 438, 190], fill=shade("ink", 0), outline=ink(0))
    d.rectangle([300, 36, 432, 190], fill=shade("glow", 0))
    d.rectangle([300, 36, 432, 96], fill=shade("void", 1))
    for i in range(5):
        d.line([(300 + i * 26, 36), (300 + i * 26, 96)], fill=shade("metal", 0))
    d.rectangle([300, 96, 432, 150], fill=shade("glass", 1))
    for i in range(6):
        d.line([(300 + i * 22, 96), (300 + i * 22, 150)], fill=shade("metal", 0))
    d.rectangle([300, 150, 432, 190], fill=shade("soil", 1))
    for i in range(7):
        d.line([(304 + i * 18, 150), (300 + i * 18, 190)], fill=shade("soil", 0))
    for x, y in [(316, 168), (352, 160), (390, 172)]:
        leaf(d, x, y, 5, 4, "leaf")
        leaf(d, x + 7, y - 3, 4, 3, "leaf")
    # light spilling from the doorway onto the wall
    for i in range(10):
        d.line([(294 - i, 60 + i * 13), (294, 60 + i * 13 + 13)], fill=shade("brass", 2))
    # sales counter: top plane then front face
    d.rectangle([0, 182, W, 206], fill=shade("brass", 3), outline=ink(0))
    for x in range(0, W, 30):
        d.line([(x, 183), (x + 6, 205)], fill=shade("brass", 2))
    d.rectangle([0, 206, W, H], fill=shade("brass", 1), outline=ink(0))
    for x in range(0, W, 28):
        d.line([(x, 208), (x, H)], fill=shade("brass", 0))
    d.line([(0, 206), (W, 206)], fill=shade("brass", 3))
    d.line([(0, 218), (W, 218)], fill=shade("brass", 0))
    return img


def greenhouse_view():
    """Inside the greenhouse: glass roof, soil beds, room for two rows of planters."""
    img, d = canvas(W, H)
    # glass roof with sky above
    d.rectangle([0, 0, W, 150], fill=shade("void", 1))
    for i in range(0, W, 60):
        d.line([(i, 0), (i + 40, 60)], fill=shade("metal", 1))
        d.line([(i + 40, 60), (i + 40, 150)], fill=shade("metal", 1))
    d.line([(0, 60), (W, 60)], fill=shade("metal", 0))
    d.line([(0, 58), (W, 58)], fill=shade("glass", 1))
    for i in range(70):
        x = (i * 37) % W
        y = (i * 23) % 56
        d.point((x, y), fill=shade("paper", 1))
    ellipse(d, 392, 26, 12, 12, shade("paper", 0))
    # glass back wall, moonlit
    d.rectangle([0, 90, W, 150], fill=shade("glass", 0))
    for x in range(10, W, 54):
        d.line([(x, 90), (x, 150)], fill=shade("metal", 0))
    # raised bed under the glass, then the soil floor
    d.rectangle([0, 126, W, 152], fill=shade("brass", 1))
    d.rectangle([0, 122, W, 128], fill=shade("soil", 2))
    d.line([(0, 122), (W, 122)], fill=shade("soil", 3))
    for x in range(6, W, 22):
        d.line([(x, 128), (x + 2, 152)], fill=shade("brass", 0))
    d.rectangle([0, 152, W, H], fill=shade("soil", 0))
    for y in range(154, H, 7):
        d.line([(0, y), (W, y)], fill=shade("soil", 1))
    for i in range(120):
        x = (i * 53) % W
        y = 156 + (i * 37) % 110
        d.point((x, y), fill=shade("soil", 2) if i % 4 else shade("soil", 0))
    return img


def bell():
    img, d = canvas(16, 14)
    d.polygon([(4, 11), (12, 11), (10, 5), (6, 5)], fill=shade("brass", 3), outline=ink(0))
    d.line([(6, 5), (8, 1)], fill=ink(0))
    d.line([(10, 5), (8, 1)], fill=ink(0))
    d.rectangle([3, 11, 13, 13], fill=shade("brass", 1), outline=ink(0))
    return img


def till():
    img, d = canvas(44, 26)
    d.rectangle([0, 4, 43, 25], fill=shade("metal", 1), outline=ink(0))
    d.rectangle([3, 7, 40, 15], fill=shade("ink", 2), outline=ink(0))
    for x in range(5, 38, 5):
        d.line([(x, 8), (x, 14)], fill=shade("glow", 2))
    for i in range(4):
        d.rectangle([4 + i * 10, 18, 11 + i * 10, 23], fill=shade("metal", 2), outline=ink(0))
    d.rectangle([0, 4, 43, 6], fill=shade("metal", 3))
    return img


def ledger():
    img, d = canvas(26, 18)
    d.polygon([(1, 4), (24, 1), (25, 15), (2, 18)], fill=shade("paper", 1), outline=ink(0))
    for i in range(4):
        d.line([(6, 6 + i * 3), (21, 4 + i * 3)], fill=shade("ink", 2))
    return img


def can():
    img, d = canvas(30, 22)
    d.rectangle([4, 8, 22, 21], fill=shade("glow", 1), outline=ink(0))
    d.rectangle([4, 10, 22, 13], fill=shade("glow", 2))
    d.line([(22, 9), (29, 3)], fill=shade("glow", 2))
    d.line([(23, 10), (29, 5)], fill=ink(0))
    d.line([(6, 8), (12, 2)], fill=ink(0))
    d.line([(14, 8), (18, 2)], fill=ink(0))
    return img


def lamp_big():
    """Hanging grow lamp: shade, hot bulb, and a soft cone of light."""
    img, d = canvas(28, 46)
    d.line([(14, 0), (14, 8)], fill=shade("metal", 1))
    d.polygon([(4, 22), (24, 22), (19, 8), (9, 8)], fill=shade("metal", 2), outline=ink(0))
    d.rectangle([8, 22, 20, 25], fill=shade("signal", 1), outline=ink(0))
    d.rectangle([10, 25, 18, 27], fill=shade("paper", 0))
    for i in range(16):
        w = 3 + i
        y = 28 + i
        for x in range(14 - w, 14 + w, 2):
            if (x + y) % 4 == 0:
                d.point((x, y), fill=shade("glow", 1))
    return img


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="assets/sprites")
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    items = {
        "bg_counter": counter_view(),
        "bg_greenhouse": greenhouse_view(),
        "pot_big": pot_big(),
        "bell": bell(),
        "till": till(),
        "ledger": ledger(),
        "can": can(),
        "lamp_big": lamp_big(),
    }
    for name, img in items.items():
        img.save(os.path.join(args.out, name + ".png"))
    print("views ->", args.out, "(%d sprites)" % len(items))


if __name__ == "__main__":
    main()


