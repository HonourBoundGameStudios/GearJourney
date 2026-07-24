-- JourneyDruidData -- curated Druid leveling gear guide (EPIC-H / FEAT-H2..H9).
--
-- Hand-picked {id, name} pairs, each verified against Wowhead Classic so the
-- provider's Engine.NameMatches guard drops any id that resolves to a different
-- item. Quality/reqLevel/slot/stats/icon resolve at runtime; the overlay buckets
-- by reqLevel, drops non-usable items via Engine.CanUse, and score-filters by the
-- player's spec -- both Feral (agi/str) and Balance/Resto (int/spi) pieces are
-- listed and the wrong school is cut at display time. Leather only; mace/staff/
-- polearm/dagger/fist. IDs in the 200000+ range (SoD/Anniversary-only) are omitted
-- for Classic Era. Overrides the auto-generated DRUID guide (loads after
-- JourneyClassGuides.lua).
local Druid = {
  -- Band 1-10 -----------------------------------------------------------------
  { id = 2300,  name = "Embossed Leather Vest" },
  { id = 3314,  name = "Ceremonial Leather Gloves" },
  { id = 2976,  name = "Hunting Gloves" },
  { id = 2899,  name = "Wendigo Collar" },

  -- Band 11-20 ----------------------------------------------------------------
  { id = 10413, name = "Gloves of the Fang" },
  { id = 6449,  name = "Glowing Lizardscale Cloak" },
  { id = 5201,  name = "Emberstone Staff" },
  { id = 6468,  name = "Deviate Scale Belt" },
  { id = 10410, name = "Leggings of the Fang" },
  { id = 1935,  name = "Assassin's Blade" },
  { id = 1121,  name = "Feet of the Lynx" },
  { id = 890,   name = "Twisted Chanter's Staff" },
  { id = 10399, name = "Blackened Defias Armor" },
  { id = 5193,  name = "Cape of the Brotherhood" },

  -- Band 21-30 ----------------------------------------------------------------
  { id = 1978,  name = "Wolfclaw Gloves" },
  { id = 2264,  name = "Mantle of Thieves" },
  { id = 791,   name = "Gnarled Ash Staff" },
  { id = 2912,  name = "Claw of the Shadowmancer" },
  { id = 13108, name = "Tigerstrike Mantle" },
  { id = 9449,  name = "Manual Crowd Pummeler" },

  -- Band 31-40 ----------------------------------------------------------------
  { id = 8175,  name = "Nightscape Tunic" },
  { id = 8176,  name = "Nightscape Headband" },
  { id = 1718,  name = "Basilisk Hide Pants" },
  { id = 4108,  name = "Panther Hunter Leggings" },
  { id = 8345,  name = "Wolfshead Helm" },

  -- Band 41-50 ----------------------------------------------------------------
  { id = 8197,  name = "Nightscape Boots" },
  { id = 943,   name = "Warden Staff" },
  { id = 4119,  name = "Raptor Hunter Tunic" },
  { id = 17749, name = "Phytoskin Spaulders" },
  { id = 17742, name = "Fungus Shroud Armor" },
  { id = 17710, name = "Charstone Dirk" },
  { id = 17713, name = "Blackstone Ring" },

  -- Band 51-59 ----------------------------------------------------------------
  { id = 16714, name = "Wildheart Bracers" },
  { id = 16716, name = "Wildheart Belt" },
  { id = 11815, name = "Hand of Justice" },
  { id = 16715, name = "Wildheart Boots" },
  { id = 16717, name = "Wildheart Gloves" },
  { id = 11669, name = "Naglering" },
  { id = 15062, name = "Devilsaur Leggings" },
  { id = 16718, name = "Wildheart Spaulders" },
  { id = 16719, name = "Wildheart Kilt" },

  -- Level 60 (pre-raid) -------------------------------------------------------
  { id = 16720, name = "Wildheart Cowl" },
  { id = 16706, name = "Wildheart Vest" },
}

-- Multi-class-ready registry; overrides the generated DRUID entry.
GearJourney_ClassGuides = GearJourney_ClassGuides or {}
GearJourney_ClassGuides.DRUID = Druid
return Druid
