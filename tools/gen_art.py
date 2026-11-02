#!/usr/bin/env python3
"""Gemini image -> palette-locked pixel art.

    python3 tools/gen_art.py --only bg_greenhouse
    python3 tools/gen_art.py --all

Needs a funded GEMINI_IMAGE_KEY (billing on the AI Studio project).
Raw output lands in assets/gen/raw, processed art in assets/gen.
"""

import argparse
import base64
import json
import os
import urllib.request

from PIL import Image

MODEL = "gemini-2.5-flash-image"
ENV = os.path.expanduser("~/.hermes/.env")

STYLE = ("16-bit pixel art, limited palette, crisp hard pixels, no anti-aliasing, "
         "no text, no watermark, no people, first person view, 16:9 composition")

PROMPTS = {
    "bg_counter": (
        "First person view standing behind a wooden shop counter in a small greenhouse "
        "on a moon. Bare wooden counter fills the bottom quarter of the frame with a "
        "brass till and a small bell. Beyond it: a doorway on the right opening into a "
        "glowing greenhouse, a tall window on the left showing black sky, a big moon and "
        "stars, glass panels, hanging grow lamps. Muted teal and warm brass palette, "
        "dim night lighting. " + STYLE),
    "bg_greenhouse": (
        "First person view inside a small glass greenhouse on a moon, standing in the "
        "aisle between two rows of large low wooden planter boxes filled with dark bare "
        "soil. The planter boxes are EMPTY, only soil, no plants in them. Hanging grow "
        "lamps above each row, glass roof panels with metal struts, moon and ringed "
        "planet visible through the glass, packed soil floor between the rows, a few "
        "small potted plants far in the background only. Muted teal and warm brass "
        "palette, dim night lighting. " + STYLE),
}


def api_key():
    for line in open(ENV):
        if line.startswith("GEMINI_IMAGE_KEY="):
            return line.split("=", 1)[1].strip()
    raise SystemExit("no GEMINI_IMAGE_KEY")


def generate(prompt: str) -> Image.Image:
    key = api_key()
    url = ("https://generativelanguage.googleapis.com/v1beta/models/"
           + MODEL + ":generateContent?key=" + key)
    body = json.dumps({"contents": [{"parts": [{"text": prompt}]}]}).encode()
    req = urllib.request.Request(url, data=body,
                                 headers={"Content-Type": "application/json"})
    data = json.loads(urllib.request.urlopen(req, timeout=180).read())
    for part in data["candidates"][0]["content"]["parts"]:
        if "inlineData" in part:
            raw = base64.b64decode(part["inlineData"]["data"])
            return Image.open(__import__("io").BytesIO(raw)).convert("RGB")
    raise SystemExit("no image in response")


def palette_image():
    pal = json.load(open(os.path.join(os.path.dirname(__file__), "..",
                                      "assets", "palette", "palette.json")))
    cols = []
    for ramp in pal["ramps"].values():
        for h in ramp:
            h = h.lstrip("#")
            cols.append(tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)))
    flat = []
    for c in cols:
        flat.extend(c)
    flat.extend([0] * (768 - len(flat)))
    p = Image.new("P", (1, 1))
    p.putpalette(flat)
    return p


def process(img: Image.Image, size=(480, 270)) -> Image.Image:
    w, h = size
    img = img.resize((w, h), Image.BOX)
    q = img.quantize(palette=palette_image(), dither=Image.NONE)
    return q.convert("RGB")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", action="append", default=[])
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--out", default="assets/gen")
    args = ap.parse_args()
    names = list(PROMPTS) if args.all or not args.only else args.only
    raw_dir = os.path.join(args.out, "raw")
    os.makedirs(raw_dir, exist_ok=True)
    for name in names:
        img = generate(PROMPTS[name])
        img.save(os.path.join(raw_dir, name + ".png"))
        process(img).save(os.path.join(args.out, name + ".png"))
        print("gen ->", name, img.size)


if __name__ == "__main__":
    main()
