-- FEAT-A1 -- item-data schema validation.
-- Run from project root: lua Tests/journey_engine_test.lua

local H = dofile("Tests/harness.lua")
local Engine = dofile("JourneyEngine.lua")

H.start("FEAT-A1 item-data schema")

-- A well-formed item passes validation.
local good = {
  slot = "Chest",
  name = "Greenweave Robe",
  reqLevel = 21,
  ilvl = 26,
  quality = "uncommon",
  sourceType = "Crafted",
  sourceLabel = "Tailoring",
  stats = { Intellect = 7, Spirit = 4, Stamina = 3 },
}
H.ok(Engine.ValidateItem(good), "well-formed item validates")

-- Missing required field fails.
local noName = { slot = "Chest", reqLevel = 21, quality = "uncommon",
                 sourceType = "Crafted", sourceLabel = "Tailoring" }
H.ok(not (Engine.ValidateItem(noName)), "item missing 'name' is rejected")

-- Wrong-typed reqLevel fails.
local badLevel = {
  slot = "Chest", name = "X", reqLevel = "twenty", quality = "uncommon",
  sourceType = "Crafted", sourceLabel = "Tailoring",
}
H.ok(not (Engine.ValidateItem(badLevel)), "non-numeric reqLevel is rejected")

-- Unknown sourceType fails (must be Crafted/Dungeon/Quest).
local badSource = {
  slot = "Chest", name = "X", reqLevel = 21, quality = "uncommon",
  sourceType = "Vendor", sourceLabel = "SomeGuy",
}
H.ok(not (Engine.ValidateItem(badSource)), "unknown sourceType is rejected")

-- Unknown quality fails.
local badQuality = {
  slot = "Chest", name = "X", reqLevel = 21, quality = "legendary?",
  sourceType = "Quest", sourceLabel = "Elwynn",
}
H.ok(not (Engine.ValidateItem(badQuality)), "unknown quality is rejected")

H.done()
