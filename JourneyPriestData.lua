-- JourneyPriestData -- curated Priest leveling gear guide (EPIC-H / FEAT-H2..H9).
--
-- Hand-picked {id, name} pairs, each verified against Wowhead Classic so the
-- provider's Engine.NameMatches guard drops any id that resolves to a different
-- item. Quality/reqLevel/slot/stats/icon resolve at runtime; the overlay buckets
-- by reqLevel, drops non-usable items via Engine.CanUse, and score-filters by the
-- player's spec (Int/Spi). Cloth armor + mace/dagger/staff/wand (a wand most
-- bands). IDs in the 200000+ range (SoD/Anniversary-only) are omitted for Classic
-- Era. Overrides the auto-generated PRIEST guide (loads after JourneyClassGuides).
local Priest = {
  -- Band 1-10 -----------------------------------------------------------------
  { id = 4984,  name = "Skull of Impending Doom" },

  -- Band 11-20 ----------------------------------------------------------------
  { id = 14150, name = "Robe of Evocation" },
  { id = 6465,  name = "Robe of the Moccasin" },
  { id = 1974,  name = "Mindthrust Bracers" },
  { id = 5198,  name = "Cookie's Stirring Rod" },
  { id = 7001,  name = "Gravestone Scepter" },

  -- Band 21-30 ----------------------------------------------------------------
  { id = 6903,  name = "Gaze Dreamer Pants" },
  { id = 6324,  name = "Robes of Arugal" },
  { id = 6689,  name = "Wind Spirit Staff" },
  { id = 9491,  name = "Hotshot Pilot's Gloves" },
  { id = 9395,  name = "Gloves of Old" },

  -- Band 31-40 ----------------------------------------------------------------
  { id = 7712,  name = "Mantle of Doan" },
  { id = 7714,  name = "Hypnotic Blade" },
  { id = 1716,  name = "Robe of the Magi" },
  { id = 873,   name = "Staff of Jordan" },
  { id = 10018, name = "Red Mageweave Gloves" },

  -- Band 41-50 ----------------------------------------------------------------
  { id = 5239,  name = "Blackbone Wand" },
  { id = 9433,  name = "Forgotten Wraps" },
  { id = 9484,  name = "Spellshock Leggings" },
  { id = 10629, name = "Mistwalker Boots" },
  { id = 11624, name = "Kentic Amice" },

  -- Band 51-59 ----------------------------------------------------------------
  { id = 16697, name = "Devout Bracers" },
  { id = 13396, name = "Skul's Ghastly Touch" },
  { id = 16696, name = "Devout Belt" },
  { id = 16692, name = "Devout Gloves" },
  { id = 16691, name = "Devout Sandals" },
  { id = 16695, name = "Devout Mantle" },
  { id = 12930, name = "Briarwood Reed" },
  { id = 13390, name = "The Postmaster's Band" },
  { id = 13388, name = "The Postmaster's Tunic" },
  { id = 13389, name = "The Postmaster's Trousers" },
  { id = 13391, name = "The Postmaster's Treads" },
  { id = 14632, name = "Necropile Leggings" },
  { id = 14631, name = "Necropile Boots" },
  { id = 14633, name = "Necropile Mantle" },
  { id = 16694, name = "Devout Skirt" },
  { id = 13938, name = "Bonecreeper Stylus" },
  { id = 16693, name = "Devout Crown" },

  -- Level 60 (pre-raid) -------------------------------------------------------
  { id = 16690, name = "Devout Robe" },
  { id = 12103, name = "Star of Mystaria" },
  { id = 14154, name = "Truefaith Vestments" },
}

-- Multi-class-ready registry; overrides the generated PRIEST entry.
GearJourney_ClassGuides = GearJourney_ClassGuides or {}
GearJourney_ClassGuides.PRIEST = Priest
return Priest
