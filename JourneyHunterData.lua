-- JourneyHunterData -- curated Hunter leveling gear guide (EPIC-H / FEAT-H2..H9).
--
-- Hand-picked {id, name} pairs, each verified against Wowhead Classic so the
-- provider's Engine.NameMatches guard drops any id that resolves to a different
-- item. Quality/reqLevel/slot/stats/icon resolve at runtime; the overlay buckets
-- by reqLevel, drops non-usable items via Engine.CanUse, and score-filters by the
-- player's spec (Agi-focused). Leather then mail, a ranged weapon most bands, plus
-- melee variety. IDs in the 200000+ range (SoD/Anniversary-only) are omitted for
-- Classic Era. Overrides the auto-generated HUNTER guide (loads after
-- JourneyClassGuides.lua).
local Hunter = {
  -- Band 1-10 -----------------------------------------------------------------
  { id = 5596,  name = "Ashwood Bow" },

  -- Band 11-20 ----------------------------------------------------------------
  { id = 15808, name = "Fine Light Crossbow" },
  { id = 3027,  name = "Heavy Recurve Bow" },
  { id = 10413, name = "Gloves of the Fang" },
  { id = 6467,  name = "Deviate Scale Gloves" },
  { id = 10410, name = "Leggings of the Fang" },
  { id = 6468,  name = "Deviate Scale Belt" },
  { id = 1121,  name = "Feet of the Lynx" },

  -- Band 21-30 ----------------------------------------------------------------
  { id = 4454,  name = "Talon of Vultros" },
  { id = 4108,  name = "Panther Hunter Leggings" },

  -- Band 31-40 ----------------------------------------------------------------
  { id = 13110, name = "Wolffear Harness" },
  { id = 8176,  name = "Nightscape Headband" },
  { id = 8175,  name = "Nightscape Tunic" },
  { id = 7718,  name = "Herod's Shoulder" },
  { id = 2825,  name = "Bow of Searing Arrows" },
  { id = 7717,  name = "Ravager" },

  -- Band 41-50 ----------------------------------------------------------------
  { id = 2100,  name = "Precisely Calibrated Boomstick" },
  { id = 2824,  name = "Hurricane" },
  { id = 17713, name = "Blackstone Ring" },

  -- Band 51-59 ----------------------------------------------------------------
  { id = 16681, name = "Beaststalker's Bindings" },
  { id = 16680, name = "Beaststalker's Belt" },
  { id = 11815, name = "Hand of Justice" },
  { id = 16676, name = "Beaststalker's Gloves" },
  { id = 16675, name = "Beaststalker's Boots" },
  { id = 12651, name = "Blackcrow" },
  { id = 12653, name = "Riphook" },
  { id = 16679, name = "Beaststalker's Mantle" },
  { id = 13965, name = "Blackhand's Breadth" },
  { id = 16678, name = "Beaststalker's Pants" },
  { id = 18680, name = "Ancient Bone Bow" },
  { id = 13148, name = "Chillpike" },
  { id = 16677, name = "Beaststalker's Cap" },
  { id = 16674, name = "Beaststalker's Tunic" },
  { id = 13340, name = "Cape of the Black Baron" },

  -- Level 60 -----------------------------------------------------------------
  { id = 19325, name = "Don Julio's Band" },
  { id = 18404, name = "Onyxia Tooth Pendant" },
}

-- Multi-class-ready registry; overrides the generated HUNTER entry.
GearJourney_ClassGuides = GearJourney_ClassGuides or {}
GearJourney_ClassGuides.HUNTER = Hunter
return Hunter
