-- JourneyPaladinData -- curated Paladin leveling gear guide (EPIC-H / FEAT-H2..H9).
--
-- Hand-picked {id, name} pairs, each verified against Wowhead Classic so the
-- provider's Engine.NameMatches guard drops any id that resolves to a different
-- item. Quality/reqLevel/slot/stats/icon resolve at runtime; the overlay buckets
-- by reqLevel, drops non-usable items via Engine.CanUse, and score-filters by the
-- player's spec (Str-focused Ret, with Holy/Prot options). Mail then plate; sword/
-- axe/mace + shields. IDs in the 200000+ range (SoD/Anniversary-only) are omitted
-- for Classic Era. Overrides the auto-generated PALADIN guide (loads after
-- JourneyClassGuides.lua).
local Paladin = {
  -- Band 1-10 -----------------------------------------------------------------
  { id = 2899,  name = "Wendigo Collar" },
  { id = 3314,  name = "Ceremonial Leather Gloves" },

  -- Band 11-20 ----------------------------------------------------------------
  { id = 2041,  name = "Tunic of Westfall" },
  { id = 6953,  name = "Verigan's Fist" },

  -- Band 21-30 ----------------------------------------------------------------
  { id = 3484,  name = "Green Iron Boots" },
  { id = 6087,  name = "Chausses of Westfall" },
  { id = 3485,  name = "Green Iron Gauntlets" },
  { id = 7913,  name = "Barbaric Iron Shoulders" },
  { id = 7914,  name = "Barbaric Iron Breastplate" },
  { id = 6687,  name = "Corpsemaker" },
  { id = 7915,  name = "Barbaric Iron Helm" },

  -- Band 31-40 ----------------------------------------------------------------
  { id = 3844,  name = "Green Iron Hauberk" },
  { id = 7916,  name = "Barbaric Iron Boots" },
  { id = 7718,  name = "Herod's Shoulder" },
  { id = 7717,  name = "Ravager" },
  { id = 7726,  name = "Aegis of the Scarlet Commander" },
  { id = 6829,  name = "Sword of Serenity" },        -- Holy: 1H sword, Spirit

  -- Band 41-50 ----------------------------------------------------------------
  { id = 7927,  name = "Ornate Mithril Gloves" },
  { id = 7926,  name = "Ornate Mithril Pants" },
  { id = 7935,  name = "Ornate Mithril Breastplate" },
  { id = 7937,  name = "Ornate Mithril Helm" },
  { id = 12424, name = "Imperial Plate Belt" },
  { id = 12428, name = "Imperial Plate Shoulders" },
  { id = 12425, name = "Imperial Plate Bracers" },
  { id = 1203,  name = "Aegis of Stormwind" },
  { id = 810,   name = "Hammer of the Northern Wind" },

  -- Band 51-59 ----------------------------------------------------------------
  { id = 2244,  name = "Krol Blade" },
  { id = 11923, name = "The Hammer of Grace" },
  { id = 2246,  name = "Myrmidon's Signet" },
  { id = 11815, name = "Hand of Justice" },
  { id = 11669, name = "Naglering" },
  { id = 12414, name = "Imperial Plate Helm" },
  { id = 12426, name = "Imperial Plate Boots" },
  { id = 14576, name = "Ebon Hilt of Marduk" },
  { id = 11684, name = "Ironfoe" },
  { id = 14554, name = "Cloudkeeper Legplates" },
  { id = 13340, name = "Cape of the Black Baron" },
  { id = 12784, name = "Arcanite Reaper" },
  { id = 12940, name = "Dal'Rend's Sacred Charge" },

  -- Level 60 (pre-raid) -------------------------------------------------------
  { id = 15411, name = "Mark of Fordring" },
  { id = 19325, name = "Don Julio's Band" },
  { id = 13965, name = "Blackhand's Breadth" },
  { id = 17105, name = "Aurastone Hammer" },         -- Holy: 1H mace, Int + spell power / heal
  -- (The Hammer of Grace, id 11923 above, is the band 51-59 Holy weapon: +31 healing.)
}

-- Multi-class-ready registry; overrides the generated PALADIN entry.
GearJourney_ClassGuides = GearJourney_ClassGuides or {}
GearJourney_ClassGuides.PALADIN = Paladin
return Paladin
