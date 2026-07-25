-- Compiled hardcoded gear data (class x spec x race) -- structural integrity
-- guard for JourneyGearData.lua (generated from Design/gear/*.json). The live
-- reqLevel/name resolve in-game, but the shape is checkable offline: valid ids,
-- non-empty names, in-era ids, no dupes within a race list, spec indices 1..3,
-- only race tokens that class can be, and a non-empty flat enrichment union.
-- Run from the project root:  lua Tests/journey_geardata_test.lua

local H = dofile("Tests/harness.lua")

dofile("JourneyGearData.lua")

-- Class -> the race TOKENS UnitRace returns (Undead -> Scourge), per Classic Era.
local VALID = {
  WARRIOR = { Human=1, Dwarf=1, NightElf=1, Gnome=1, Orc=1, Scourge=1, Tauren=1, Troll=1 },
  ROGUE   = { Human=1, Dwarf=1, NightElf=1, Gnome=1, Orc=1, Scourge=1, Troll=1 },
  HUNTER  = { Dwarf=1, NightElf=1, Orc=1, Tauren=1, Troll=1 },
  PRIEST  = { Human=1, Dwarf=1, NightElf=1, Scourge=1, Troll=1 },
  MAGE    = { Human=1, Gnome=1, Scourge=1, Troll=1 },
  WARLOCK = { Human=1, Gnome=1, Orc=1, Scourge=1 },
  SHAMAN  = { Orc=1, Tauren=1, Troll=1 },
  PALADIN = { Human=1, Dwarf=1 },
  DRUID   = { NightElf=1, Tauren=1 },
}

H.start("compiled gear data integrity")

H.ok(type(GearJourney_GearData) == "table", "GearJourney_GearData is published")

local function checkList(list, label)
  H.ok(type(list) == "table", label .. ": is a table")
  local seen, bad, dupes = {}, 0, 0
  for i = 1, #(list or {}) do
    local e = list[i]
    local okId = type(e) == "table" and type(e.id) == "number" and e.id >= 1 and e.id < 200000
    local okName = type(e) == "table" and type(e.name) == "string" and e.name ~= ""
    if not (okId and okName) then bad = bad + 1 end
    if okId then
      if seen[e.id] then dupes = dupes + 1 else seen[e.id] = true end
    end
  end
  H.eq(bad, 0, label .. ": every entry has valid id (1..199999) + non-empty name")
  H.eq(dupes, 0, label .. ": no duplicate id within the list")
end

for class, byClass in pairs(GearJourney_GearData or {}) do
  H.ok(VALID[class] ~= nil, class .. ": is a known class")
  for spec = 1, 3 do
    local byRace = byClass[spec]
    H.ok(type(byRace) == "table", class .. " spec " .. spec .. ": present")
    for race, list in pairs(byRace or {}) do
      H.ok(VALID[class] and VALID[class][race] == 1,
           class .. " spec " .. spec .. ": race token '" .. tostring(race) .. "' is valid for the class")
      checkList(list, class .. "/" .. spec .. "/" .. race)
    end
  end
  -- The flat enrichment union must exist and be non-empty for any class present.
  local union = GearJourney_ClassGuides and GearJourney_ClassGuides[class]
  H.ok(type(union) == "table" and #union > 0, class .. ": flat enrichment union non-empty")
  checkList(union, class .. " union")
end

H.done()
