#!/usr/bin/env python3
"""Bake the 3x5 HUD font into a bitmap font Godot can load (.fnt + png).

    python3 tools/make_font.py [--out assets/fonts]
"""

import argparse
import os

from PIL import Image

from pixelgen import ink, rgb

GLYPHS = {
    "A": "010101111101101", "B": "110101110101110", "C": "011100100100011",
    "D": "110101101101110", "E": "111100110100111", "F": "111100110100100",
    "G": "011100101101011", "H": "101101111101101", "I": "111010010010111",
    "J": "001001001101010", "K": "101101110101101", "L": "100100100100111",
    "M": "101111111101101", "N": "101111111111101", "O": "010101101101010",
    "P": "110101110100100", "Q": "010101101111011", "R": "110101110101101",
    "S": "011100010001110", "T": "111010010010010", "U": "101101101101111",
    "V": "101101101101010", "W": "101101111111101", "X": "101101010101101",
    "Y": "101101010010010", "Z": "111001010100111",
    "0": "111101101101111", "1": "010110010010111", "2": "111001111100111",
    "3": "111001111001111", "4": "101101111001001", "5": "111100111001111",
    "6": "111100111101111", "7": "111001001001001", "8": "111101111101111",
    "9": "111101111001111",
    "/": "001001010100100", ":": "000010000010000", ".": "000000000000010",
    "-": "000000111000000", " ": "000000000000000",
}

W, H, TRACK = 3, 5, 1


def build(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    chars = list(GLYPHS.items())
    cols = 16
    cw, cell_h = W + TRACK, H + 2
    rows = (len(chars) + cols - 1) // cols
    img = Image.new("RGBA", (cols * cw, rows * cell_h), (255, 255, 255, 0))
    px = img.load()
    fg = (255, 255, 255, 255)

    lines = []
    for i, (glyph, bits) in enumerate(chars):
        cx = (i % cols) * cw
        cy = (i // cols) * cell_h
        for r in range(H):
            for c in range(W):
                if bits[r * W + c] == "1":
                    px[cx + c, cy + r] = fg
        lines.append('char id=%d x=%d y=%d width=%d height=%d xoffset=0 yoffset=0 '
                     'xadvance=%d page=0 chnl=15'
                     % (ord(glyph), cx, cy, W, H, W + TRACK))

    img.save(os.path.join(out_dir, "hud.png"))
    header = [
        'info face="hud" size=%d bold=0 italic=0 charset="" unicode=0 stretchH=100 '
        'smooth=0 aa=1 padding=0,0,0,0 spacing=0,0' % H,
        'common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0'
        % (cell_h, H, img.width, img.height),
        'page id=0 file="hud.png"',
        'chars count=%d' % len(chars),
    ]
    with open(os.path.join(out_dir, "hud.fnt"), "w") as fh:
        fh.write("\n".join(header + lines) + "\n")
    print("font ->", out_dir, img.size)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="assets/fonts")
    args = ap.parse_args()
    build(args.out)
