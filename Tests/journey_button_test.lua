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

-- Pinning the lowest goal advances to the next one.
local _, v2 = Engine.BuildButtonText(fixture, 14, 10, { ["Gloves of the Fang"] = true })
H.eq(v2, "Robes of Arugal (Lv. 20) - In 6 Levels", "pinned next-goal is skipped")

-- No goal in range -> a clear placeholder, not an error.
local _, v3 = Engine.BuildButtonText(fixture, 40, 5)
H.eq(v3, "None in range", "no goal in window -> 'None in range'")

H.done()
