-- Curated Rogue guide data (EPIC-H / FEAT-H1) -- structural integrity guard.
-- The list itself is verified in-game (reqLevel/name resolve via GetItemInfo),
-- but the shape is checkable offline: as the curated pool grows across classes,
-- this catches a fat-fingered duplicate id, a malformed entry, or an out-of-era
-- id (200000+ = Season of Discovery / Anniversary-only) before it ships.
-- Run from project root:  lua Tests/journey_rogue_data_test.lua

local H = dofile("Tests/harness.lua")
local Rogue = dofile("JourneyRogueData.lua")

H.start("Rogue guide data integrity")

H.ok(type(Rogue) == "table" and #Rogue > 0, "Rogue list loads and is non-empty")

-- The file self-registers under the multi-class registry; the returned table
-- and the published one are the same object.
H.eq(GearJourney_ClassGuides and GearJourney_ClassGuides.ROGUE, Rogue,
     "published as GearJourney_ClassGuides.ROGUE")

-- Every entry: numeric id (1 <= id < 200000) + non-empty string name; no dupes.
local seen, dupes, bad = {}, 0, 0
for i = 1, #Rogue do
  local e = Rogue[i]
  local okId = type(e) == "table" and type(e.id) == "number"
               and e.id >= 1 and e.id < 200000
  local okName = type(e) == "table" and type(e.name) == "string" and e.name ~= ""
  if not (okId and okName) then bad = bad + 1 end
  if okId then
    if seen[e.id] then dupes = dupes + 1 else seen[e.id] = true end
  end
end
H.eq(bad, 0, "every entry has a valid id (1..199999) and a non-empty name")
H.eq(dupes, 0, "no duplicate item ids in the curated list")

H.done()
