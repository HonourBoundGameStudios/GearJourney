-- JourneyShamanData -- curated Shaman leveling gear guide (EPIC-H / FEAT-H2..H9).
--
-- Hand-picked {id, name} pairs, each verified against Wowhead Classic so the
-- provider's Engine.NameMatches guard drops any id that resolves to a different
-- item (a bad id is skipped, never shown as the wrong item). Every other fact
-- (quality, reqLevel, slot, stats, icon) resolves at runtime; the overlay buckets
-- each item into its level band by reqLevel, drops non-usable items via
-- Engine.CanUse, and the in-game guide score-filters by the player's spec -- so
-- both Enhancement (agi/str) and Elemental/Resto (int/spi) pieces are listed and
-- the wrong school is cut at display time. IDs in the 200000+ range (Season of
-- Discovery / Anniversary-only) are intentionally omitted for Classic Era. This
-- overrides the auto-generated SHAMAN guide (loads after JourneyClassGuides.lua).
local Shaman = {
  -- Band 1-10 -----------------------------------------------------------------
  { id = 3314,  name = "Ceremonial Leather Gloves" },
  { id = 2899,  name = "Wendigo Collar" },

  -- Band 11-20 ----------------------------------------------------------------
  { id = 10413, name = "Gloves of the Fang" },
  { id = 6449,  name = "Glowing Lizardscale Cloak" },
  { id = 6468,  name = "Deviate Scale Belt" },
  { id = 10410, name = "Leggings of the Fang" },
  { id = 13404, name = "Mask of the Unforgiven" },
  { id = 10399, name = "Blackened Defias Armor" },
  { id = 3202,  name = "Forest Leather Bracers" },
  { id = 1121,  name = "Feet of the Lynx" },
  { id = 890,   name = "Twisted Chanter's Staff" },
  { id = 5193,  name = "Cape of the Brotherhood" },

  -- Band 21-30 ----------------------------------------------------------------
  { id = 1978,  name = "Wolfclaw Gloves" },
  { id = 2264,  name = "Mantle of Thieves" },
  { id = 18948, name = "Barbaric Bracers" },
  { id = 6414,  name = "Seal of Sylvanas" },

  -- Band 31-40 ----------------------------------------------------------------
  { id = 9624,  name = "Triprunner Dungarees" },
  { id = 7755,  name = "Flintrock Shoulders" },
  { id = 7714,  name = "Hypnotic Blade" },
  { id = 1404,  name = "Tidal Charm" },
  { id = 7717,  name = "Ravager" },
  { id = 13095, name = "Assault Band" },

  -- Band 41-50 ----------------------------------------------------------------
  { id = 14612, name = "Bloodmail Legguards" },
  { id = 17749, name = "Phytoskin Spaulders" },
  { id = 17742, name = "Fungus Shroud Armor" },
  { id = 17728, name = "Albino Crocscale Boots" },
  { id = 17718, name = "Gizlock's Hypertech Buckler" },
  { id = 12624, name = "Wildthorn Mail" },

  -- Band 51-59 ----------------------------------------------------------------
  { id = 11726, name = "Savage Gladiator Chain" },
  { id = 11669, name = "Naglering" },
  { id = 11684, name = "Ironfoe" },
  { id = 13198, name = "Hurd Smasher" },
  { id = 944,   name = "Elemental Mage Staff" },

  -- Level 60 (pre-raid) -------------------------------------------------------
  { id = 12930, name = "Briarwood Reed" },
  { id = 19491, name = "Amulet of the Darkmoon" },
  { id = 17774, name = "Mark of the Chosen" },
}

-- Multi-class-ready registry; overrides the generated SHAMAN entry.
GearJourney_ClassGuides = GearJourney_ClassGuides or {}
GearJourney_ClassGuides.SHAMAN = Shaman
return Shaman
