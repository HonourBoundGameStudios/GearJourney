-- FEAT-F2 -- Journey List: NextJourneyGoal (engine) + DB list ops.
-- Run from project root: lua Tests/journey_journey_test.lua

local H = dofile("Tests/harness.lua")
local Engine = dofile("JourneyEngine.lua")

H.start("FEAT-F2 Journey List")

-- NextJourneyGoal: among the player's journey items, the next one to reach
-- (lowest reqLevel at-or-above the player's level); else the highest available.
local items = {
  { name = "A", reqLevel = 18 },
  { name = "B", reqLevel = 24 },
  { name = "C", reqLevel = 30 },
  { name = "Z", reqLevel = 22 },  -- not on the journey list
}
local journey = { "A", "B", "C" }

H.eq(Engine.NextJourneyGoal(items, journey, 10).name, "A", "level 10 -> nearest upcoming A(18)")
H.eq(Engine.NextJourneyGoal(items, journey, 20).name, "B", "level 20 -> next upcoming B(24)")
H.eq(Engine.NextJourneyGoal(items, journey, 24).name, "B", "at-level counts as upcoming")
H.eq(Engine.NextJourneyGoal(items, journey, 32).name, "C", "all outleveled -> highest C(30)")
H.eq(Engine.NextJourneyGoal(items, {}, 20), nil, "empty journey -> nil")
H.eq(Engine.NextJourneyGoal(items, { "X" }, 20), nil, "journey name not present -> nil")

-- DB list operations (pure table ops over TitanJourneyDB).
dofile("JourneyDB.lua")
local DB = TitanJourney_DB
TitanJourneyDB = nil
DB.Init()

H.eq(#DB.Journey(), 0, "journey starts empty")
DB.JourneyAdd("A"); DB.JourneyAdd("B"); DB.JourneyAdd("A")
H.eq(#DB.Journey(), 2, "JourneyAdd dedupes")
H.ok(DB.JourneyContains("A"), "JourneyContains true for added")
H.eq(DB.JourneyToggle("A"), false, "toggle removes existing (returns false)")
H.ok(not DB.JourneyContains("A"), "A removed by toggle")
H.eq(DB.JourneyToggle("C"), true, "toggle adds new (returns true)")
H.ok(DB.JourneyContains("C"), "C added by toggle")
DB.JourneyRemove("C")
H.ok(not DB.JourneyContains("C"), "JourneyRemove works")

H.done()
