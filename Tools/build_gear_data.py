#!/usr/bin/env python3
"""Compile Design/gear/*.json into JourneyGearData.lua.

The game cannot read JSON at runtime (no io / no JSON parser in Classic Era Lua),
so the hardcoded class x spec x race gear lives in JSON under Tools/gear/ and ships
as this generated Lua table.

The generated file PUBLISHES, to satisfy the engine consumers:
  * GearJourney_GearData[CLASS][specIndex][RACE] = { {id,name}, ... }
      -- the per-race render lookup (JourneyOverlay.RenderGuide, keyed on UnitRace)
  * GearJourney_ClassGuides[CLASS]               = { {id,name}, ... }  (deduped union)
      -- the flat enrichment queue (JourneyProvider.BuildQueue walks every id)
  * GearJourney_BiS[CLASS][specIndex]            = { {slot,id,name}, ... }  (optional)
      -- the handcrafted per-slot best-in-slot list (JourneyOverlay BiS tab, EPIC-M).
      -- Built only from a class JSON's optional top-level "bis" section; its ids are
      -- folded into the enrichment union so the provider resolves their name/icon.

Run from the project root:  python Tools/build_gear_data.py
"""
import json
import glob
import os
import sys

SRC_GLOB = "Tools/gear/*.json"
OUT = "JourneyGearData.lua"

# UnitClass token -> races that can be that class in Classic Era.
VALID = {
    "WARRIOR": {"Human", "Dwarf", "NightElf", "Gnome", "Orc", "Undead", "Tauren", "Troll"},
    "ROGUE":   {"Human", "Dwarf", "NightElf", "Gnome", "Orc", "Undead", "Troll"},
    "HUNTER":  {"Dwarf", "NightElf", "Orc", "Tauren", "Troll"},
    "PRIEST":  {"Human", "Dwarf", "NightElf", "Undead", "Troll"},
    "MAGE":    {"Human", "Gnome", "Undead", "Troll"},
    "WARLOCK": {"Human", "Gnome", "Orc", "Undead"},
    "SHAMAN":  {"Orc", "Tauren", "Troll"},
    "PALADIN": {"Human", "Dwarf"},
    "DRUID":   {"NightElf", "Tauren"},
}

# JSON race name -> the token UnitRace("player") returns (used as the Lua key).
RACE_TOKEN = {"Undead": "Scourge"}  # all others are identical


def die(msg):
    print("ERROR: " + msg, file=sys.stderr)
    sys.exit(1)


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def load_class(path):
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh)
    cls = data.get("class")
    if cls not in VALID:
        die(f"{path}: unknown class {cls!r}")
    valid_races = VALID[cls]

    # specIndex -> raceToken -> [ {id,name}, ... ]
    specs = {}
    union = {}  # id -> name (deduped across all specs/races)
    for spec in data.get("specs", []):
        idx = spec.get("index")
        if idx not in (1, 2, 3):
            die(f"{path}: spec index must be 1..3, got {idx!r}")
        by_race = {}
        for race, items in (spec.get("races") or {}).items():
            if race not in valid_races:
                die(f"{path}: {cls} cannot be race {race!r} in Classic Era")
            token = RACE_TOKEN.get(race, race)
            seen, out = set(), []
            for it in items:
                iid, name = it.get("id"), it.get("name")
                if not isinstance(iid, int) or not (1 <= iid < 200000):
                    die(f"{path}: {cls}/{spec.get('name')}/{race}: bad id {iid!r} (need 1..199999, in-era)")
                if not isinstance(name, str) or not name:
                    die(f"{path}: {cls}/{spec.get('name')}/{race}: id {iid} has empty name")
                if iid in seen:
                    continue  # de-dupe within one race list
                seen.add(iid)
                out.append((iid, name))
                union.setdefault(iid, name)
            by_race[token] = out
        specs[idx] = by_race

    # Optional handcrafted BiS: specIndex -> [ {slot,id,name}, ... ]. Its ids also
    # join the enrichment union so the provider resolves their name/icon.
    bis = {}
    for spec in (data.get("bis") or {}).get("specs", []):
        idx = spec.get("index")
        if idx not in (1, 2, 3):
            die(f"{path}: bis spec index must be 1..3, got {idx!r}")
        seen, out = set(), []
        for it in (spec.get("slots") or []):
            slot, iid, name = it.get("slot"), it.get("id"), it.get("name")
            if not isinstance(slot, str) or not slot:
                die(f"{path}: {cls} bis spec {idx}: entry missing slot")
            if not isinstance(iid, int) or not (1 <= iid < 200000):
                die(f"{path}: {cls} bis/{slot}: bad id {iid!r} (need 1..199999, in-era)")
            if not isinstance(name, str) or not name:
                die(f"{path}: {cls} bis/{slot}: id {iid} has empty name")
            if (slot, iid) in seen:
                continue
            seen.add((slot, iid))
            out.append((slot, iid, name))
            union.setdefault(iid, name)
        if out:
            bis[idx] = out
    return cls, specs, union, bis


def emit_class(cls, specs, union, bis, buf):
    buf.append(f'GearJourney_GearData[{lua_str(cls)}] = {{')
    for idx in (1, 2, 3):
        by_race = specs.get(idx, {})
        buf.append(f'  [{idx}] = {{')
        for token in sorted(by_race):
            items = by_race[token]
            inner = ", ".join(f'{{id={iid},name={lua_str(nm)}}}' for iid, nm in items)
            buf.append(f'    {token} = {{ {inner} }},')
        buf.append('  },')
    buf.append('}')
    # Flat deduped union for the enrichment queue (order: sorted by id for stable diffs).
    buf.append(f'GearJourney_ClassGuides[{lua_str(cls)}] = {{')
    for iid in sorted(union):
        buf.append(f'  {{id={iid},name={lua_str(union[iid])}}},')
    buf.append('}')
    # Optional handcrafted per-slot BiS (slot order preserved as authored).
    if bis:
        buf.append(f'GearJourney_BiS[{lua_str(cls)}] = {{')
        for idx in (1, 2, 3):
            rows = bis.get(idx)
            if not rows:
                continue
            inner = ", ".join(
                f'{{slot={lua_str(slot)},id={iid},name={lua_str(nm)}}}'
                for slot, iid, nm in rows)
            buf.append(f'  [{idx}] = {{ {inner} }},')
        buf.append('}')
    buf.append('')


def main():
    paths = sorted(p for p in glob.glob(SRC_GLOB) if not os.path.basename(p).startswith("_"))
    if not paths:
        die(f"no class JSON found under {SRC_GLOB}")

    buf = [
        "-- AUTO-GENERATED by Tools/build_gear_data.py -- DO NOT EDIT BY HAND.",
        "-- Source of truth: Design/gear/*.json (class x spec x race hardcoded gear).",
        "-- Regenerate: python Tools/build_gear_data.py",
        "",
        "GearJourney_GearData = GearJourney_GearData or {}",
        "GearJourney_ClassGuides = GearJourney_ClassGuides or {}",
        "GearJourney_BiS = GearJourney_BiS or {}",
        "",
    ]
    total_lists, total_ids = 0, 0
    for path in paths:
        cls, specs, union, bis = load_class(path)
        emit_class(cls, specs, union, bis, buf)
        total_lists += sum(len(r) for r in specs.values())
        total_ids += len(union)
        print(f"  {cls}: {sum(len(r) for r in specs.values())} race-lists, {len(union)} unique ids")

    with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(buf))
    print(f"Wrote {OUT}: {len(paths)} classes, {total_lists} race-lists, {total_ids} ids total.")


if __name__ == "__main__":
    main()
