#!/usr/bin/env python3
"""Generate the greenhouse palette, swatch sheet and a look-dev frame.

    python3 tools/make_palette.py [--out assets/palette]

Deterministic: same output every run. No API calls, no external assets.
Base resolution 480x270, integer-scaled x3 for the preview.
"""
import argparse, json, os, random
from PIL import Image, ImageDraw

BASE_W, BASE_H = 480, 270
FLOOR_Y = 152
HUD_H = 22

RAMPS = {
    "ink":     ["#0b0f1a", "#141a28", "#1e2740"],
    "void":    ["#101a2b", "#16243a", "#1d3050", "#24405f"],
    "glass":   ["#2f5670", "#3d6f83", "#4f8f9a", "#6fb3ad"],
    "soil":    ["#2a1d18", "#3b2a20", "#4e3828", "#63503a"],
    "leaf":    ["#1c4230", "#275c3c", "#357a49", "#4c9a56", "#6fbb64", "#a3d97e"],
    "glow":    ["#1b4a4a", "#2b7a72", "#46b3a0", "#86e0c4"],
    "bloom":   ["#5a1f42", "#8d2f5e", "#c04b7a", "#e87fa3"],
    "metal":   ["#2b3440", "#46515f", "#6b7787", "#9aa5b1"],
    "brass":   ["#4a2f1a", "#6d4321", "#96602f", "#c78d4c"],
    "skin":    ["#3a2630", "#6b4a48", "#a87a63", "#d6a583"],
    "paper":   ["#f2f0e4", "#cfd3c4"],
    "signal":  ["#d0553f", "#e0b04a"],
}

BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

FONT = {
    "A": "010101111101101", "B": "110101110101110", "C": "011100100100011",
    "D": "110101101101110", "E": "111100110100111", "F": "111100110100100",
    "G": "011100101101011", "H": "101101111101101", "I": "111010010010111",
    "J": "001001001101010", "K": "101101110101101", "L": "100100100100111",
    "M": "101111111101101", "N": "101111111111101", "O": "010101101101010",
    "P": "110101110100100", "Q": "010101101111011", "R": "110101110101101",
    "S": "011100010001110", "T": "111010010010010", "U": "101101101101111",
    "V": "101101101101010", "W": "101101111111101", "X": "101101010101101",
    "Y": "101101010010010", "Z": "111001010100111", "/": "001001010100100",
    "0": "111101101101111", "1": "010110010010111", "2": "111001111100111",
    "3": "111001111001111", "4": "101101111001001", "5": "111100111001111",
    "6": "111100111101111", "7": "111001001001001", "8": "111101111101111",
    "9": "111101111001111", " ": "000000000000000",
}


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def bayer(x, y):
    return (BAYER[y % 4][x % 4] + 0.5) / 16.0


def text(d, x, y, s, color, scale=1):
    for ch in s.upper():
        g = FONT.get(ch, FONT[" "])
        for i, bit in enumerate(g):
            if bit == "1":
                gx, gy = i % 3, i // 3
                d.rectangle([x + gx * scale, y + gy * scale,
                             x + gx * scale + scale - 1, y + gy * scale + scale - 1], fill=color)
        x += 4 * scale


def vgrad(img, x0, y0, x1, y1, ramp, a=0.0, b=1.0, dither=True):
    d = ImageDraw.Draw(img)
    n = len(ramp)
    for y in range(y0, y1):
        t = (y - y0) / max(1, y1 - y0 - 1)
        pos = (a + (b - a) * t) * (n - 1)
        i = max(0, min(n - 2, int(pos)))
        frac = pos - i
        for x in range(x0, x1):
            if dither:
                d.point((x, y), rgb(ramp[i]) if frac > bayer(x, y) else rgb(ramp[i + 1]))
            else:
                d.point((x, y), rgb(ramp[i]))


def pool(img, cx, cy, rx, ry, color, strength=0.55):
    """Soft dithered ellipse of light."""
    d = ImageDraw.Draw(img)
    for y in range(cy - ry, cy + ry + 1):
        for x in range(cx - rx, cx + rx + 1):
            nx, ny = (x - cx) / rx, (y - cy) / ry
            dist = nx * nx + ny * ny
            if dist <= 1.0:
                t = (1.0 - dist) * strength
                if t > bayer(x, y):
                    d.point((x, y), color)


def trunk(d, x, y0, y1, c):
    d.line([(x, y0), (x, y1)], fill=c)


def leaf_shape(d, cx, cy, w, h, ramp, lit=4, mid=3, dark=2, outline=0):
    for y in range(-h, h + 1):
        for x in range(-w, w + 1):
            if (x * x) / (w * w) + (y * y) / (h * h) <= 1.0:
                edge = (x * x) / (w * w) + (y * y) / (h * h) > 0.55
                if edge:
                    c = rgb(ramp[outline])
                elif x < 0 and y > 0:
                    c = rgb(ramp[lit])
                elif y > 0:
                    c = rgb(ramp[mid])
                else:
                    c = rgb(ramp[dark])
                d.point((cx + x, cy + y), c)


def bush(d, cx, base_y, size, rng, species="leaf", bloom=None):
    """A potted plant: leaves hung on a visible stem, few and large enough to read."""
    leaf = RAMPS["leaf"]
    h = [7, 13, 21, 29][size - 1]
    top = base_y - h
    trunk(d, cx, base_y, top, rgb(leaf[1]))

    if species == "fern":
        for i in range(4 + size):
            side = -1 if i % 2 else 1
            y = base_y - 3 - i * (h // (4 + size))
            leaf_shape(d, cx + side * (4 + i // 2), y, 3 + size // 3, 2, leaf, lit=4, mid=2, dark=1, outline=0)
    elif species == "vine":
        for i in range(3 + size // 2):
            side = -1 if i % 2 else 1
            leaf_shape(d, cx + side * (5 + i * 2), base_y - 5 - i * (4 + size), 3 + size // 3, 2 + size // 4, leaf)
        leaf_shape(d, cx, top, 4 + size // 2, 3, leaf)
    else:
        nodes = 3 + size
        for i in range(nodes):
            y = base_y - 4 - int(i * (h - 4) / max(1, nodes - 1))
            w = max(3, 7 - i)
            for side in (-1, 1):
                leaf_shape(d, cx + side * (2 + w // 2), y, w, max(2, 5 - i // 2), leaf,
                           lit=4, mid=3, dark=1, outline=0)
        # crown
        leaf_shape(d, cx, top + 2, 4 + size // 2, 3 + size // 3, leaf)
    if bloom and size >= 2:
        for k in range(2 + size // 2):
            bx = cx - 4 + rng.randint(0, 8)
            by = top + 2 + rng.randint(0, 5)
            for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)):
                d.point((bx + dx, by + dy), rgb(RAMPS["bloom"][3] if (k + dx) % 2 else RAMPS["bloom"][2]))


def pot(d, cx, top_y, w=12, h=9):
    soil, brass = RAMPS["soil"], RAMPS["brass"]
    for i in range(h):
        ww = w - int(i * 0.35)
        for x in range(-ww // 2, ww // 2 + 1):
            if i == 0:
                c = rgb(brass[3])
            elif x <= -ww // 2 + 1:
                c = rgb(brass[2])
            elif x >= ww // 2 - 1:
                c = rgb(brass[0])
            else:
                c = rgb(brass[1])
            d.point((cx + x, top_y + i), c)
    for x in range(-w // 2 + 2, w // 2 - 1):
        d.point((cx + x, top_y), rgb(soil[1]))


def person(d, cx, base_y, scale_y=1.0, turn=-1):
    """Side-view figure, 20 x 46-ish, facing `turn`."""
    skin, metal, brass, ink = RAMPS["skin"], RAMPS["metal"], RAMPS["brass"], RAMPS["ink"]
    d.rectangle([cx - 6, base_y - 30, cx + 6, base_y - 12], fill=rgb(metal[1]), outline=rgb(ink[1]))
    d.rectangle([cx - 5, base_y - 29, cx - 1, base_y - 13], fill=rgb(metal[2]))
    # legs
    d.rectangle([cx - 4, base_y - 12, cx - 1, base_y], fill=rgb(metal[0]))
    d.rectangle([cx + 1, base_y - 12, cx + 4, base_y], fill=rgb(ink[2]))
    # arm reaching to the counter
    d.line([(cx + turn * 6, base_y - 26), (cx + turn * 12, base_y - 22)], fill=rgb(brass[2]))
    d.point((cx + turn * 12, base_y - 22), rgb(skin[2]))
    # head + hood
    d.ellipse([cx - 5, base_y - 42, cx + 5, base_y - 31], fill=rgb(skin[2]), outline=rgb(ink[1]))
    d.ellipse([cx - 4, base_y - 44, cx + 4, base_y - 36], fill=rgb(metal[2]), outline=rgb(ink[1]))
    d.point((cx + turn * 2, base_y - 36), rgb(ink[0]))


def window(img, rng):
    d = ImageDraw.Draw(img)
    void, glass, metal, paper = (RAMPS["void"], RAMPS["glass"], RAMPS["metal"], RAMPS["paper"])
    d.rectangle([16, 12, 246, 132], fill=rgb(void[1]), outline=rgb(metal[1]))
    d.rectangle([18, 14, 244, 130], outline=rgb(metal[0]))
    for _ in range(90):
        x, y = rng.randint(20, 242), rng.randint(16, 128)
        d.point((x, y), rng.choice([rgb(paper[1]), rgb(glass[3]), rgb(void[3])]))
    # moon: large, backlit, with a soft halo
    pool(img, 72, 62, 34, 34, rgb(glass[1]), 0.35)
    d.ellipse([44, 34, 100, 90], fill=rgb(paper[1]), outline=rgb(glass[2]))
    for yy in range(40, 86):
        for xx in range(50, 96):
            nx, ny = (xx - 72) / 26.0, (yy - 62) / 26.0
            if nx * nx + ny * ny <= 1.0 and bayer(xx, yy) > 0.55:
                d.point((xx, yy), rgb(paper[1]))
    d.ellipse([56, 46, 76, 66], fill=rgb(glass[3]))
    d.ellipse([62, 52, 70, 60], fill=rgb(glass[2]))
    d.ellipse([80, 64, 88, 72], fill=rgb(glass[3]))
    # struts
    for x in (86, 152, 218):
        d.line([(x, 14), (x, 130)], fill=rgb(metal[2]))
    d.line([(18, 78), (244, 78)], fill=rgb(metal[1]))
    # lander crossing
    d.polygon([(150, 84), (196, 88), (150, 92)], fill=rgb(metal[1]), outline=ink_line())
    d.rectangle([160, 90, 168, 96], fill=rgb(metal[0]))
    d.point((150, 86), rgb(RAMPS["signal"][1]))


def ink_line():
    return rgb(RAMPS["ink"][1])


def shelves(d, rng):
    brass, ink = RAMPS["brass"], RAMPS["ink"]
    for row, sy in enumerate((104, 128)):
        d.rectangle([256, sy, 468, sy + 4], fill=rgb(brass[1]), outline=rgb(brass[0]))
        d.line([(256, sy), (468, sy)], fill=rgb(brass[3]))
        for i, sx in enumerate(range(268, 460, 32)):
            pot(d, sx, sy - 1, 12, 8)
            bush(d, sx, sy - 4, 1 + ((i + row) % 2), rng)


def benches(img, d, rng):
    brass, ink, soil = RAMPS["brass"], RAMPS["ink"], RAMPS["soil"]
    # floor plane: warm boards, receding slightly toward the back wall
    vgrad(img, 0, FLOOR_Y, BASE_W, BASE_H - HUD_H, soil, 0.85, 0.25)
    for i, y in enumerate(range(FLOOR_Y + 4, BASE_H - HUD_H, 7)):
        d.line([(0, y), (BASE_W, y)], fill=rgb(soil[1] if i % 2 else soil[2]))
    # back bench: smaller pots read as further away
    d.rectangle([36, 172, 268, 176], fill=rgb(brass[1]), outline=rgb(brass[0]))
    for lx in (44, 96, 148, 200, 252):
        d.rectangle([lx, 176, lx + 2, 186], fill=rgb(brass[0]))
    d.line([(36, 177), (268, 177)], fill=rgb(ink[1]))
    for sx in (62, 110, 158, 206, 248):
        pot(d, sx, 171, 9, 6)
        bush(d, sx, 168, 2, rng, species="fern" if sx % 3 else "leaf")
    # front bench
    d.rectangle([18, 214, 296, 222], fill=rgb(brass[2]), outline=rgb(brass[0]))
    d.line([(18, 215), (296, 215)], fill=rgb(brass[3]))
    for lx in (26, 90, 154, 218, 282):
        d.rectangle([lx, 222, lx + 3, 240], fill=rgb(brass[1]), outline=rgb(brass[0]))
        d.ellipse([lx - 4, 238, lx + 7, 242], fill=rgb(ink[2]))
    for sx, species in ((50, "leaf"), (108, "fern"), (166, "vine"), (224, "leaf"), (278, "fern")):
        pot(d, sx, 213, 13, 9)
        bush(d, sx, 209, 3, rng, species=species, bloom=(sx == 166))
    # warm light pool where the counter lamp falls on the floor
    pool(img, 392, 238, 78, 22, rgb(RAMPS["signal"][1]), 0.30)
    # grow rail + narrow cones
    d.rectangle([40, 150, 280, 153], fill=rgb(RAMPS["metal"][1]), outline=rgb(ink[1]))
    for lx in (78, 158, 238):
        d.rectangle([lx - 9, 153, lx + 9, 156], fill=rgb(RAMPS["metal"][2]), outline=rgb(ink[1]))
        d.rectangle([lx - 6, 156, lx + 6, 157], fill=rgb(RAMPS["paper"][0]))
        d.rectangle([lx - 3, 157, lx + 3, 158], fill=rgb(RAMPS["signal"][1]))
        for y in range(158, 186):
            t = (y - 158) / 28.0
            spread = int(2 + 6 * t)
            for x in range(lx - spread, lx + spread + 1):
                edge = abs(x - lx) / max(1, spread)
                if edge < 0.3 and y < 168:
                    c = rgb(RAMPS["glow"][2])
                elif edge < 0.6 and bayer(x, y) > 0.5:
                    c = rgb(RAMPS["glow"][1])
                elif bayer(x, y) > 0.78:
                    c = rgb(RAMPS["glow"][1])
                else:
                    continue
                d.point((x, y), c)


def counter(img, d, rng):
    brass, ink, paper = RAMPS["brass"], RAMPS["ink"], RAMPS["paper"]
    d.rectangle([300, 200, 440, 212], fill=rgb(brass[3]), outline=rgb(brass[0]))
    d.rectangle([300, 212, 440, 252], fill=rgb(brass[1]), outline=rgb(brass[0]))
    for x in range(310, 436, 24):
        d.line([(x, 214), (x, 250)], fill=rgb(brass[0]))
    d.line([(300, 201), (440, 201)], fill=rgb(paper[1]))
    # till, a tray of cuttings, and a small lamp with a warm pool
    d.rectangle([314, 186, 342, 200], fill=rgb(RAMPS["metal"][2]), outline=rgb(ink[1]))
    d.rectangle([318, 190, 338, 194], fill=rgb(RAMPS["glow"][3]))
    d.rectangle([350, 190, 384, 200], fill=rgb(RAMPS["soil"][2]), outline=rgb(ink[1]))
    for i in range(3):
        bush(d, 356 + i * 10, 192, 1, rng)
    d.rectangle([404, 178, 408, 200], fill=rgb(RAMPS["metal"][1]))
    d.rectangle([398, 174, 414, 179], fill=rgb(RAMPS["signal"][1]), outline=rgb(RAMPS["brass"][0]))
    pool(img, 406, 200, 30, 8, rgb(RAMPS["signal"][1]), 0.22)
    # shopkeeper behind the counter, customer in front of it
    person(d, 336, 200, turn=1)
    person(d, 462, 258, turn=-1)


def hud(img, d):
    ink, metal, paper = RAMPS["ink"], RAMPS["metal"], RAMPS["paper"]
    d.rectangle([0, BASE_H - HUD_H, BASE_W, BASE_H], fill=rgb(ink[1]))
    d.line([(0, BASE_H - HUD_H), (BASE_W, BASE_H - HUD_H)], fill=rgb(RAMPS["glow"][1]))
    text(d, 8, BASE_H - 14, "DAY 3", rgb(paper[0]))
    text(d, 60, BASE_H - 14, "CASH 412", rgb(RAMPS["signal"][1]))
    text(d, 148, BASE_H - 14, "RATING 12", rgb(RAMPS["glow"][3]))
    text(d, 236, BASE_H - 14, "VISITORS 4/6", rgb(paper[1]))
    d.rectangle([380, BASE_H - 17, 470, BASE_H - 5], outline=rgb(metal[1]))
    text(d, 386, BASE_H - 14, "SELL  BUY", rgb(metal[3]))


def frame(img, rng):
    d = ImageDraw.Draw(img)
    void = RAMPS["void"]
    vgrad(img, 0, 0, BASE_W, FLOOR_Y, void, 0.0, 1.0)
    # wall struts for depth
    for x in range(0, BASE_W, 48):
        d.line([(x, 0), (x, FLOOR_Y)], fill=rgb(void[1]))
    window(img, rng)
    shelves(d, rng)
    benches(img, d, rng)
    counter(img, d, rng)
    hud(img, d)


def swatches(out_dir):
    cell, pad, line = 46, 8, 22
    rows = list(RAMPS.items())
    w = pad + max(len(c) for _, c in rows) * (cell + pad)
    h = pad + len(rows) * (line + cell + 14 + pad)
    img = Image.new("RGB", (w, h), rgb(RAMPS["ink"][0]))
    d = ImageDraw.Draw(img)
    for r, (name, cols) in enumerate(rows):
        y = pad + r * (line + cell + 14 + pad)
        d.text((pad, y), name.upper(), fill=rgb(RAMPS["paper"][0]))
        text(d, pad + len(name) * 7 + 8, y + 1, str(len(cols)), rgb(RAMPS["glow"][2]))
        for c, hexv in enumerate(cols):
            x = pad + c * (cell + pad)
            d.rectangle([x, y + line, x + cell, y + line + cell], fill=rgb(hexv),
                        outline=rgb(RAMPS["ink"][2]))
            d.text((x, y + line + cell + 2), hexv.upper().lstrip("#"),
                   fill=rgb(RAMPS["paper"][1]))
    img.save(os.path.join(out_dir, "palette.png"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="assets/palette")
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)

    with open(os.path.join(args.out, "palette.json"), "w") as fh:
        json.dump({"name": "Greenhouse Dusk", "base_resolution": [BASE_W, BASE_H],
                   "ramps": RAMPS,
                   "roles": {"outline": "ink.1", "ink": "paper.1", "grow_light": "glow.2",
                             "accent": "signal.1", "alarm": "signal.0",
                             "sky": "void.2", "moon": "paper.1"}}, fh, indent=2)

    rng = random.Random(7)
    img = Image.new("RGB", (BASE_W, BASE_H), rgb(RAMPS["ink"][0]))
    frame(img, rng)
    img.save(os.path.join(args.out, "look_dev_1x.png"))
    img.resize((BASE_W * 3, BASE_H * 3), Image.NEAREST).save(os.path.join(args.out, "look_dev.png"))
    swatches(args.out)
    print("wrote", args.out, "-> look_dev.png (1440x810), palette.png, palette.json")


if __name__ == "__main__":
    main()
