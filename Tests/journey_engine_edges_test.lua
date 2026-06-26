-- Engine edge cases -- the branches the feature tests don't reach: schema
-- rejections, shield usability, deterministic tie-breaks, and StatParts.
-- Run from project root: lua Tests/journey_engine_edges_test.lua

local H = dofile("Tests/harness.lua")
local E = dofile("JourneyEngine.lua")

H.start("engine edge cases")

-- ValidateItem rejection branches ------------------------------------------
H.ok(not (E.ValidateItem("not a table")), "non-table item rejected")
H.ok(not (E.ValidateItem(42)), "number item rejected")
do
  local base = {
    slot = "Chest", name = "X", reqLevel = 10, quality = "common",
    sourceType = "Quest", sourceLabel = "Somewhere",
  }
  local function with(extra)
    local t = {}; for k, v in pairs(base) do t[k] = v end
    for k, v in pairs(extra) do t[k] = v end
    return t
  end
  H.ok(E.ValidateItem(base), "well-formed item validates")
  H.ok(not E.ValidateItem(with({ stats = "nope" })), "non-table stats rejected")
  H.ok(not E.ValidateItem(with({ stats = { Agility = "lots" } })), "non-number stat value rejected")
  H.ok(E.ValidateItem(with({ stats = { Agility = 5 } })), "numeric stats accepted")
end

-- CanUse: shield branch (item class 4, subclass 6) -------------------------
local shield = { itemClassID = 4, itemSubClassID = 6 }
H.ok(E.CanUse(shield, "WARRIOR", 20), "warrior can use a shield")
H.ok(E.CanUse(shield, "PALADIN", 20), "paladin can use a shield")
H.ok(E.CanUse(shield, "SHAMAN", 20), "shaman can use a shield")
H.ok(not E.CanUse(shield, "MAGE", 20), "mage cannot use a shield")
H.ok(not E.CanUse(shield, "ROGUE", 20), "rogue cannot use a shield")

-- betterByIlvl deepest tie-break: equal ilvl AND reqLevel -> lower itemID ----
do
  local items = {
    { slot = "Chest", name = "Hi", ilvl = 20, reqLevel = 18, quality = "rare", itemID = 5 },
    { slot = "Chest", name = "Lo", ilvl = 20, reqLevel = 18, quality = "rare", itemID = 3 },
  }
  local out = E.BestPerSlot(items)
  H.eq(#out, 1, "full ilvl/reqLevel tie collapses to one")
  H.eq(out[1].itemID, 3, "tie broken by lower itemID")
end

-- BestPerSlot output sort: equal reqLevel -> name order ---------------------
do
  local items = {
    { slot = "Chest", name = "Bravo", ilvl = 20, reqLevel = 20, quality = "rare" },
    { slot = "Head",  name = "Alpha", ilvl = 20, reqLevel = 20, quality = "rare" },
  }
  local out = E.BestPerSlot(items)
  H.eq(out[1].name, "Alpha", "equal reqLevel sorted by name (A before B)")
  H.eq(out[2].name, "Bravo", "second by name")
end

-- BestPerSlotScored output sort across slots (reqLevel asc, then name) ------
do
  local items = {
    { slot = "Legs",  name = "Cee",  ilvl = 30, reqLevel = 20, quality = "rare" },
    { slot = "Head",  name = "Aay",  ilvl = 30, reqLevel = 18, quality = "rare" },
    { slot = "Chest", name = "Bee",  ilvl = 30, reqLevel = 20, quality = "rare" },
  }
  local out = E.BestPerSlotScored(items, nil)   -- nil weights -> all score 0
  H.eq(#out, 3, "three slots kept")
  H.eq(out[1].name, "Aay", "lowest reqLevel first")
  H.eq(out[2].name, "Bee", "reqLevel tie -> name order (Bee)")
  H.eq(out[3].name, "Cee", "reqLevel tie -> name order (Cee)")
end

-- NextJourneyGoal: all out-leveled -> highest reqLevel, name tie-break ------
do
  local items = {
    { name = "Bee", reqLevel = 30 },
    { name = "Aay", reqLevel = 30 },  -- same reqLevel; lower name should win
    { name = "Low", reqLevel = 20 },
  }
  local goal = E.NextJourneyGoal(items, { "Bee", "Aay", "Low" }, 40)
  H.eq(goal.name, "Aay", "out-leveled fallback breaks ties by name")
end

-- StatParts: ordered {name,abbr,value}, raw + canonical keys merged ---------
do
  H.eq(#E.StatParts(nil), 0, "nil stats -> empty")
  H.eq(#E.StatParts({}), 0, "empty stats -> empty")
  local parts = E.StatParts({ ITEM_MOD_AGILITY_SHORT = 9, Stamina = 5, Spirit = 0 })
  H.eq(#parts, 2, "zero-valued stat dropped")
  H.eq(parts[1].name, "Agility", "fixed order: Agility first")
  H.eq(parts[1].abbr, "Agi", "abbreviation mapped")
  H.eq(parts[1].value, 9, "raw GetItemStats key normalised")
  H.eq(parts[2].name, "Stamina", "Stamina after Agility in fixed order")
  -- raw + canonical of the same stat sum together
  local merged = E.StatParts({ ITEM_MOD_AGILITY_SHORT = 4, Agility = 3 })
  H.eq(merged[1].value, 7, "raw + canonical Agility summed")
end

H.done()
