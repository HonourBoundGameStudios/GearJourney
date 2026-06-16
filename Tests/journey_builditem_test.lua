-- FEAT-E2 -- pure item-enrichment mapping (BuildItem + helpers).
-- Run from project root: lua Tests/journey_builditem_test.lua

local H = dofile("Tests/harness.lua")
local Engine = dofile("JourneyEngine.lua")

H.start("FEAT-E2 item enrichment mapping")

-- Armor type from item class/subclass (4 = Armor; subclass 1..4 = Cloth..Plate).
H.eq(Engine.ArmorTypeFromClass(4, 1), "Cloth",   "armor subclass 1 -> Cloth")
H.eq(Engine.ArmorTypeFromClass(4, 2), "Leather", "armor subclass 2 -> Leather")
H.eq(Engine.ArmorTypeFromClass(4, 4), "Plate",   "armor subclass 4 -> Plate")
H.eq(Engine.ArmorTypeFromClass(4, 0), nil, "misc armor (neck/ring/cloak) is neutral")
H.eq(Engine.ArmorTypeFromClass(2, 7), nil, "weapons are neutral")

-- Quality id -> name.
H.eq(Engine.QUALITY_NAME[2], "uncommon", "quality 2 = uncommon")
H.eq(Engine.QUALITY_NAME[3], "rare", "quality 3 = rare")

-- Gear item builds with all fields mapped.
local raw  = { id = 1234, sourceType = "Dungeon", source = "The Deadmines" }
local info = { name = "Cool Vest", quality = 2, reqLevel = 18, ilvl = 23,
               equipLoc = "INVTYPE_CHEST", classID = 4, subClassID = 2, icon = "iconpath" }
local it = Engine.BuildItem(raw, info)
H.ok(it ~= nil, "gear item builds")
H.eq(it.slot, "Chest", "equipLoc -> slot")
H.eq(it.armorType, "Leather", "armorType from class/subclass")
H.eq(it.quality, "uncommon", "quality id -> string")
H.eq(it.reqLevel, 18, "reqLevel carried")
H.eq(it.itemID, 1234, "itemID carried")
H.eq(it.sourceType, "Dungeon", "sourceType carried")
H.eq(it.sourceLabel, "The Deadmines", "source label carried")
H.eq(it.icon, "iconpath", "icon carried")

-- Weapon maps to a slot but stays neutral (no armorType).
local wpn = Engine.BuildItem({ id = 5, sourceType = "Dungeon", source = "x" },
  { name = "Dagger", quality = 3, reqLevel = 20, equipLoc = "INVTYPE_WEAPON", classID = 2, subClassID = 15 })
H.eq(wpn.slot, "Main Hand", "weapon -> Main Hand slot")
H.eq(wpn.armorType, nil, "weapon armorType nil (neutral)")

-- Non-gear is filtered out (returns nil).
H.eq(Engine.BuildItem({ id = 1 }, { name = "Bread", equipLoc = "", classID = 0, subClassID = 5 }),
     nil, "non-equippable -> nil")
H.eq(Engine.BuildItem({ id = 2 }, { name = "Tabard", equipLoc = "INVTYPE_TABARD", classID = 4, subClassID = 0 }),
     nil, "tabard (not a listed slot) -> nil")

-- Not yet resolved (GetItemInfo returned no name) -> nil, try again later.
H.eq(Engine.BuildItem({ id = 3 }, { equipLoc = "INVTYPE_CHEST", classID = 4, subClassID = 1 }),
     nil, "no name yet -> nil")

H.done()
