#!/usr/bin/env python3
"""One-time backfill: some AtlasLoot rows were harvested with an empty `source`
(notably Scarlet Monastery), so the UI showed the generic word "Dungeon". Fill
the instance name from the nexus dataset's zone id. Idempotent -- only touches
rows whose source is still "". Run from the project root:

    python Tools/backfill_atlas_sources.py
"""
import json, re

ATLAS = "JourneyAtlasData.lua"
RAW = "Tools/_items_raw.json"

ZONE_NAME = {
    796: "Scarlet Monastery", 2557: "Dire Maul", 1584: "Blackrock Depths",
    2057: "Scholomance", 721: "Gnomeregan", 2017: "Stratholme",
}


def main():
    raw = json.load(open(RAW, encoding="utf-8"))
    zone_by_id = {it["itemId"]: (it.get("source") or {}).get("zone") for it in raw}
    text = open(ATLAS, encoding="utf-8").read()

    pat = re.compile(r'(\{ id = (\d+), sourceType = "Dungeon", source = )""')
    filled = [0]

    def repl(m):
        iid = int(m.group(2))
        name = ZONE_NAME.get(zone_by_id.get(iid))
        if not name:
            return m.group(0)
        filled[0] += 1
        return m.group(1) + '"' + name + '"'

    text = pat.sub(repl, text)
    open(ATLAS, "w", encoding="utf-8", newline="\n").write(text)
    print("backfilled", filled[0], "dungeon sources")


if __name__ == "__main__":
    main()
