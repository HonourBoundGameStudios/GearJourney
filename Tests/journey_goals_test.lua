-- FEAT-A3 -- GetGoalsForLevel(items, level, range).
-- Run from project root: lua Tests/journey_goals_test.lua

local H = dofile("Tests/harness.lua")
local Engine = dofile("JourneyEngine.lua")

H.start("FEAT-A3 GetGoalsForLevel")

-- Deterministic fixture: GetGoalsForLevel only reads reqLevel, so rows are
-- minimal. Deliberately unsorted to prove the function sorts its output.
local fixture = {
  { name = "L24", reqLevel = 24 },
  { name = "L14", reqLevel = 14 },
  { name = "L30", reqLevel = 30 },
  { name = "L18", reqLevel = 18 },
  { name = "L28", reqLevel = 28 },
  { name = "L20", reqLevel = 20 },
  { name = "L17", reqLevel = 17 },
}

local function names(list)
  local t = {}
  for i = 1, #list do t[i] = list[i].name end
  return table.concat(t, ",")
end

-- Window [level, level+range] is inclusive at both ends, output sorted asc.
local got = Engine.GetGoalsForLevel(fixture, 18, 10)  -- [18 .. 28]
H.eq(names(got), "L18,L20,L24,L28", "filters to [level..level+range], sorted asc")

-- Lower bound inclusive: an item exactly at `level` is included.
local atLevel = Engine.GetGoalsForLevel(fixture, 20, 0)  -- [20 .. 20]
H.eq(names(atLevel), "L20", "lower/upper bound inclusive at range 0")

-- Nothing in range -> empty list.
local none = Engine.GetGoalsForLevel(fixture, 40, 5)
H.eq(#none, 0, "no items in window -> empty list")

-- Default range is 10 when omitted.
local def = Engine.GetGoalsForLevel(fixture, 18)  -- [18 .. 28]
H.eq(names(def), "L18,L20,L24,L28", "range defaults to 10")

-- Pure: the input table's order is not mutated.
H.eq(fixture[1].name, "L24", "does not mutate caller's input order")

H.done()
