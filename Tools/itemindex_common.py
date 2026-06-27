"""Shared helpers for the JourneyItemIndex builders (Classic + Retail).

The two builders read different upstream formats (nexus-devs JSON vs wago.tools
ItemSparse+Item CSV) and emit slightly different rows (Classic stores an icon
PATH inline; Retail a numeric icon fileID), so their input adapters and Lua
writers stay separate. What IS identical -- the quality maps, the junk-name
filter, the Lua string escaper, and the body-armor slot set -- lives here so a
change (e.g. a new junk pattern) happens once.

Used by Tools/build_item_index.py and Tools/build_item_index_retail.py.
"""
import re

# Quality maps. Classic's nexus dataset gives quality by NAME; wago's ItemSparse
# gives it by OverallQualityID. Same target vocabulary.
QUALITY_BY_NAME = {
    "Poor": "poor", "Common": "common", "Uncommon": "uncommon",
    "Rare": "rare", "Epic": "epic", "Legendary": "legendary",
    "Artifact": "legendary", "Heirloom": "rare",
}
QUALITY_BY_ID = {
    "0": "poor", "1": "common", "2": "uncommon", "3": "rare",
    "4": "epic", "5": "legendary", "6": "legendary", "7": "rare",
}

# Body slots that carry an armor material (drives class filtering via Engine.CanUse).
BODY_ARMOR_SLOTS = {"Head", "Shoulder", "Chest", "Wrist", "Hands", "Waist", "Legs", "Feet"}

# True placeholders/test rows -- keep real items like "Old Greatsword".
JUNK = re.compile(
    r"\[|\]|XXXX|^QR\b|^Monster\b|^OLD\b|\bTest\b|\bDEPRECATED\b|\bUNUSED\b|"
    r"\bPH\b|\bTBD\b|\bQA\b|\bDND\b|^PvP\b",
    re.I,
)


def lua_str(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')
