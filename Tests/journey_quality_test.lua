-- FEAT-G2 -- FilterByQuality(items, enabled).
-- Run from project root: lua Tests/journey_quality_test.lua

local H = dofile("Tests/harness.lua")
local Engine = dofile("JourneyEngine.lua")

H.start("FEAT-G2 rarity filter")

local items = {
  { name = "U", quality = "uncommon" },
  { name = "R", quality = "rare" },
  { name = "C", quality = "common" },
  { name = "E", quality = "epic" },
}
local function names(list)
  local t = {}
  for i = 1, #list do t[i] = list[i].name end
  return table.concat(t, ",")
end

H.eq(names(Engine.FilterByQuality(items, { uncommon = true, rare = true, epic = true })),
     "U,R,E", "keeps enabled qualities, drops common")
H.eq(#Engine.FilterByQuality(items, nil), 4, "nil allow-map -> all")
H.eq(#Engine.FilterByQuality(items, {}), 0, "empty allow-map -> none")
H.eq(names(items), "U,R,C,E", "input not mutated")

H.done()
