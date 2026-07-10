-- Bug: "Usable by me" in the Browse search offered items whose required level
-- is far above the player's -- CanUse only checks class/armor/weapon proficiency,
-- not the item's own reqLevel. CanEquipNow layers the level gate on top so the
-- checkbox means "gear I can equip right now."
-- Run from project root: lua Tests/journey_equipnow_test.lua

local H = dofile("Tests/harness.lua")
local Engine = dofile("JourneyEngine.lua")

H.start("CanEquipNow -- usable AND at/below my level")

-- A bow a hunter is proficient with (itemClassID 2 / subClassID 2 = Bow).
local bow37 = { name = "Bow of Searing Arrows", itemClassID = 2, itemSubClassID = 2, reqLevel = 37 }
H.ok(Engine.CanUse(bow37, "HUNTER", 38), "sanity: CanUse ignores reqLevel (proficiency only)")

-- The level gate: equippable now only when reqLevel <= player level.
H.ok(Engine.CanEquipNow(bow37, "HUNTER", 38), "req 37 bow: equippable by a level-38 hunter")
H.ok(Engine.CanEquipNow(bow37, "HUNTER", 37), "req 37 bow: equippable exactly at level 37")
H.ok(not Engine.CanEquipNow(bow37, "HUNTER", 36), "req 37 bow: NOT equippable at level 36")

-- A high-level plate piece a warrior can eventually use but not yet.
local plate60 = { name = "Lionheart Helm", armorType = "Plate", reqLevel = 60 }
H.ok(not Engine.CanEquipNow(plate60, "WARRIOR", 38), "req 60 plate: NOT equippable at level 38")
H.ok(Engine.CanEquipNow(plate60, "WARRIOR", 60), "req 60 plate: equippable at level 60")

-- Class/proficiency still gates: a bow is not usable by a mage at any level.
H.ok(not Engine.CanEquipNow(bow37, "MAGE", 60), "bow never equippable by a mage (proficiency)")

-- Missing reqLevel is treated as 0 (no requirement) -> equippable if usable.
local noReq = { name = "Plain Ring", reqLevel = nil }
H.ok(Engine.CanEquipNow(noReq, "HUNTER", 1), "no reqLevel -> equippable")

H.done()
