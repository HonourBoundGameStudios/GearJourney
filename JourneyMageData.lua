-- JourneyMageData -- curated Mage leveling gear guide (EPIC-H / FEAT-H2..H9).
--
-- Hand-picked {id, name} pairs, each verified against Wowhead Classic so the
-- provider's Engine.NameMatches guard drops any id that resolves to a different
-- item. Quality/reqLevel/slot/stats/icon resolve at runtime; the overlay buckets
-- by reqLevel, drops non-usable items via Engine.CanUse, and score-filters by the
-- player's spec (Int/Spi). Cloth armor + sword/dagger/staff/wand. IDs in the
-- 200000+ range (SoD/Anniversary-only) are omitted for Classic Era. Overrides the
-- auto-generated MAGE guide (loads after JourneyClassGuides.lua).
local Mage = {
  -- Band 1-10 -----------------------------------------------------------------
  { id = 11287, name = "Lesser Magic Wand" },

  -- Band 11-20 ----------------------------------------------------------------
  { id = 11288, name = "Greater Magic Wand" },
  { id = 5243,  name = "Firebelcher" },
  { id = 5198,  name = "Cookie's Stirring Rod" },
  { id = 14150, name = "Robe of Evocation" },
  { id = 20426, name = "Advisor's Ring" },
  { id = 12998, name = "Magician's Mantle" },
  { id = 4320,  name = "Spidersilk Boots" },

  -- Band 21-30 ----------------------------------------------------------------
  { id = 4036,  name = "Silver-thread Cuffs" },
  { id = 3748,  name = "Feline Mantle" },
  { id = 4319,  name = "Azure Silk Gloves" },
  { id = 6324,  name = "Robes of Arugal" },
  { id = 7053,  name = "Azure Silk Cloak" },
  { id = 7514,  name = "Icefury Wand" },

  -- Band 31-40 ----------------------------------------------------------------
  { id = 7714,  name = "Hypnotic Blade" },
  { id = 7713,  name = "Illusionary Rod" },
  { id = 7054,  name = "Robe of Power" },
  { id = 1716,  name = "Robe of the Magi" },
  { id = 7720,  name = "Whitemane's Chapeau" },
  { id = 10021, name = "Dreamweave Vest" },
  { id = 10019, name = "Dreamweave Gloves" },

  -- Band 41-50 ----------------------------------------------------------------
  { id = 940,   name = "Robes of Insight" },
  { id = 10041, name = "Dreamweave Circlet" },
  { id = 17745, name = "Noxious Shooter" },
  { id = 942,   name = "Freezing Band" },
  { id = 11662, name = "Ban'thok Sash" },

  -- Band 51-59 ----------------------------------------------------------------
  { id = 10836, name = "Rod of Corrosion" },
  { id = 14136, name = "Robe of Winter Night" },
  { id = 16689, name = "Magister's Mantle" },
  { id = 12930, name = "Briarwood Reed" },
  { id = 16687, name = "Magister's Leggings" },
  { id = 16686, name = "Magister's Crown" },
  { id = 13938, name = "Bonecreeper Stylus" },
  { id = 12103, name = "Star of Mystaria" },
  { id = 22327, name = "Amulet of the Redeemed" },

  -- Level 60 (pre-raid / Tier 0.5) --------------------------------------------
  { id = 22065, name = "Sorcerer's Crown" },
  { id = 22066, name = "Sorcerer's Gloves" },
  { id = 22063, name = "Sorcerer's Bindings" },
  { id = 22064, name = "Sorcerer's Boots" },
}

-- Multi-class-ready registry; overrides the generated MAGE entry.
GearJourney_ClassGuides = GearJourney_ClassGuides or {}
GearJourney_ClassGuides.MAGE = Mage
return Mage
