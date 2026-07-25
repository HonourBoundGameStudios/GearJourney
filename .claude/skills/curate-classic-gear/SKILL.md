---
name: curate-classic-gear
description: Source and verify the best WoW Classic (Era) weapons and armor for a class, for each spec, and for each playable race, then write it to that class's hardcoded gear JSON (Tools/gear/<class>.json) and compile it into the addon (JourneyGearData.lua). Uses Wowhead Classic online endpoints to discover, resolve, and verify every item id<->name before it ships. Use when the user says "better gear for <class>", "gear for <class>/<spec>/<race>", "curate <class> weapons and armor", "add best-in-slot items", or "refresh the class gear data".
---

# Curate Classic Gear (class × spec × race, hardcoded to JSON)

Gear Journey ships a **hardcoded** gear guide: the best weapons and armor for every class, every spec,
and every playable race, authored as JSON and compiled to a Lua table the addon loads. This skill is
how you produce and verify that data.

```
Tools/gear/<class>.json   <- you write this (source of truth: class × spec × race)
      │  py Tools/build_gear_data.py
      ▼
JourneyGearData.lua        <- generated (DO NOT hand-edit); listed in the .toc; the game loads it
```

The game **cannot read JSON at runtime** (no `io`, no JSON parser in Classic Era Lua), so JSON is only
the authoring/tooling format — the shipped artifact is the generated Lua. See `Tools/gear/README.md`
for the schema.

## What "each spec, each race" means here

- **Specs** — every class has 3 talent tabs (specIndex 1..3), in the order of `Engine.CLASS_SPEC_WEIGHTS`
  (`JourneyEngine.lua` ~line 564). Some collapse to one gear profile (Mage/Warlock/Hunter/Rogue), some
  split caster vs physical (Druid, Shaman, Priest), some are three-way (Warrior, Paladin). Cover every
  distinct profile.
- **Races** — only the races that can be that class in Classic Era exist in the file. The full table is
  in `Tools/gear/README.md`; the generator **rejects invalid combos** (e.g. an Orc Paladin). Race
  barely changes gear: the real signal is the **weapon-skill racial** reordering weapon choice —
  **Human** (Sword/Mace), **Orc** (Axe), **Dwarf** (Gun), **Troll** (Bow) — plus a few race/faction-locked
  items. Every other race's list usually equals the spec's neutral base.

**Author once, materialize the matrix.** Build a strong neutral base list per spec, then produce each
race's list by applying that race's weapon-skill reorder and adding any race/faction-locked pieces.
Write all valid races explicitly into the JSON (the shipped data is the full matrix), but you only
hand-curate the base + the per-race deltas.

## The three online endpoints (all verified working)

1. **Discover** candidate item *names* for a class/spec/band:
   - `WebSearch` community guides, e.g. `WoW Classic Era Feral Druid best leveling weapons wowhead`,
     with `allowed_domains: ["wowhead.com","warcrafttavern.com","icy-veins.com"]`.
   - `WebFetch` a Wowhead **guide** page (`wowhead.com/classic/guide/...`) — server-rendered, readable.
     **Do NOT `WebFetch` a filtered item-*listing* page** (`/classic/items/...?filter=`) — JS-only, empty shell.
2. **Resolve name → id** — `WebFetch https://www.wowhead.com/classic/search/suggestions-template?q=<Item+Name>`
   returns the numeric id, quality, and item level.
3. **Verify id ↔ name** — `https://nether.wowhead.com/classic/tooltip/item/<id>` returns clean `name`,
   numeric `quality` (2+ = uncommon+), and `Requires Level N`. This mirrors the in-game
   `Engine.NameMatches` guard, which **silently drops** any entry whose live name != the stored name.

The bundled **`verify-items.ps1`** wraps endpoint 3 and reads **both JSON and Lua** (de-duping ids, so
the repeated matrix entries fetch once each). Always run it before compiling. Call it in-process:

```powershell
& ".claude/skills/curate-classic-gear/verify-items.ps1" Tools/gear/druid.json   # a gear JSON
& ".claude/skills/curate-classic-gear/verify-items.ps1" -Ids 2244,1482           # ad-hoc ids
```
It prints `MATCH` / `MISMATCH -> '<live name>'` with quality + required level, flags `[POOR/COMMON]`
(quality < 2) and `[ERA?]` (id >= 200000), and exits non-zero on any problem.

## Engine consumption (constraints the data must satisfy)

The generator dual-publishes so both engine consumers keep working:
- `GearJourney_GearData[CLASS][specIndex][RACETOKEN]` — the per-race render lookup
  (`JourneyOverlay.RenderGuide`, keyed on `UnitRace("player")`; note **Undead's token is `Scourge`** —
  the generator maps `"Undead"` → `Scourge`).
- `GearJourney_ClassGuides[CLASS]` — a flat deduped union of every id, for the enrichment queue
  (`JourneyProvider.BuildQueue` walks every id to resolve stats/name).

Data rules (the generator and the guard test enforce most of these):
- **Usable only** — weapon types the class can wield (`Engine.WEAPON_PROF`) and armor of its tab
  (`Engine.CLASS_ARMOR`), plus neutral neck/ring/trinket/cloak/held. The engine drops the rest.
- **Bands** — the guide buckets by `Engine.BandIndex(reqLevel)`: 1-10, 11-20, 21-30, 31-40, 41-50,
  51-59, and **60 is its own band 7**. Aim for weapons + each armor slot across bands 1-6; band 7 is raid/BiS.
- **In era** — ids `< 200000` only (200000+ is SoD/Anniversary). The verifier flags `[ERA?]`; the
  generator rejects out-of-range ids.
- **Off-spec** — `Engine.IsOffSpec` still hard-cuts caster gear from a physical spec's view (and vice
  versa) at render, so don't rely on race to fix a wrong-school list — put the right items in per spec.

## The workflow — RED → GREEN → COMMIT, one class per commit

### Step 0 — Scope
Pick the class. Read its `Engine.CLASS_SPEC_WEIGHTS` row (distinct profiles) and its race list in
`Tools/gear/README.md`. Open the existing `Tools/gear/<class>.json` (or create it from the schema).
Run `verify-items.ps1 Tools/gear/<class>.json` first to confirm the current data still verifies and to
see the band spread (the RLvl column) — that shows which specs/bands/slots are thin.

### Step 1 — RED (state the gap)
Name the concrete gap: "Feral Druid has no melee weapon in bands 3-4", "Holy Paladin 41-50 armor empty",
"Orc Warrior weapons don't lead with axes". This is what you'll confirm fixed in-game later.

### Step 2 — Discover → resolve → verify (build the additions)
For each starved spec/band: `WebSearch` + `WebFetch` a guide for candidate names → resolve each to an id
via `suggestions-template` → collect `{ "id": N, "name": "Exact Name" }`. Prefer uncommon+ (quality ≥ 2),
class-usable, in-era pieces with real primary-stat value for the spec.

### Step 3 — GREEN (write the JSON, materialize the matrix)
Write the base list per spec, then fill every valid race: same base, reordered for that race's weapon-skill
racial (axes first for Orc, swords/maces for Human, guns for Dwarf, bows for Troll), plus any race/faction-locked
items. Keep valid JSON (the schema in `Tools/gear/README.md`). No duplicate id within a single race list.

### Step 4 — Verify + compile (the gate)
```powershell
& ".claude/skills/curate-classic-gear/verify-items.ps1" Tools/gear/<class>.json   # fix every MISMATCH / [ERA?]
py Tools/build_gear_data.py                                                        # JSON -> JourneyGearData.lua
```
Then the offline suite:
```bash
lua Tests/journey_geardata_test.lua        # structural guard for the compiled data
for f in Tests/*_test.lua; do lua "$f" >/dev/null 2>&1 || echo "FAIL: $f"; done
```
A `MISMATCH` left in ships as an item that silently never appears in-game. All green before proceeding.

### Step 5 — Eye-verify in the client (standing order — one screenshot is not sign-off)
`./deploy.ps1`, then in-game `/reload`. Open the Class Guide and **preview each spec**, and check on
**more than one race** of the class where a weapon-skill racial applies (e.g. an Orc vs a Human Warrior —
the Orc list should lead with axes). Confirm the filled bands/slots now show items; scan for defects
(wrong item, missing icon, off-spec leakage) in more than one state. The owner runs the client — present
exactly what to check.

### Step 6 — Commit (one class)
Commit the JSON **and** the regenerated Lua together:
```bash
git add Tools/gear/<class>.json JourneyGearData.lua
git commit -m "feat(gear): hardcode <Class> gear for <specs/races/bands filled>"
```
**Do not push** — the agent commits, the Admiral pushes. Report it ready.

## Gotchas

- **A name mismatch is invisible, not an error.** `verify-items.ps1` is the only thing between a typo
  and a missing item. Run it every time, on the JSON, before compiling.
- **Never hand-edit `JourneyGearData.lua`.** It's generated. Edit `Tools/gear/<class>.json` and recompile.
- **Undead's race token is `Scourge`.** Write `"Undead"` in JSON; the generator maps it. Don't key JSON on `Scourge`.
- **Wowhead item-*listing* pages don't fetch** — only guide pages, the suggestions endpoint, and the
  tooltip endpoint return server-side data. Search via `WebSearch` → guide `WebFetch` → resolve → verify.
- **Be polite to Wowhead** — the verifier throttles (~8 req/s) and de-dupes. Don't hammer with unthrottled parallel fetches.
- **Band 1-10 needs specific low items**, not high-ilvl no-req pieces (those would flood the "levels 1-10" view).
