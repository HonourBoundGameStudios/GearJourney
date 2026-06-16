-- JourneyData -- starter item database for the Journey wishlist (FEAT-A2).
--
-- Pure data: an array of item rows matching the JourneyEngine schema (FEAT-A1).
-- No engine or WoW dependency, so it loads under standalone Lua for tests and
-- under the client via the .toc.
--
-- This is a *representative* seed spanning the early leveling band (~14-24),
-- with at least one Crafted / Dungeon / Quest entry. Names/levels should be
-- verified against game data when the real DB is curated (HEALTH-3).

-- `armorType` (Cloth/Leather/Mail/Plate) drives class filtering; weapons and
-- jewelry omit it (neutral -- shown to every class). See Engine.FilterByClass.
local Items = {
  -- Crafted -----------------------------------------------------------------
  {
    slot = "Chest", name = "Greenweave Robe", reqLevel = 21, ilvl = 26,
    quality = "uncommon", sourceType = "Crafted", sourceLabel = "Tailoring",
    armorType = "Cloth", stats = { Intellect = 7, Spirit = 4, Stamina = 3 },
  },
  {
    slot = "Chest", name = "Silvered Bronze Breastplate", reqLevel = 22, ilvl = 27,
    quality = "uncommon", sourceType = "Crafted", sourceLabel = "Blacksmithing",
    armorType = "Mail", stats = { Stamina = 6, Strength = 3 },
  },
  {
    slot = "Feet", name = "Spider Silk Slippers", reqLevel = 24, ilvl = 29,
    quality = "uncommon", sourceType = "Crafted", sourceLabel = "Tailoring",
    armorType = "Cloth", stats = { Stamina = 5, Spirit = 4 },
  },

  -- Dungeon -----------------------------------------------------------------
  {
    slot = "Hands", name = "Gloves of the Fang", reqLevel = 18, ilvl = 23,
    quality = "uncommon", sourceType = "Dungeon", sourceLabel = "Wailing Caverns",
    armorType = "Leather", stats = { Agility = 9, Stamina = 5 },
  },
  {
    slot = "Chest", name = "Robes of Arugal", reqLevel = 20, ilvl = 25,
    quality = "rare", sourceType = "Dungeon", sourceLabel = "Shadowfang Keep",
    armorType = "Cloth", stats = { Intellect = 9, Stamina = 5, Spirit = 4 },
  },
  {
    slot = "MainHand", name = "Assassin's Blade", reqLevel = 24, ilvl = 29,
    quality = "rare", sourceType = "Dungeon", sourceLabel = "Shadowfang Keep",
    stats = { Agility = 6, Stamina = 4 },  -- weapon: neutral
  },

  -- Quest -------------------------------------------------------------------
  {
    slot = "Head", name = "Tarnished Elven Circlet", reqLevel = 17, ilvl = 22,
    quality = "rare", sourceType = "Quest", sourceLabel = "Redridge Mountains",
    armorType = "Cloth", stats = { Intellect = 5, Stamina = 3, Spirit = 2 },
  },
  {
    slot = "Feet", name = "Tree Bark Sandals", reqLevel = 23, ilvl = 28,
    quality = "uncommon", sourceType = "Quest", sourceLabel = "Duskwood",
    armorType = "Leather", stats = { Spirit = 6, Stamina = 3 },
  },
  {
    slot = "Ranged", name = "Verdant Keeper's Aim", reqLevel = 24, ilvl = 29,
    quality = "rare", sourceType = "Quest", sourceLabel = "Ashenvale",
    stats = { Agility = 7, Stamina = 4 },  -- bow: neutral
  },
}

-- Publish for the WoW client (global by contract); return for standalone use.
TitanJourney_Items = Items
return Items
