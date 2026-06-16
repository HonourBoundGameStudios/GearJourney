-- FEAT-A7 -- ProximityLabel(reqLevel, playerLevel).
-- Run from project root: lua Tests/journey_proximity_test.lua

local H = dofile("Tests/harness.lua")
local Engine = dofile("JourneyEngine.lua")

H.start("FEAT-A7 ProximityLabel")

-- At or below the player's level -> already available.
H.eq(Engine.ProximityLabel(20, 20), "Available now", "equal level -> Available now")
H.eq(Engine.ProximityLabel(14, 18), "Available now", "below level -> Available now")

-- One level away is singular.
H.eq(Engine.ProximityLabel(19, 18), "In 1 Level", "one level away -> singular")

-- More than one level away is plural.
H.eq(Engine.ProximityLabel(24, 18), "In 6 Levels", "several levels away -> plural")
H.eq(Engine.ProximityLabel(20, 18), "In 2 Levels", "two levels away -> plural")

H.done()
