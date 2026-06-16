-- Class-aware filtering -- FilterByClass(items, class).
-- Run from project root: lua Tests/journey_class_test.lua

local H = dofile("Tests/harness.lua")
local Engine = dofile("JourneyEngine.lua")

H.start("FilterByClass armor-type preference")

-- armorType nil = neutral (weapons/jewelry), kept for every class.
local fixture = {
  { name = "ClothRobe",  armorType = "Cloth" },
  { name = "LeatherGlv", armorType = "Leather" },
  { name = "MailVest",   armorType = "Mail" },
  { name = "PlateLegs",  armorType = "Plate" },
  { name = "Dagger" },                              -- neutral (no armorType)
  { name = "Amulet",     armorType = "Neck" },      -- non-armor slot -> neutral
}

local function names(list)
  local t = {}
  for i = 1, #list do t[i] = list[i].name end
  return table.concat(t, ",")
end

-- Rogue wears Leather; keeps leather + neutral, drops other armor.
H.eq(names(Engine.FilterByClass(fixture, "ROGUE")),
     "LeatherGlv,Dagger,Amulet", "ROGUE keeps Leather + neutral")

-- Mage wears Cloth.
H.eq(names(Engine.FilterByClass(fixture, "MAGE")),
     "ClothRobe,Dagger,Amulet", "MAGE keeps Cloth + neutral")

-- Warrior wears Mail and Plate while leveling.
H.eq(names(Engine.FilterByClass(fixture, "WARRIOR")),
     "MailVest,PlateLegs,Dagger,Amulet", "WARRIOR keeps Mail+Plate + neutral")

-- Unknown / nil class -> no filtering (pass-through), order preserved.
H.eq(names(Engine.FilterByClass(fixture, nil)),
     "ClothRobe,LeatherGlv,MailVest,PlateLegs,Dagger,Amulet", "nil class passes all")
H.eq(names(Engine.FilterByClass(fixture, "TINKER")),
     "ClothRobe,LeatherGlv,MailVest,PlateLegs,Dagger,Amulet", "unknown class passes all")

-- Pure: input not mutated.
H.eq(names(fixture), "ClothRobe,LeatherGlv,MailVest,PlateLegs,Dagger,Amulet",
     "does not mutate caller's input")

H.done()
