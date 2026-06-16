-- Bug: AtlasLoot rows with a typo'd itemID resolve to the wrong item. The addon
-- validates the real name against the comment name. Run from project root:
--   lua Tests/journey_name_test.lua

local H = dofile("Tests/harness.lua")
local Engine = dofile("JourneyEngine.lua")

H.start("itemID name validation")

H.ok(Engine.NameMatches("Fine Leather Gloves", "Fine Leather Gloves"), "exact match")
H.ok(Engine.NameMatches("Smite's Mighty Hammer", "Smites Mighty Hammer"),
     "punctuation/spacing insensitive")
H.ok(not Engine.NameMatches("Shadowblade", "White Leather Jerkin"),
     "typo'd id (real != expected) -> mismatch")
H.ok(not Engine.NameMatches("Tracker's Gloves", "Solid Grinding Stone"), "another typo mismatch")
H.ok(Engine.NameMatches("Anything", nil), "no expected name -> accept")
H.ok(Engine.NameMatches(nil, "Anything"), "no real name -> accept")

H.done()
