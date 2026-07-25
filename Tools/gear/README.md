# Hardcoded gear data (class × spec × race)

These JSON files are the **source of truth** for Gear Journey's curated gear guide. The `curate-classic-gear`
skill writes them; `Tools/build_gear_data.py` compiles them into `JourneyGearData.lua`, which the addon loads.
The game cannot read JSON at runtime (no `io`, no JSON parser in Classic Era Lua) — so JSON is authored/tooled
here and shipped as a generated Lua table.

```
Tools/gear/<class>.json    (edit these / skill writes these)
        │  py Tools/build_gear_data.py
        ▼
JourneyGearData.lua        (generated — DO NOT edit by hand; listed in the .toc; the game loads it)
```

## File shape — one file per class

```json
{
  "class": "PALADIN",
  "specs": [
    {
      "index": 1,
      "name": "Holy",
      "races": {
        "Human": [ { "id": 22784, "name": "Sunwell Orb" } ],
        "Dwarf": [ { "id": 22784, "name": "Sunwell Orb" } ]
      }
    },
    { "index": 2, "name": "Protection",  "races": { "Human": [], "Dwarf": [] } },
    { "index": 3, "name": "Retribution", "races": { "Human": [], "Dwarf": [] } }
  ]
}
```

- **`class`** — UnitClass token (uppercase): `WARRIOR PALADIN HUNTER ROGUE PRIEST SHAMAN MAGE WARLOCK DRUID`.
- **`specs`** — always the 3 talent tabs, `index` 1..3 in talent-tab order (matches `Engine.CLASS_SPEC_WEIGHTS`).
- **`races`** — only the races that can be this class in Classic Era (the generator rejects invalid combos).
  Race keys use these names; the generator maps `Undead` → the `Scourge` token the game's `UnitRace` returns.
- **item** — `{ "id": <number>, "name": "<exact live item name>" }`. `id` must be `< 200000` (in-era; 200000+
  is Season of Discovery / Anniversary). The name must match the live Wowhead name exactly — the in-game
  `Engine.NameMatches` guard silently drops any mismatch. Verify with `verify-items.ps1` before compiling.

## Optional `bis` section — handcrafted best-in-slot (EPIC-M)

A class file may add a top-level `"bis"` object: a handcrafted per-slot best-in-slot list per spec,
surfaced in the addon's **BiS tab** (`GearJourney_BiS[CLASS][specIndex]`). Unlike the level-banded
`specs` (which the game bands by live `reqLevel`), BiS is an authored endgame target — the natural home
for no-required-level raid/dungeon drops that would otherwise mis-band into Level 1-10. Slot order is
preserved as authored. Every `id` is folded into the class enrichment union so the provider resolves it.

```json
{
  "class": "WARRIOR",
  "specs": [ ... ],
  "bis": {
    "specs": [
      { "index": 1, "name": "Arms", "slots": [
        { "slot": "Head", "id": 14849, "name": "Sunscale Helmet" },
        { "slot": "Main Hand", "id": 12784, "name": "Arcanite Reaper" }
      ] }
    ]
  }
}
```

- `slot` — free-text label shown in the tab (e.g. `Head`, `Ring 1`, `Main Hand`, `Off Hand`). No
  duplicate slot within a spec.
- `id`/`name` — same rules and verification as the banded lists (`verify-items.ps1` reads both).
- The section is optional; a class without `bis` simply publishes no `GearJourney_BiS[CLASS]` entry.

## Valid class → races (Classic Era)

| Class | Races |
|---|---|
| WARRIOR | Human, Dwarf, NightElf, Gnome, Orc, Undead, Tauren, Troll |
| ROGUE | Human, Dwarf, NightElf, Gnome, Orc, Undead, Troll |
| HUNTER | Dwarf, NightElf, Orc, Tauren, Troll |
| PRIEST | Human, Dwarf, NightElf, Undead, Troll |
| MAGE | Human, Gnome, Undead, Troll |
| WARLOCK | Human, Gnome, Orc, Undead |
| SHAMAN | Orc, Tauren, Troll |
| PALADIN | Human, Dwarf |
| DRUID | NightElf, Tauren |

Only Human (Sword/Mace), Orc (Axe), Dwarf (Gun) and Troll (Bow) have a weapon-skill racial that reorders
weapon choice; for every other race the per-race list usually equals the spec's neutral base plus any
race/faction-locked items.

## Regenerate

```
python Tools/build_gear_data.py      # reads Tools/gear/*.json -> writes JourneyGearData.lua
lua Tests/journey_geardata_test.lua  # structural guard
```
