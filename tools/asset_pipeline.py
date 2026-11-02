#!/usr/bin/env python3
"""Pixel-art asset pipeline: raw AI output -> game-ready sprites + atlas.

Why this exists: generative models emit 1024x1024 soft, off-palette images.
A game needs crisp grid-aligned sprites on one shared palette. This script does
the mechanical part (key-out, downscale, palette-lock, atlas pack) so the human
time goes into taste, not cleanup.

Usage:
  python3 tools/asset_pipeline.py --src assets/raw --out assets/generated
  python3 tools/asset_pipeline.py --src assets/raw --out assets/generated \
      --grid 32 --colors 32 --scale 4 --key 255,0,255

Outputs: <out>/sprites/<name>.png, <out>/atlas.png (1x, game-ready),
         <out>/atlas_preview.png (xN, for eyeballing), <out>/atlas.json
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image

EXTS = {".png", ".jpg", ".jpeg", ".webp"}


def key_out(img: Image.Image, rgb: tuple[int, int, int], tolerance: int) -> Image.Image:
    """Remove a flat background (magenta by default) by flood-filling from the border."""
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()
    stack = [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)]
    seen = set()
    while stack:
        x, y = stack.pop()
        if (x, y) in seen or not (0 <= x < w and 0 <= y < h):
            continue
        seen.add((x, y))
        r, g, b, a = px[x, y]
        if a == 0 or max(abs(r - rgb[0]), abs(g - rgb[1]), abs(b - rgb[2])) <= tolerance:
            px[x, y] = (0, 0, 0, 0)
            stack.extend([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])
    return img


def to_grid(img: Image.Image, grid: int, colors: int, palette: list[tuple[int, int, int]] | None) -> Image.Image:
    """Downscale to true pixel grid, then quantize so every asset shares one palette."""
    img = img.convert("RGBA")
    alpha = img.getchannel("A")
    img = img.resize((grid, grid), Image.NEAREST)
    alpha = alpha.resize((grid, grid), Image.NEAREST)
    if palette:
        pal_img = Image.new("P", (1, 1))
        flat = [c for rgb in palette for c in rgb]
        pal_img.putpalette(flat + [0] * (768 - len(flat)))
        quant = img.convert("RGB").quantize(palette=pal_img, dither=Image.Dither.NONE)
    else:
        quant = img.convert("RGB").quantize(colors=colors, method=Image.Quantize.MEDIANCUT,
                                            dither=Image.Dither.NONE)
    out = quant.convert("RGBA")
    out.putalpha(alpha)
    return out


def pack(sprites: list[tuple[str, Image.Image]], scale: int, pad: int = 1) -> tuple[Image.Image, Image.Image, dict]:
    """Square-ish atlas at 1x (game-ready) plus a scaled preview at Nx for humans."""
    if not sprites:
        raise SystemExit("no sprites to pack")
    cell = max(im.width for _, im in sprites)
    cols = max(1, int(len(sprites) ** 0.5 + 0.999))
    rows = (len(sprites) + cols - 1) // cols
    step = cell + pad * 2
    atlas = Image.new("RGBA", (cols * step, rows * step), (0, 0, 0, 0))
    frames = {}
    for i, (name, im) in enumerate(sprites):
        cx, cy = (i % cols) * step, (i // cols) * step
        atlas.paste(im, (cx + pad, cy + pad))
        frames[name] = {"x": cx + pad, "y": cy + pad, "w": cell, "h": cell}
    preview = atlas.resize((atlas.width * scale, atlas.height * scale), Image.NEAREST)
    return atlas, preview, {"grid": cell, "frames": frames}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--grid", type=int, default=32, help="final sprite size in game pixels")
    ap.add_argument("--colors", type=int, default=32)
    ap.add_argument("--scale", type=int, default=4, help="preview upscale factor for the atlas")
    ap.add_argument("--key", default="255,0,255", help="background colour to remove, r,g,b")
    ap.add_argument("--tolerance", type=int, default=40)
    ap.add_argument("--palette", default="", help="optional path to a .hex palette (one #rrggbb per line)")
    args = ap.parse_args()

    src, out = Path(args.src), Path(args.out)
    (out / "sprites").mkdir(parents=True, exist_ok=True)
    key_rgb = tuple(int(v) for v in args.key.split(","))
    palette = None
    if args.palette:
        palette = []
        for line in Path(args.palette).read_text().splitlines():
            line = line.strip()
            if line.startswith("#") and len(line) >= 7:
                palette.append(tuple(int(line[i:i + 2], 16) for i in (1, 3, 5)))

    sprites = []
    for path in sorted(p for p in src.iterdir() if p.suffix.lower() in EXTS):
        img = Image.open(path).convert("RGBA")
        img = key_out(img, key_rgb, args.tolerance)
        img = to_grid(img, args.grid, args.colors, palette)
        img.save(out / "sprites" / f"{path.stem}.png")
        sprites.append((path.stem, img))
        print(f"  {path.name} -> {args.grid}x{args.grid}")

    atlas, preview, meta = pack(sprites, args.scale)
    atlas.save(out / "atlas.png")
    preview.save(out / "atlas_preview.png")
    (out / "atlas.json").write_text(json.dumps(meta, indent=2))
    print(f"atlas: {atlas.width}x{atlas.height} ({len(sprites)} frames), preview x{args.scale} -> {out/'atlas_preview.png'}")


if __name__ == "__main__":
    main()
