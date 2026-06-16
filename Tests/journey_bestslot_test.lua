-- Best-per-slot collapse -- BestPerSlot(items) keeps the highest-ilvl item in
-- each slot. Run from project root: lua Tests/journey_bestslot_test.lua

local H = dofile("Tests/harness.lua")
local Engine = dofile("JourneyEngine.lua")

H.start("BestPerSlot by item level")

local fixture = {
  { name = "Vest A",   slot = "Chest", ilvl = 20, reqLevel = 18, itemID = 1 },
  { name = "Vest B",   slot = "Chest", ilvl = 27, reqLevel = 20, itemID = 2 }, -- best chest
  { name = "Vest C",   slot = "Chest", ilvl = 25, reqLevel = 19, itemID = 3 },
  { name = "Cap X",    slot = "Head",  ilvl = 22, reqLevel = 17, itemID = 4 }, -- only head
  { name = "Blade P",  slot = "Main Hand", ilvl = 30, reqLevel = 24, itemID = 5 },
  { name = "Blade Q",  slot = "Main Hand", ilvl = 30, reqLevel = 22, itemID = 6 }, -- tie ilvl, lower req
}

local function names(list)
  local t = {}
  for i = 1, #list do t[i] = list[i].name end
  return table.concat(t, ",")
end

local best = Engine.BestPerSlot(fixture)

-- One row per slot (Chest, Head, Main Hand) and sorted by reqLevel.
H.eq(#best, 3, "one item per slot (3 slots)")
H.eq(names(best), "Cap X,Vest B,Blade P", "sorted by reqLevel; best-ilvl per slot")

-- Verify the winners explicitly.
local pick = {}
for _, it in ipairs(best) do pick[it.slot] = it.name end
H.eq(pick["Chest"], "Vest B", "Chest: highest ilvl (27) wins")
H.eq(pick["Head"], "Cap X", "Head: the only one")
H.eq(pick["Main Hand"], "Blade P", "Main Hand: ilvl tie broken by higher reqLevel")

-- Pure: input not mutated.
H.eq(#fixture, 6, "input list not mutated")

H.done()
