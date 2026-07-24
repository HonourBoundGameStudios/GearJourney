-- FEAT-B1 -- BuildButtonText(items, level, range, pinned) -> label, value.
-- The pure formatting behind the Titan button text. Run from project root:
--   lua Tests/journey_button_test.lua

local H = dofile("Tests/harness.lua")
local Engine = dofile("JourneyEngine.lua")

H.start("FEAT-B1 BuildButtonText")

local fixture = {
  { name = "Gloves of the Fang", reqLevel = 18 },
  { name = "Robes of Arugal",    reqLevel = 20 },
  { name = "Assassin's Blade",   reqLevel = 24 },
}

-- Label is constant; value is "<name> (Lv. <req>) - <proximity>" (FEAT-B2).
local label, value = Engine.BuildButtonText(fixture, 14, 10)  -- window [14..24], lowest = L18
H.eq(label, "Next Goal:", "label is 'Next Goal:'")
H.eq(value, "Gloves of the Fang (Lv. 18) - In 4 Levels",
     "value names the next goal with level and proximity")

-- A pinned item is shown directly (even if outside the lookahead window).
local _, v2 = Engine.BuildButtonText(fixture, 14, 10, "Assassin's Blade")
H.eq(v2, "Assassin's Blade (Lv. 24) - In 10 Levels", "pinned item is shown")

-- A pin that isn't in the list falls back to the default next goal.
local _, v2b = Engine.BuildButtonText(fixture, 14, 10, "Nonexistent Item")
H.eq(v2b, "Gloves of the Fang (Lv. 18) - In 4 Levels", "unknown pin falls back to next goal")

-- Once the item is reachable the "Available now" suffix adds nothing, so the
-- value is just "<name> (Lv. <req>)" with no proximity tail.
local _, v2c = Engine.BuildButtonText(fixture, 20, 10, "Gloves of the Fang")
H.eq(v2c, "Gloves of the Fang (Lv. 18)", "reachable goal drops the proximity suffix")

-- No goal in range -> a clear placeholder, not an error.
local _, v3 = Engine.BuildButtonText(fixture, 40, 5)
H.eq(v3, "None in range", "no goal in window -> 'None in range'")

H.done()
