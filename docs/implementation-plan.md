# Greenhouse Shop — Implementation Plan

> **For Hermes:** implement task-by-task with TDD; each task ends green (`./check.sh`) + commit.

**Goal:** Pivot `station-fence` from a text pawnshop into a side-view, detailed-pixel-art greenhouse shop
on a tiny moon — grow plants, barter with miners, serve richer customers, unlock quests.

**Architecture:** Keep the deterministic headless sim core (day cycle, customers, deals, rating,
save/load, test harness, art pipeline) and replace the content + presentation layers: plants and
goods instead of scrap items, growing instead of pure resale, a tile-based side-view room instead of
text buttons.

**Tech stack:** Godot 4.7 (GDScript), JSON data files, Pillow asset pipeline, headless test runner.

---

## 0. Source design intent (your sketch, transcribed)

Page 1 — shop layout
- "Inventory Management" · "Shop/Quest office annex"
- Vertical label: **Helipad / Spatioport** — customers land outside.
- **Counter** — long counter in the foreground; NPC drawn standing behind it (leafy hair: plant-person).
- Right side: dense foliage / pines inside the shop.
- Margin note: *"Diferite NPC cu mașină / săracu' / mânios / lenoman cu marfa veche sau pe jos.
  Fiecare cu aparat de zbor."* → different NPCs with vehicles: the poor one, the angry one, the lazy
  one with old goods or on foot; each has a flying craft.

Page 2 — world + flow
- Drawing labelled **"Opțiune: un satelit natural f. mic"** — a small natural moon. On it: a shack,
  plants, crystals, a hanging swing, a flag. Notes: *"Poate puțin mai mare.. să aibă și pădure,
  pădure, mină, etc. — locuri de Questuri."*
- *"Câteva personaje vizitează magazinul pe zi, în funcție de ratingul magazinului."*
- *"La început doar minerii/săracii care aduc câteva minerale, resturi/junk și vor suc, mâncare,
  pătuțuri, medicamente, și poate orice altceva de vânzare."*
- *"Apoi introducem câte un om care vine și aduce lucruri mai scumpe/interesante și pe care ți-l
  putem trimite în Questuri."*

Read: **rating drives traffic → poor customers barter raw material for consumables → richer
customers unlock quests → quests open the moon (forest, mine).**

## 1. Current context

Repo `vladc-alexa/station-fence` (public, commit 345e0f1 + check.sh fix): 183 unit assertions + UI
smoke, all green, zero art.

| Reuse as-is | Rewrite | New |
|---|---|---|
| `GameRNG`, day loop skeleton, `Deal` (price/barter math), `rating` (from reputation), save/load JSON, `check.sh`, test runner, `tools/asset_pipeline.py` | Item defs → plant/good defs; customer archetypes → miner/angry/lazy/rich; UI → tiled room + panels | Grow simulation, plant state, barter requests, quest graph, tile rooms, sprite/animation layer, lighting |

Assumptions (correct me and I'll re-cut the plan):
- **A1** Same repo, new branch `pivot-greenhouse`; repo renamed when the title is settled.
- **A2** Solo dev, ~15 h/week; AI writes code, you own taste calls.
- **A3** English UI at ship; Romanian dev notes fine.
- **A4** No combat, no player avatar in the world at first — you *are* the shopkeeper behind the counter.

## 2. Recommended design decisions

| Question | Recommendation | Why |
|---|---|---|
| View | **Side-view fixed camera room**, 3 parallax planes, no camera scroll | Sketch shows it; kills 4-directional walk cycles and level design; cheapest path to *detailed* art |
| Base res | **480×270** (16:9), integer ×4 → 1920×1080 | 16px tiles, 48×64 characters; readable at Steam deck size |
| Tiles | 16×16, room = 30×17 tiles exactly | One screen = one room = one scene |
| Time | **Turn/queue-based day** (customer at counter, "Next" advances), plants advance overnight | Papers-Please clarity, deterministic, testable |
| Economy | **Barter-first**: customers pay partly in goods; cash for the rich tier | Matches sketch ("aduc minerale... vor suc"); cash-only is what the old build already did |
| Protagonist | Plant-person shopkeeper, seen only from behind/at counter | Matches sketch; cheap to animate |
| Player actions | Water, lamp on/off, repot, harvest, open counter, trade | 6 verbs, all one-click, all state-changing |

## 3. Core loop

1. **Morning (grow room)** — check benches: water, light, temperature. Each action costs 1 "tick"
   of the morning budget (6 ticks). Neglect → wilt debuff.
2. **Overnight growth** happens at day end; stage thresholds accumulate.
3. **Open shop** — queue of 3–8 visitors scaled by rating; each has a *want* (goods) and *brings*
   (raw stock or cash).
4. **Trade** — accept / counter / refuse; barter basket UI; refusing costs rating slightly.
5. **Close** — upkeep (power, water, rent) deducted, rating recomputed, plants tick, event roll.
6. **Unlock** — at rating thresholds, a tier-2 customer appears with a quest hook (mine, forest).

Rating (0–100, float, decays 2/day): `+trade_value/50`, `+0.5 per happy customer`, `-1 refusal`,
`-3 expired request`, cap 100. Visitor count = `clamp(2 + floor(rating/12), 2, 8)`.

## 4. Data model (JSON, loaded by a static DB class per file)

```json
// data/plants.json
{
  "id": "lumen_moss",
  "name": "Lumen Moss",
  "stage_days": [2, 3, 4],          // days to reach stage 2, 3, 4(harvestable)
  "water_per_day": 1.0,
  "light_need": "low|mid|high",
  "temp_c": [12, 26],
  "yield": {"id": "glow_sap", "min": 1, "max": 3},
  "wilt_penalty": 0.25,
  "value": 40,
  "sprite": "res://art/plants/lumen_moss.png"
}
```

Other files: `goods.json` (id, name, category, base_value, stack, icon), `customers.json`
(archetype, tier, budget, wants[], brings[], sprite, quip pool), `quests.json` (id, hook_customer,
requires_rating, location, steps[], rewards[]).

Grow sim (pure, seeded, no nodes):
```
progress += light_factor * water_factor * temp_factor (0..1 each)
stage = count(progress >= cumulative(stage_days))
wilt if water_deficit_days >= 2 → progress *= (1 - wilt_penalty)
```

## 5. Presentation & art spec

**Style bible (write once, obey everywhere):**
- Palette: 32 colours, "greenhouse dusk" — desaturated teal shadows, warm lamp ochre,
  magenta grow-light accent. Every asset quantized to it (pipeline enforces).
- 1px dark outline on interactables only; interior props unoutlined for depth.
- Light from upper-left; one rim highlight colour; dither only on glass and gradients.
- No anti-aliasing anywhere; nearest-neighbour everywhere (`default_texture_filter=0`, already set).

**Asset inventory**

| Asset | Count | Size | Source |
|---|---|---|---|
| Plants × 4 stages | 12 × 4 = 48 | 32×32 (tall: 32×48) | AI + manual cleanup |
| Good/item icons | 24 | 16×16 | AI, palette-locked |
| Characters (idle 2f + walk 4f + hand-over 1f) | 6 archetypes × 3 recolours = 18 | 48×64 | AI sheet → slicer → manual fix |
| Room background layers | 3 | 480×270 | AI/matte paint, then pixel pass |
| Props (shelves, pots, lamps, pipes, crates, till, pad) | 45 | 16–64 | AI + manual |
| UI (panel 9-slice, buttons, icons, cursor) | ~15 | 8–48 | hand-authored |
| Font | 1 | — | OFL pixel font (m5x7 / Pixeloid) |

**Pipeline:** `python3 tools/asset_pipeline.py --src art/raw --out art/gen --grid 32 --key magenta`
→ key-out, grid snap, palette quantize, atlas + JSON. Character sheets use the sprite-sheet flow:
generate a 2×4 grid on flat grey, slice on a **fixed** grid, align on the existing baseline, then a
manual pass in Aseprite for silhouette and eyes.

**Honest split:** AI is good enough for plants, props, icons, backgrounds after palette-lock.
Characters need a human pass — budget **€200–400** for a pixel artist to fix 6 characters, or
**€1.5–2.5k** for a full art pass. Do not ship raw AI characters; they read as slop at 4× zoom.

## 6. Repo changes

```
scenes/  main.tscn  interior.tscn  ui/{hud,trade_panel,ledger}.tscn
scripts/core/  plant_def.gd plant.gd grow_sim.gd goods_db.gd request.gd rating.gd quest.gd
scripts/world/ room_builder.gd bench_slot.gd customer_actor.gd parallax.gd
scripts/ui/    shop_screen.gd (rewritten) trade_panel.gd hud.gd
data/          plants.json goods.json customers.json quests.json
art/raw/ art/gen/ art/plants/ art/chars/ art/tiles/ art/ui/
tests/         run_tests.gd (kept) + test_grow.gd test_barter.gd test_rating.gd
```

Delete: `scripts/core/item_def.gd`, `item_instance.gd`, `item_db.gd`, `data/items.json`,
`scripts/ui/shop_screen.gd` body, cyberpunk docs. Keep `deal.gd` as `barter.gd` (rename + rework).

## 7. Milestones

| # | Scope | Exit test | Time (15 h/wk) |
|---|---|---|---|
| M0 | Branch, schema swap, delete cyberpunk content, harness green | `./check.sh` green on empty data | 2 days |
| M1 | Grow sim + 6 plants + debug rectangles + morning ticks | 30-day headless sim: no plant stuck, wilt works | 1.5 weeks |
| M2 | Tiled room, counter, queue, barter panel, rating | smoke: full day with 5 customers, rating changes | 2 weeks |
| M3 | First art pass: room, 12 plants, 4 characters, UI, light | screenshot passes the "would I wishlist this?" test | 3 weeks |
| M4 | Quests + moon map stub (mine, forest) + tier-2 customers | one quest playable start→reward | 2.5 weeks |
| M5 | Steam demo build + page + trailer-ish capture | builds on Win/Linux, 20-min session | 1.5 weeks |

Demo-ready ≈ **10–11 weeks at 15 h/week** (≈5 months calendar with a real job), or ~5 weeks if you
go full-time. Early Access content-complete after that: +4–6 months.

## 8. M1 task list (bite-sized, TDD)

**Task 1 — plant data schema**
Files: create `data/plants.json` (6 entries), `scripts/core/plant_def.gd`, `scripts/core/plant_db.gd`.
Test: `tests/test_grow.gd::test_plant_db_loads_six` — `PlantDB.all().size() == 6`, every def has
`stage_days.size() == 3`. Run `./check.sh`. Commit `feat: plant definitions`.

**Task 2 — grow accumulator**
Create `scripts/core/grow_sim.gd`: `static func tick(plant: Dictionary, env: Dictionary) -> Dictionary`.
Test: water/light/temp factors each in [0,1]; 10 ideal days → stage 2 reached; 0 water 3 days → wilted
true. Commit.

**Task 3 — plant instance + stage thresholds**
`scripts/core/plant.gd` (`Plant.new(def, rng)`, `to_dict/from_dict`). Test: round-trip equality,
stage never decreases, wilt penalty applied once per deficit streak.

**Task 4 — morning budget**
`scripts/core/morning.gd`: 6 ticks; `water(slot)`, `toggle_lamp(bench)`, `repot(slot)` each cost 1.
Test: 7th action refused with `budget_exhausted`.

**Task 5 — day-end tick wiring**
`DayCycle` gains `end_day(plants, env) -> summary`; test 30 seeded days → all plants reach stage 4 or
wilt, none NaN, deterministic across two runs of the same seed.

**Task 6 — headless playthrough smoke**
Extend `--smoke`: tend 6 plants for 10 days, assert cash/upkeep/report printed. Exit green.

## 9. Verification

- `./check.sh` after every task (unit + smoke, ~2 s).
- Determinism: same seed → identical 30-day summary hash printed by the runner.
- Visual: `tools/asset_pipeline.py` preview PNG attached to each art PR; screenshots at 1× and 4×.
- No art enters the repo un-palette-locked (pipeline is the only write path to `art/gen`).

## 10. Cost

| Item | Cost |
|---|---|
| Code tokens (DeepSeek, M0–M5) | **$25–60** |
| Art: AI gen | ~$10 (needs a topped-up image key — current Gemini key is 402) |
| Art: pixel artist pass on 6 characters | €200–400 |
| Steam app fee (when you get there) | $100 |
| Total to demo | **≈ €300–500** |

## 11. Risks

| Risk | Mitigation |
|---|---|
| "Detailed pixel art" is where AI fails — inconsistency reads as slop | Style bible + palette lock + one human pass on characters; judge at 4× zoom, not thumbnail |
| Grow sim is boring if it's just waiting | Every stage must change the *silhouette*, and neglect must be visible immediately |
| Barter economy hard to balance | Existing seeded 10-day sim test pattern; assert solvency + margin invariants |
| Quest scope creep | M4 is one quest, one location stub; the map is a menu until M6 |
| Solo time | Milestones each end in something screenshot-able or it doesn't count |

## 12. Open questions (my default in bold)

1. **Barter-first (bold)** or cash-only? — sketch says barter.
2. Turn-based queue **(bold)** or real-time clock pressure? — turn-based is testable and cheaper to art.
3. Do you want a walkable avatar later, or stay fixed behind the counter **(bold: stay)**?
4. Protagonist: plant-person **(bold)**, human, or drone?
5. Title + name clearance — timing matters before Steam page (there's a `brand-name-clearance` skill for it).
