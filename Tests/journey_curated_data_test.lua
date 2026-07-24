-- Curated per-class guide data (EPIC-H) -- structural integrity guard for all
-- hand-curated class files (Rogue + the FEAT-H2..H9 fan-out). Each file resolves
-- reqLevel/name in-game, but the shape is checkable offline: valid ids, non-empty
-- names, no duplicate id WITHIN a class, and in-era ids (< 200000; SoD is 200000+).
-- Run from project root:  lua Tests/journey_curated_data_test.lua

local H = dofile("Tests/harness.lua")

-- The hand-curated class files, each sets GearJourney_ClassGuides[CLASS].
local FILES = {
  ROGUE   = "JourneyRogueData.lua",
  WARRIOR = "JourneyWarriorData.lua",
  PALADIN = "JourneyPaladinData.lua",
  HUNTER  = "JourneyHunterData.lua",
  PRIEST  = "JourneyPriestData.lua",
  SHAMAN  = "JourneyShamanData.lua",
  MAGE    = "JourneyMageData.lua",
  WARLOCK = "JourneyWarlockData.lua",
  DRUID   = "JourneyDruidData.lua",
}

H.start("curated class guide data integrity")

for class, file in pairs(FILES) do
  local list = dofile(file)
  H.ok(type(list) == "table" and #list > 0, class .. ": " .. file .. " loads non-empty")
  H.eq(GearJourney_ClassGuides and GearJourney_ClassGuides[class], list,
       class .. ": published as GearJourney_ClassGuides." .. class)

  local seen, dupes, bad = {}, 0, 0
  for i = 1, #list do
    local e = list[i]
    local okId = type(e) == "table" and type(e.id) == "number"
                 and e.id >= 1 and e.id < 200000
    local okName = type(e) == "table" and type(e.name) == "string" and e.name ~= ""
    if not (okId and okName) then bad = bad + 1 end
    if okId then
      if seen[e.id] then dupes = dupes + 1 else seen[e.id] = true end
    end
  end
  H.eq(bad, 0, class .. ": every entry has a valid id (1..199999) + non-empty name")
  H.eq(dupes, 0, class .. ": no duplicate item ids within the class")
end

H.done()
