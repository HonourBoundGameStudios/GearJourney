-- FEAT-A6 -- GetNextGoal(items, level, range, pinned).
-- Run from project root: lua Tests/journey_nextgoal_test.lua

local H = dofile("Tests/harness.lua")
local Engine = dofile("JourneyEngine.lua")

H.start("FEAT-A6 GetNextGoal")

-- Unsorted on purpose; window [18..28] for level 18, range 10.
local fixture = {
  { name = "Alpha",   reqLevel = 20 },
  { name = "Charlie", reqLevel = 18 },  -- ties Bravo at 18
  { name = "Bravo",   reqLevel = 18 },  -- tie-break by name -> wins
  { name = "Delta",   reqLevel = 24 },
  { name = "Below",   reqLevel = 15 },  -- out-leveled, never chosen
  { name = "Above",   reqLevel = 30 },  -- beyond window, never chosen
}

-- Lowest reqLevel in window; ties resolved by name ascending -> deterministic.
H.eq(Engine.GetNextGoal(fixture, 18, 10).name, "Bravo",
     "picks lowest-reqLevel goal in window (name tie-break)")

-- Out-of-window items are never the next goal.
local g = Engine.GetNextGoal(fixture, 18, 10)
H.ok(g.name ~= "Below" and g.name ~= "Above", "ignores items outside the window")

-- Pinned items are skipped; the next-lowest unpinned goal is returned.
H.eq(Engine.GetNextGoal(fixture, 18, 10, { Bravo = true }).name, "Charlie",
     "skips a pinned goal -> next unpinned at same level")
H.eq(Engine.GetNextGoal(fixture, 18, 10, { Bravo = true, Charlie = true }).name, "Alpha",
     "skips multiple pinned goals")

-- No goals in window -> nil.
H.eq(Engine.GetNextGoal(fixture, 40, 5), nil, "no goal in window -> nil")

-- All in-window goals pinned -> nil.
H.eq(Engine.GetNextGoal(fixture, 18, 10, { Alpha = true, Bravo = true, Charlie = true, Delta = true }),
     nil, "all in-window goals pinned -> nil")

H.done()
