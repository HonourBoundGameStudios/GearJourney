-- JourneyWarlockData -- curated Warlock leveling gear guide (EPIC-H / FEAT-H2..H9).
--
-- Hand-picked {id, name} pairs, each verified against Wowhead Classic so the
-- provider's Engine.NameMatches guard drops any id that resolves to a different
-- item. Quality/reqLevel/slot/stats/icon resolve at runtime; the overlay buckets
-- by reqLevel, drops non-usable items via Engine.CanUse, and score-filters by the
-- player's spec (Int/Spi/spell power). Cloth armor + sword/dagger/staff/wand (and
-- off-hand shields). IDs in the 200000+ range (SoD/Anniversary-only) are omitted
-- for Classic Era. Overrides the auto-generated WARLOCK guide (loads after
-- JourneyClassGuides.lua).
local Warlock = {
  -- Band 1-10 -----------------------------------------------------------------
  { id = 11287, name = "Lesser Magic Wand" },
  { id = 5071,  name = "Shadow Wand" },

  -- Band 11-20 ----------------------------------------------------------------
  { id = 4310,  name = "Heavy Woolen Gloves" },
  { id = 14150, name = "Robe of Evocation" },
  { id = 5201,  name = "Emberstone Staff" },

  -- Band 21-30 ----------------------------------------------------------------
  { id = 6392,  name = "Belt of Arugal" },
  { id = 6324,  name = "Robes of Arugal" },
  { id = 9395,  name = "Gloves of Old" },
  { id = 7684,  name = "Bloodmage Mantle" },
  { id = 4325,  name = "Boots of the Enchanter" },

  -- Band 31-40 ----------------------------------------------------------------
  { id = 7714,  name = "Hypnotic Blade" },
  { id = 1716,  name = "Robe of the Magi" },
  { id = 19520, name = "Advisor's Ring" },
  { id = 10019, name = "Dreamweave Gloves" },
  { id = 10042, name = "Cindercloth Robe" },

  -- Band 41-50 ----------------------------------------------------------------
  { id = 14436, name = "Windchaser Coronet" },
  { id = 10041, name = "Dreamweave Circlet" },
  { id = 11623, name = "Spritecaster Cape" },

  -- Band 51-59 ----------------------------------------------------------------
  { id = 14108, name = "Felcloth Boots" },
  { id = 18497, name = "Sublime Wristguards" },
  { id = 12930, name = "Briarwood Reed" },
  { id = 14626, name = "Necropile Robe" },
  { id = 14632, name = "Necropile Leggings" },
  { id = 944,   name = "Elemental Mage Staff" },
  { id = 14106, name = "Felcloth Robe" },
  { id = 18485, name = "Observer's Shield" },
  { id = 18407, name = "Felcloth Gloves" },
  { id = 14153, name = "Robe of the Void" },
  { id = 22334, name = "Band of Mending" },

  -- Level 60 (pre-raid) -------------------------------------------------------
  { id = 22327, name = "Amulet of the Redeemed" },
  { id = 12103, name = "Star of Mystaria" },
  { id = 19147, name = "Ring of Spell Power" },
  { id = 19682, name = "Bloodvine Vest" },
  { id = 19684, name = "Bloodvine Boots" },
}

-- Multi-class-ready registry; overrides the generated WARLOCK entry.
GearJourney_ClassGuides = GearJourney_ClassGuides or {}
GearJourney_ClassGuides.WARLOCK = Warlock
return Warlock
