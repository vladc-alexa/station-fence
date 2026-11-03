# station-fence — Greenhouse Shop (Godot 4.7, GDScript, no plugins)

First-person greenhouse trading sim on a tiny moon. One walkable first-person room scene
(`scenes/fp.tscn`) + a headless-testable simulation spine. Ship straight to `main`, no PRs.

## Commands (run from the repo root; Godot binary = `~/tools/godot` or `$GODOT`)
```
./check.sh                     # import pass -> unit tests -> headless UI smoke; must print ALL GREEN
~/tools/godot --path .         # play (window 1440x810, integer-scaled from 480x270)
~/tools/godot --headless --path . --script res://tests/balance_sim.gd -- 30   # economy table
~/tools/godot --headless --path . --check-only --script res://scripts/foo.gd  # fast parse check
xvfb-run -a ~/tools/godot --path . --rendering-driver opengl3 --resolution 1440x810 -- --shot=/tmp/x.png
```
Never pipe a build/test command through `tail`/`head` — `check.sh` already tees to `/tmp/station-fence-*.log`.

## Map
- `scenes/fp.tscn` — the whole UI: background views + clickable hotspots (no character sprites, ever).
- `scripts/autoload/game_state.gd` — day loop, plants, benches, stock, rating, JSON save/load.
- `scripts/core/`, `scripts/ui/` — pure sim logic vs. presentation; keep sim logic headless-testable.
- `data/*.json` — plants, goods, customers, quests (content layer; edit here, not in code).
- `tests/run_tests.gd` (assertions), `tests/balance_sim.gd` (30-day economy), `tools/*.py` (art/palette/font generation).

## Pitfalls that have actually bitten
- A fresh clone/`.godot` needs `--import` first or `--script` fails on unknown `class_name` (check.sh does it).
- Smoke args need the `--` separator: `godot --headless --path . -- --smoke`.
- Stretched viewport: map clicks with `get_viewport().get_mouse_position()`, not raw event coords, and set
  `mouse_filter = IGNORE` on decorative layers — otherwise hotspots silently miss.
- Palette is locked by `tools/make_palette.py`; new art must be generated through `tools/` (quantized), not dropped in.
- Regenerating sprites changes `.import` files too — commit them together or the build differs.

## Cost hygiene
Start a new session per task; long channel sessions resend the full transcript every call. Grep/`head`
instead of reading whole files or full logs.
