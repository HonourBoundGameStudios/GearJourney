-- JourneyWarriorData -- curated Warrior leveling gear guide (EPIC-H / FEAT-H2..H9).
--
-- Hand-picked {id, name} pairs, each verified against Wowhead Classic so the
-- provider's Engine.NameMatches guard drops any id that resolves to a different
-- item. Quality/reqLevel/slot/stats/icon resolve at runtime; the overlay buckets
-- by reqLevel, drops non-usable items via Engine.CanUse, and score-filters by the
-- player's spec. Leather/mail early, plate later; every weapon type incl. 2H, plus
-- shields. IDs in the 200000+ range (SoD/Anniversary-only) are omitted for Classic
-- Era. Overrides the auto-generated WARRIOR guide (loads after JourneyClassGuides).
local Warrior = {
  -- Band 1-10 -----------------------------------------------------------------
  { id = 2300,  name = "Embossed Leather Vest" },
  { id = 3314,  name = "Ceremonial Leather Gloves" },
  { id = 2899,  name = "Wendigo Collar" },

  -- Band 11-20 ----------------------------------------------------------------
  { id = 10413, name = "Gloves of the Fang" },
  { id = 1482,  name = "Shadowfang" },
  { id = 5191,  name = "Cruel Barb" },
  { id = 1121,  name = "Feet of the Lynx" },
  { id = 5193,  name = "Cape of the Brotherhood" },

  -- Band 21-30 ----------------------------------------------------------------
  { id = 18948, name = "Barbaric Bracers" },
  { id = 3836,  name = "Green Iron Helm" },
  { id = 9449,  name = "Manual Crowd Pummeler" },

  -- Band 31-40 ----------------------------------------------------------------
  { id = 10328, name = "Scarlet Chestpiece" },
  { id = 1404,  name = "Tidal Charm" },
  { id = 7718,  name = "Herod's Shoulder" },
  { id = 7717,  name = "Ravager" },
  { id = 10330, name = "Scarlet Leggings" },
  { id = 9425,  name = "Pendulum of Doom" },
  { id = 2164,  name = "Gut Ripper" },
  { id = 6975,  name = "Whirlwind Axe" },

  -- Band 41-50 ----------------------------------------------------------------
  { id = 9639,  name = "The Hand of Antu'sul" },
  { id = 809,   name = "Bloodrazor" },
  { id = 13253, name = "Vinehedge Cinch" },
  { id = 14849, name = "Sunscale Helmet" },
  { id = 17728, name = "Albino Crocscale Boots" },

  -- Band 51-59 ----------------------------------------------------------------
  { id = 2244,  name = "Krol Blade" },
  { id = 15063, name = "Devilsaur Gauntlets" },
  { id = 11815, name = "Hand of Justice" },
  { id = 1168,  name = "Skullflame Shield" },
  { id = 11669, name = "Naglering" },
  { id = 11684, name = "Ironfoe" },
  { id = 15062, name = "Devilsaur Leggings" },
  { id = 12784, name = "Arcanite Reaper" },
  { id = 18520, name = "Barbarous Blade" },
  { id = 12940, name = "Dal'Rend's Sacred Charge" },
  { id = 12939, name = "Dal'Rend's Tribal Guardian" },
  { id = 13340, name = "Cape of the Black Baron" },
  { id = 18404, name = "Onyxia Tooth Pendant" },

  -- Level 60 (pre-raid) -------------------------------------------------------
  { id = 18832, name = "Brutality Blade" },
  { id = 13959, name = "Omokk's Girth Restrainer" },
  { id = 19578, name = "Berserker Bracers" },
  { id = 19325, name = "Don Julio's Band" },
  { id = 13965, name = "Blackhand's Breadth" },
  { id = 15411, name = "Mark of Fordring" },
  { id = 17774, name = "Mark of the Chosen" },
}

-- Multi-class-ready registry; overrides the generated WARRIOR entry.
GearJourney_ClassGuides = GearJourney_ClassGuides or {}
GearJourney_ClassGuides.WARRIOR = Warrior
return Warrior
