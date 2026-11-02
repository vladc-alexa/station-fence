# Steam checklist

## Before you write more code

- [ ] **Name cleared** — Steam search + trademark search (EUIPO/USPTO) for the title.
- [ ] **Engine decision locked** — Godot 4.7 here; Steam works fine, ~2 MB runtime overhead.
- [ ] **Scope written down** — one paragraph: what the player does in 30 minutes. Everything
      in the roadmap must serve that sentence.

## Account + money

- [ ] Steamworks account, $100 USD app fee per app (recoupable after $1,000 revenue).
- [ ] Tax interview + bank details (W-8BEN for RO/AT residency).
- [ ] Company vs personal: revenue → Romanian SRL or Austrian sole trader, decide before launch.

## Store page

- [ ] Capsule art: 616×353, 460×215, 231×87, 374×448 (library), 1920×620 (header).
- [ ] 10 screenshots at 1920×1080, first one shows the core loop, not the menu.
- [ ] Trailer: 60–90 s, gameplay in first 5 s, no logo intro.
- [ ] Tags: Simulation, Management, Economy, Cyberpunk, Pixel Graphics, Singleplayer.
- [ ] Short description ≤ 300 chars; long description with 3 feature blocks, no lore walls.
- [ ] **AI disclosure** — Steam requires declaring pre-generated and live-generated AI content.
      Declare it accurately; undisclosed AI assets are a store-removal risk.
- [ ] Age rating questionnaire (contraband/drug references will bump the rating).
- [ ] Page live ≥ 3 months before launch for wishlists; don't launch on a page with 0 followers.

## Build

- [ ] Export templates for the exact Godot version installed.
- [ ] `export_presets.cfg` with Linux + Windows x86_64, embed PCK off, debug off.
- [ ] GodotSteam plugin + `steam_appid.txt` for local testing; achievements + cloud saves wired.
- [ ] Resolution: integer scaling only (`canvas_items` + nearest filter), 1280×720 base,
      letterbox to 16:9/16:10; test on a 4K display and a Steam Deck.
- [ ] Steam Deck: controller-only playable, text ≥ 14 px at 1280×800, verify via Proton.
- [ ] Save path is `user://` (already); test migration from an older save version.

## SteamPipe upload

- [ ] `steamcmd +login <builder> +run_app_build ../scripts/app_build_<appid>.vdf`
- [ ] Depot split: content (exe/pck/assets) + optional separate depot for localization.
- [ ] Set build live on `default` branch, then test with a fresh install on a clean machine.
- [ ] Branch strategy: `default` (public), `beta` (playtest), `internal`.

## Launch

- [ ] Demo build submitted (demo is the single biggest wishlist driver for sims).
- [ ] Next Fest registration (needs a demo, deadline ~2 months ahead).
- [ ] Press/creator list: 100 contacts, personalized, keys 2 weeks before launch.
- [ ] Launch discount 10% for 7 days; do not launch on a Friday or a Steam sale.
- [ ] Support: a Discord/Steam forum you actually read; refund policy is Steam's, not yours.

## Known traps

- AI assets are allowed but *must* be disclosed, and visible artifacts get called out in reviews.
- Wishlists < 5,000 at launch usually means < 1,000 units sold. Marketing is not optional.
- Sim audiences punish shallow economies faster than ugly art.
- Do not localize before the English text stops changing daily.
