# Roadmap

Each milestone is shippable/playable on its own. Times assume solo, full-time, with an
agent doing the code.

## M0 — Barebones (done)

Day loop, 10 items, 4 customer archetypes, appraisal, buy/sell, heat + rep, undercover,
rent, game over, save/load, text UI, headless tests, art pipeline.

## M1 — First playable (2–4 weeks)

- Render the shop: shelf grid with sprites, customer portrait at the counter.
- Hover inspection: item card with condition, wear, serial numbers, maker marks.
- Counter offer loop: customer counters up to 2× before walking.
- 60 items across 6 categories; rarity tiers; category demand per day.
- Heat consequences: fines, raid event, bribe.
- Keyboard/gamepad input, pause, settings, quit-to-desktop.
- Audio pass: 1 loop, 8 SFX, UI clicks.

**Exit test:** a stranger plays 20 minutes without asking what to do.

## M2 — Economy depth (4–6 weeks)

- Crafting/repair: cleaning, re-serializing, refurbishing (cost + time + skill).
- Permits: legal goods need a licence; unlicensed legal goods are seized.
- Faction reputation (2 factions) with price modifiers and job offers.
- Employees: one hire who serves walk-in buyers passively.
- Difficulty curve: rent/wholesale prices scale with day, not with cash.

**Exit test:** 10-day balance sim passes for three different strategies (volume, margin,
contraband) with none dominating.

## M3 — Content + polish (6–10 weeks)

- 300+ items, 40 customer barks per archetype, 3 shop upgrades, 2 endings.
- Juice: screen shake on bust, coin sound with pitch variance, day-end summary card.
- Tutorial: 3 in-game days that teach appraisal by doing.
- Localization scaffolding (CSV → engine), 5 locales drafted by LLM + native pass.
- Steam: appid, GodotSteam, achievements (10), cloud saves, SteamPipe depots.

**Exit test:** demo build that holds a 20-minute session at a festival.

## M4 — Release (4–8 weeks, mostly not code)

- Store page live 3+ months before launch, wishlist campaign, demo in Next Fest.
- Press/creator keys, trailer (90s), capsule art (3 sizes), screenshots (10).
- AI disclosure filed, age ratings, EULA, refund/support workflow.

## Deliberately out of scope

Multiplayer, 3D, voice acting, console ports, workshop/modding, live service.

## Balance knobs (one place, tuned by simulation)

`day_cycle.gd`: visitors/day, rent curve, archetype weights, budget range.
`deal.gd`: heat per sale, undercover base chance.
`item_instance.gd`: quality spread, appraisal error band.
`data/items.json`: base values, heat weights.

Run `./check.sh` after every knob change — the 10-day economy assertion is the guardrail.
