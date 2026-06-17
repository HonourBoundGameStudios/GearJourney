-- Bug: unwearable items offered. FilterByClass must also respect weapon
-- proficiency and armor level requirements (mail/plate unlock at 40).
-- Run from project root: lua Tests/journey_usable_test.lua

local H = dofile("Tests/harness.lua")
local Engine = dofile("JourneyEngine.lua")

H.start("usable-only filtering")

local function names(list)
  local t = {}
  for i = 1, #list do t[i] = list[i].name end
  return table.concat(t, ",")
end

-- Weapon proficiency (itemClassID 2; subclass: 10=Staff, 15=Dagger, 19=Wand,
-- 8=2H Sword, 0=1H Axe, 7=1H Sword).
local weapons = {
  { name = "Staff",  itemClassID = 2, itemSubClassID = 10 },
  { name = "Dagger", itemClassID = 2, itemSubClassID = 15 },
  { name = "Wand",   itemClassID = 2, itemSubClassID = 19 },
  { name = "2HSword",itemClassID = 2, itemSubClassID = 8 },
}
H.eq(names(Engine.FilterByClass(weapons, "ROGUE", 30)), "Dagger",
     "rogue keeps dagger; drops staff/wand/2H")
H.eq(names(Engine.FilterByClass(weapons, "MAGE", 30)), "Staff,Dagger,Wand",
     "mage keeps staff/dagger/wand; drops 2H sword")
H.eq(names(Engine.FilterByClass(weapons, "WARRIOR", 30)), "Staff,Dagger,2HSword",
     "warrior keeps melee + staff; drops wand")

-- Rogues use 1H mace/sword/fist/dagger + ranged, but NOT axes, polearms,
-- staves, or 2H weapons (regression: 1H axe was wrongly allowed).
local rogueWeapons = {
  { name = "Axe1H",   itemClassID = 2, itemSubClassID = 0 },
  { name = "Mace1H",  itemClassID = 2, itemSubClassID = 4 },
  { name = "Sword1H", itemClassID = 2, itemSubClassID = 7 },
  { name = "Fist",    itemClassID = 2, itemSubClassID = 13 },
  { name = "Dagger2", itemClassID = 2, itemSubClassID = 15 },
  { name = "Polearm", itemClassID = 2, itemSubClassID = 6 },
}
H.eq(names(Engine.FilterByClass(rogueWeapons, "ROGUE", 30)), "Mace1H,Sword1H,Fist,Dagger2",
     "rogue drops axes/polearms; keeps 1H mace/sword/fist/dagger")

-- Armor level gates: plate (warrior/paladin) and mail (hunter/shaman) at 40.
local plate  = { { name = "Plate", armorType = "Plate" } }
H.eq(#Engine.FilterByClass(plate, "WARRIOR", 25), 0, "no plate for a level-25 warrior")
H.eq(#Engine.FilterByClass(plate, "WARRIOR", 45), 1, "plate ok for a level-45 warrior")

local mail = { { name = "Mail", armorType = "Mail" } }
H.eq(#Engine.FilterByClass(mail, "HUNTER", 25), 0, "no mail for a level-25 hunter")
H.eq(#Engine.FilterByClass(mail, "HUNTER", 45), 1, "mail ok for a level-45 hunter")
H.eq(#Engine.FilterByClass(mail, "WARRIOR", 25), 1, "warrior wears mail at any level")

-- Existing preference behaviour still holds (armorType-only items, no level).
local armor = {
  { name = "ClothRobe", armorType = "Cloth" },
  { name = "LeatherGlv", armorType = "Leather" },
  { name = "Amulet", armorType = "Neck" },  -- non-armor -> neutral
  { name = "Ring" },                         -- neutral
}
H.eq(names(Engine.FilterByClass(armor, "ROGUE")), "LeatherGlv,Amulet,Ring",
     "rogue still keeps leather + neutral, drops cloth")

-- Hard class restriction ("Classes: Shaman" mail must not reach a Paladin).
local nameToToken = { Paladin = "PALADIN", Warrior = "WARRIOR", Shaman = "SHAMAN" }
H.ok(Engine.ClassSetFromNames("Shaman", nameToToken).SHAMAN, "parses single class")
H.ok(Engine.ClassSetFromNames("Paladin, Warrior", nameToToken).WARRIOR, "parses class list")
H.eq(Engine.ClassSetFromNames("", nameToToken), nil, "empty -> nil")

local shamanMail = { name = "Totem Mail", armorType = "Mail", classes = { SHAMAN = true } }
H.ok(not Engine.CanUse(shamanMail, "PALADIN", 45), "Shaman-only mail not usable by a Paladin")
H.ok(Engine.CanUse(shamanMail, "SHAMAN", 45), "Shaman-only mail usable by a Shaman")
H.ok(Engine.CanUse({ name = "Plain Mail", armorType = "Mail" }, "PALADIN", 45),
     "unrestricted mail still usable by a Paladin")

H.done()
