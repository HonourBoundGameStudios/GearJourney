-- Generated class guides (EPIC-H / FEAT-H2..H9) -- load + global-name guard.
-- The 8 non-rogue guides are emitted by Tools/build_class_guides.py. That
-- generator once drifted from the addon rename and wrote TitanJourney_ClassGuides,
-- which would break loading (the addon reads GearJourney_ClassGuides). This
-- pins the published global so a bad regeneration can't ship silently.
-- Run from project root:  lua Tests/journey_classguides_test.lua

local H = dofile("Tests/harness.lua")
dofile("JourneyClassGuides.lua")

H.start("generated class guides")

H.ok(_G.TitanJourney_ClassGuides == nil, "no stale TitanJourney_ClassGuides global")
H.ok(type(_G.GearJourney_ClassGuides) == "table", "GearJourney_ClassGuides published")

local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "PRIEST",
                  "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local G = _G.GearJourney_ClassGuides or {}
for _, cls in ipairs(CLASSES) do
  local list = G[cls]
  H.ok(type(list) == "table" and #list > 0, cls .. " guide present and non-empty")
end

H.done()
