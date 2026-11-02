# Greenhouse Shop (working title)

M0 of a greenhouse trading sim set on a tiny moon: grow plants, trade with the miners
who land outside, and let your shop rating decide who flies in tomorrow.

Godot 4.7, GDScript, no plugins. The simulation spine is headless-testable; the UI is
still debug buttons — pixel art and the side-view room land in M2/M3.

## Run

```
godot --path .            # play
./check.sh                # 89 assertions + headless UI smoke
godot --headless --path . --script res://tests/balance_sim.gd -- 30   # 30-day economy table
```

## What M0 does

| System | Behaviour |
|---|---|
| Day loop | 4-8 visitors/day from shop rating, upkeep `40+4*day`, broke = run over |
| Plants | 6 species, 3 growth stages, per-day growth = light x water x temperature |
| Benches | 3 benches x 2 slots, one lamp per bench (high-light species need it) |
| Morning budget | 6 actions/day: watering and lamp switching cost a tick, harvesting is free |
| Barter | Customers bring goods + cash and want specific produce; unwanted goods trade at 60% |
| Rating | +0.7 accepted / -0.5 refused / -1 walkout, decay 0.5/day, tier 2 at 25 |
| Persistence | JSON save/load of plants, benches, stock, rating |

## Structure

```
scripts/core/        pure sim (no scene deps): Plant, GrowSim, Barter, Customer, DayCycle, Rating
scripts/autoload/    GameState singleton: owns the run, applies sim results
scripts/ui/          shop_screen.gd — debug counter UI + --smoke integration test
data/                plants.json, goods.json, customers.json, quests.json
tests/               run_tests.gd (unit), balance_sim.gd (economy tuning table)
tools/               asset_pipeline.py (pixel-art pipeline)
docs/                implementation-plan.md, roadmap.md, steam-checklist.md
```

## Balance snapshot (30-day bot run, seed 4242)

```
day  cash  rating  visitors  trades  harvests
  1   588     4.0         4       4         0
 15  1844    22.9         5      12         2
 30  2888    32.4         6      12         4
```

Tuned with `balance_sim.gd`, not by feel. If you change a number in `data/`, re-run it.

## Next

M1 = grow loop polish (seeds, repotting, plant stress readout). See `docs/implementation-plan.md`.
