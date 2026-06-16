-- Bug: items already owned (equipped / bags / bank) are still suggested.
-- FilterOwned + NextJourneyGoal must skip owned items (predicate injected so the
-- WoW inventory API stays out of the test). Run from the project root:
--   lua Tests/journey_owned_test.lua

local H = dofile("Tests/harness.lua")
local Engine = dofile("JourneyEngine.lua")

H.start("skip owned items")

local function names(list)
  local t = {}
  for i = 1, #list do t[i] = list[i].name end
  return table.concat(t, ",")
end

local items = {
  { itemID = 1, name = "A" },
  { itemID = 2, name = "B" },
  { itemID = 3, name = "C" },
}
local owned = { [2] = true }

H.eq(names(Engine.FilterOwned(items, function(id) return owned[id] end)), "A,C",
     "FilterOwned drops owned items")
H.eq(#Engine.FilterOwned(items, nil), 3, "nil predicate -> keep all")
H.eq(names(items), "A,B,C", "input not mutated")

-- NextJourneyGoal skips owned journey items and advances to the next.
local jitems = {
  { itemID = 10, name = "A", reqLevel = 18 },
  { itemID = 11, name = "B", reqLevel = 24 },
}
local journey = { "A", "B" }
H.eq(Engine.NextJourneyGoal(jitems, journey, 10).name, "A", "no predicate -> nearest A")
H.eq(Engine.NextJourneyGoal(jitems, journey, 10, function(id) return id == 10 end).name, "B",
     "A owned -> advance to B")

H.done()
