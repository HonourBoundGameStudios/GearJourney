-- FEAT-A4 -- SplitGoals(items, level, range) -> current, future.
-- Run from project root: lua Tests/journey_split_test.lua

local H = dofile("Tests/harness.lua")
local Engine = dofile("JourneyEngine.lua")

H.start("FEAT-A4 SplitGoals current/future")

local fixture = {
  { name = "L14", reqLevel = 14 },  -- out-leveled (below level)
  { name = "L17", reqLevel = 17 },  -- out-leveled
  { name = "L18", reqLevel = 18 },  -- current (lower bound)
  { name = "L20", reqLevel = 20 },  -- current
  { name = "L28", reqLevel = 28 },  -- current (upper bound)
  { name = "L30", reqLevel = 30 },  -- future
  { name = "L35", reqLevel = 35 },  -- future
}

local function names(list)
  local t = {}
  for i = 1, #list do t[i] = list[i].name end
  return table.concat(t, ",")
end

local current, future = Engine.SplitGoals(fixture, 18, 10)  -- window [18..28]

H.eq(names(current), "L18,L20,L28", "current = window [level..level+range], sorted")
H.eq(names(future), "L30,L35", "future = strictly above the window, sorted")

-- Out-leveled items (reqLevel < level) appear in neither bucket.
local all = names(current) .. "," .. names(future)
H.ok(not string.find(all, "L14") and not string.find(all, "L17"),
     "out-leveled items are excluded from both buckets")

-- Default range applies to the split too.
local c2, f2 = Engine.SplitGoals(fixture, 18)  -- range 10 -> [18..28]
H.eq(names(c2), "L18,L20,L28", "current honours default range")
H.eq(names(f2), "L30,L35", "future honours default range")

H.done()
