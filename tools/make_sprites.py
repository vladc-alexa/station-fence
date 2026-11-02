#!/usr/bin/env python3
"""Generate in-game sprites from the palette. 1x pixels, ready for nearest-neighbour x4.

    python3 tools/make_sprites.py [--out assets]

Outputs assets/sprites/*.png (transparent) and assets/fonts/hud.png + hud.fnt.
"""

import argparse
import os

from PIL import Image, ImageDraw

from pixelgen import RAMPS, canvas, ellipse, ink, leaf, rgb, shade, stem

SPECIES = ["lumen_moss", "vine_bean", "ember_pepper", "dew_fern", "crystal_orchid", "brine_kelp"]


def plant(species, stage):
    """stage 0..3 -> 32x40 sprite, stem base at the bottom centre."""
    img, d = canvas(32, 40)
    base = 39
    g = stage                      # 0..3
    h = 7 + g * 8                  # total height
    top = base - h

    def tier(y, spread, size=3, count=2):
        for i in range(count):
            off = spread if i % 2 == 0 else -spread
            leaf(d, 16 + off, y, size, size - 1)
        leaf(d, 16, y - 1, size + 1, size)

    if species == "lumen_moss":
        for i in range(4 + g * 3):
            x = 16 + ((i * 7) % 19) - 9
            y = base - 2 - ((i * 5) % (5 + g * 5))
            leaf(d, x, y, 2, 2, "glow")
        if g >= 2:
            for x, y in [(10, base - 14), (22, base - 19), (16, base - 24)]:
                d.point((x, y), fill=shade("glow", 3))
                d.point((x + 1, y), fill=shade("glow", 2))

    elif species == "vine_bean":
        stem(d, 16, base, top)
        for i in range(2 + g):
            y = top + 6 + i * 7
            tier(y, 5 + (i % 2), 3, 2)
        if g >= 3:
            for y in (top + 10, top + 20):
                ellipse(d, 20, y, 2, 4, shade("leaf", 4), ink(0))

    elif species == "ember_pepper":
        stem(d, 16, base, top)
        for i in range(2 + g * 2):
            y = top + 3 + (i * 6) % max(6, h)
            tier(y, 4 + (i % 3), 3, 2)
        if g >= 3:
            for x, y in [(11, base - 12), (23, base - 18)]:
                ellipse(d, x, y, 2, 3, shade("signal", 0), ink(0))
                d.point((x - 1, y - 1), fill=shade("signal", 1))

    elif species == "dew_fern":
        for i in range(3 + g * 2):
            side = -1 if i % 2 else 1
            x1 = 16 + side * (5 + g * 2)
            y1 = top + (i % 4) * 3
            d.line([(16, base), (x1, y1)], fill=shade("leaf", 1))
            for t in range(4):
                xx = 16 + int((x1 - 16) * (t + 1) / 5)
                yy = base + int((y1 - base) * (t + 1) / 5)
                leaf(d, xx, yy, 2, 1)

    elif species == "crystal_orchid":
        stem(d, 16, base, top)
        leaf(d, 12, base - 3, 5, 2)
        leaf(d, 20, base - 6, 5, 2)
        for i in range(1 + g):
            y = top + 2 + i * 7
            cx = 16 + (2 if i % 2 else -2)
            ellipse(d, cx, y, 3, 2, shade("bloom", 2), ink(0))
            d.point((cx - 1, y - 1), fill=shade("bloom", 3))

    else:  # brine_kelp
        for i in range(2 + g):
            x = 16 + (i - g) * 3
            pts = [(x + (1 if j % 2 else 0), base - j * 5) for j in range(1, 3 + g)]
            for j in range(len(pts) - 1):
                d.line([pts[j], pts[j + 1]], fill=shade("glass", 2))
            d.point(pts[-1], fill=shade("glow", 2))
            d.point((pts[-1][0] + 1, pts[-1][1] + 1), fill=shade("glow", 1))

    return img


def pot():
    img, d = canvas(16, 12)
    d.polygon([(2, 0), (14, 0), (12, 11), (4, 11)], fill=shade("brass", 1), outline=ink(0))
    d.line([(2, 1), (14, 1)], fill=shade("brass", 3))
    d.line([(3, 2), (13, 2)], fill=shade("brass", 2))
    d.line([(4, 11), (12, 11)], fill=shade("brass", 0))
    return img


def bench(w=140):
    img, d = canvas(w, 26)
    d.rectangle([0, 0, w - 1, 5], fill=shade("brass", 2), outline=ink(0))
    d.line([(1, 1), (w - 2, 1)], fill=shade("brass", 3))
    d.line([(1, 2), (w - 2, 2)], fill=shade("brass", 1))
    for x in (10, w // 2, w - 16):
        d.rectangle([x, 6, x + 2, 25], fill=shade("brass", 0))
        d.point((x + 2, 25), fill=ink(0))
    d.line([(0, 25), (w - 1, 25)], fill=ink(0))
    return img


def counter(w=176):
    img, d = canvas(w, 58)
    d.rectangle([0, 0, w - 1, 6], fill=shade("brass", 3), outline=ink(0))
    d.rectangle([0, 7, w - 1, 57], fill=shade("brass", 1), outline=ink(0))
    for x in range(6, w - 6, 24):
        d.line([(x, 10), (x, 55)], fill=shade("brass", 0))
        d.line([(x + 1, 10), (x + 1, 55)], fill=shade("brass", 2))
    d.rectangle([0, 44, w - 1, 47], fill=shade("brass", 0))
    return img


def person(coat="metal", hat=True, scale=1.0):
    img, d = canvas(24, 40)
    base = 39
    hh = int(9 * scale)
    torso_top = base - int(20 * scale)
    d.rectangle([9, base - 4, 10, base], fill=shade("metal", 0))
    d.rectangle([14, base - 4, 15, base], fill=shade("metal", 0))
    d.polygon([(6, base - 4), (18, base - 4), (17, torso_top), (7, torso_top)],
              fill=shade(coat, 1), outline=ink(0))
    d.line([(8, torso_top + 1), (16, torso_top + 1)], fill=shade(coat, 2))
    d.ellipse([7, torso_top - hh, 17, torso_top + 1], fill=shade("skin", 2), outline=ink(0))
    d.point((10, torso_top - hh + 3), fill=ink(0))
    d.point((14, torso_top - hh + 3), fill=ink(0))
    if hat:
        d.rectangle([6, torso_top - hh - 2, 18, torso_top - hh], fill=shade(coat, 2), outline=ink(0))
        d.rectangle([9, torso_top - hh - 5, 15, torso_top - hh - 2], fill=shade(coat, 1), outline=ink(0))
    d.rectangle([17, torso_top + 2, 18, torso_top + 12], fill=shade(coat, 0))
    return img


def lamp():
    img, d = canvas(18, 34)
    d.rectangle([7, 0, 9, 8], fill=shade("metal", 1))
    d.polygon([(2, 9), (16, 9), (10, 15), (8, 15)], fill=shade("metal", 2), outline=ink(0))
    d.rectangle([8, 15, 9, 17], fill=shade("signal", 1))
    for y in range(17, 31, 3):
        d.point((9, y), fill=shade("glow", 2))
    ellipse(d, 9, 32, 3, 1, shade("glow", 1))
    return img


def backdrop(w=480, h=150):
    img, d = canvas(w, h)
    for y in range(h):
        t = y / h
        c = shade("void", 0) if t < 0.45 else shade("void", 1) if t < 0.8 else shade("void", 2)
        d.line([(0, y), (w, y)], fill=c)
    # window
    d.rectangle([16, 14, 258, 122], fill=shade("void", 0), outline=ink(0))
    d.rectangle([20, 18, 254, 118], fill=shade("void", 1), outline=shade("glass", 0))
    for i in range(70):
        x = 24 + (i * 37) % 226
        y = 22 + (i * 53) % 92
        d.point((x, y), fill=shade("paper", 1))
    ellipse(d, 74, 52, 20, 20, shade("paper", 0))
    ellipse(d, 69, 47, 6, 6, shade("glass", 2))
    ellipse(d, 82, 58, 4, 4, shade("glass", 1))
    d.line([(139, 74), (170, 70)], fill=shade("metal", 2))
    d.polygon([(160, 66), (172, 69), (160, 74)], fill=shade("metal", 1))
    for x in (100, 178):
        d.line([(x, 14), (x, 122)], fill=shade("brass", 0))
    d.line([(16, 68), (258, 68)], fill=shade("brass", 0))
    return img


def floor(w=480, h=120):
    img, d = canvas(w, h)
    d.rectangle([0, 0, w, h], fill=shade("soil", 0))
    for y in range(4, h, 10):
        d.line([(0, y), (w, y)], fill=shade("soil", 1))
        d.line([(0, y + 1), (w, y + 1)], fill=shade("ink", 0))
    for x in range(0, w, 48):
        d.line([(x, 4), (x + 10, h)], fill=shade("ink", 0))
    # baseboard where the wall meets the floor
    d.rectangle([0, 0, w, 3], fill=shade("brass", 0))
    d.line([(0, 4), (w, 4)], fill=shade("ink", 0))
    return img


def shadow():
    """Soft contact shadow blob, alpha only."""
    img = Image.new("RGBA", (28, 8), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    ellipse(d, 14, 4, 13, 3, (0, 0, 0, 110))
    return img


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="assets")
    args = ap.parse_args()
    sprites = os.path.join(args.out, "sprites")
    os.makedirs(sprites, exist_ok=True)

    def save(img, name):
        img.save(os.path.join(sprites, name))

    for sp in SPECIES:
        for st in range(4):
            save(plant(sp, st), "plant_%s_%d.png" % (sp, st))
    save(pot(), "pot.png")
    save(bench(), "bench.png")
    save(counter(), "counter.png")
    save(lamp(), "lamp.png")
    save(backdrop(), "backdrop.png")
    save(floor(), "floor.png")
    save(shadow(), "shadow.png")
    save(person("metal"), "vendor.png")
    for i, coat in enumerate(["glass", "brass", "bloom", "glow"]):
        save(person(coat, hat=(i % 2 == 0)), "customer_%d.png" % i)

    print("sprites ->", sprites)


if __name__ == "__main__":
    main()
