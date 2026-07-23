-- JourneyRogueData -- curated Rogue leveling gear guide (EPIC-H / FEAT-H1).
--
-- Hardcoded {id, name} pairs sourced from ShadowPanther's classic rogue twink
-- weapon/armor lists (shadowpanther.net) plus well-known leveling pieces. We
-- store the expected NAME alongside each id so the provider's Engine.NameMatches
-- guard drops any id that resolves to a different item (page scrapes can be
-- wrong) -- a bad id is skipped, never shown as the wrong item.
--
-- Every other fact (quality, reqLevel, slot, stats, icon) resolves at runtime.
-- The overlay buckets each item into its level band by reqLevel, drops anything
-- not Rogue-usable (Engine.CanUse), and score-filters defensive armor (weapons
-- are kept and ranked by item level). IDs in the 200000+ range (Season of
-- Discovery / Anniversary-only) are intentionally omitted for Classic Era.
local Rogue = {
  -- Weapons: main-hand / off-hand / dagger / sword / mace (ShadowPanther) ------
  { id = 4303,  name = "Cranial Thumper" },
  { id = 4766,  name = "Feral Blade" },
  { id = 3570,  name = "Bonegrinding Pestle" },
  { id = 15445, name = "Hammer of Orgrimmar" },
  { id = 15443, name = "Kris of Orgrimmar" },
  { id = 5191,  name = "Cruel Barb" },
  { id = 1482,  name = "Shadowfang" },
  { id = 1483,  name = "Face Smasher" },
  { id = 1935,  name = "Assassin's Blade" },
  { id = 6472,  name = "Stinging Viper" },
  { id = 20430, name = "Legionnaire's Sword" },
  { id = 8226,  name = "The Butcher" },
  { id = 13033, name = "Zealot Blade" },
  { id = 2912,  name = "Claw of the Shadowmancer" },
  { id = 9453,  name = "Toxic Revenger" },
  { id = 776,   name = "Vendetta" },
  { id = 9427,  name = "Stonevault Bonebreaker" },
  { id = 7721,  name = "Hand of Righteousness" },
  { id = 10703, name = "Fiendish Skiv" },
  { id = 10761, name = "Coldrage Dagger" },
  { id = 809,   name = "Bloodrazor" },
  { id = 17705, name = "Thrash Blade" },
  { id = 13027, name = "Bonesnapper" },
  { id = 2164,  name = "Gut Ripper" },
  { id = 4091,  name = "Widowmaker" },
  { id = 2244,  name = "Krol Blade" },
  { id = 12940, name = "Dal'Rend's Sacred Charge" },
  { id = 11684, name = "Ironfoe" },
  { id = 12590, name = "Felstriker" },
  { id = 12783, name = "Heartseeker" },
  { id = 6622,  name = "Sword of Zeal" },
  { id = 22384, name = "Persuader" },

  -- Low-level fillers (bands 1-10 / 11-15) so the early game isn't empty -------
  { id = 727,   name = "Notched Shortsword" },
  { id = 2282,  name = "Rodentia Shortsword" },
  { id = 2488,  name = "Gladius" },
  { id = 4971,  name = "Skorn's Hammer" },
  { id = 4948,  name = "Stinging Mace" },
  { id = 3223,  name = "Frostmane Scepter" },
  { id = 4932,  name = "Harpy Wing Clipper" },
  { id = 5744,  name = "Pale Skinner" },
  { id = 827,   name = "Wicked Blackjack" },
  { id = 3462,  name = "Talonstrike" },
  { id = 1219,  name = "Redridge Machete" },
  { id = 6504,  name = "Wingblade" },
  { id = 15335, name = "Briarsteel Shortsword" },
  { id = 18957, name = "Brushwood Blade" },

  -- Ranged -------------------------------------------------------------------
  { id = 6469,  name = "Venomstrike" },
  { id = 13136, name = "Lil Timmy's Peashooter" },
  { id = 6696,  name = "Nightstalker Bow" },

  -- Head / Shoulder ----------------------------------------------------------
  { id = 4385,  name = "Green Tinted Goggles" },
  { id = 10588, name = "Goblin Rocket Helm" },
  { id = 10657, name = "Talbar Mantle" },
  { id = 2264,  name = "Mantle of Thieves" },
  { id = 10774, name = "Fleshhide Shoulders" },
  { id = 7755,  name = "Flintrock Shoulders" },
  { id = 17749, name = "Phytoskin Spaulders" },

  -- Chest / Back -------------------------------------------------------------
  { id = 2041,  name = "Tunic of Westfall" },
  { id = 10399, name = "Blackened Defias Armor" },
  { id = 4119,  name = "Raptor Hunter Tunic" },
  { id = 14601, name = "Warden's Wraps" },
  { id = 17742, name = "Fungus Shroud Armor" },
  { id = 2059,  name = "Sentry Cloak" },
  { id = 6449,  name = "Glowing Lizardscale Cloak" },
  { id = 13108, name = "Tigerstrike Mantle" },
  { id = 5193,  name = "Cape of the Brotherhood" },
  { id = 12753, name = "Skin of Shadow" },

  -- Wrist / Hands / Waist ----------------------------------------------------
  { id = 3202,  name = "Forest Leather Bracers" },
  { id = 18948, name = "Barbaric Bracers" },
  { id = 10413, name = "Gloves of the Fang" },
  { id = 1978,  name = "Wolfclaw Gloves" },
  { id = 7284,  name = "Red Whelp Gloves" },
  { id = 15708, name = "Blight Leather Gloves" },
  { id = 6468,  name = "Deviate Scale Belt" },
  { id = 4328,  name = "Spider Belt" },

  -- Legs / Feet --------------------------------------------------------------
  { id = 10410, name = "Leggings of the Fang" },
  { id = 5961,  name = "Dark Leather Pants" },
  { id = 9624,  name = "Triprunner Dungarees" },
  { id = 4108,  name = "Panther Hunter Leggings" },
  { id = 1718,  name = "Basilisk Hide Pants" },
  { id = 1121,  name = "Feet of the Lynx" },
  { id = 7189,  name = "Goblin Rocket Boots" },
  { id = 17728, name = "Albino Crocscale Boots" },

  -- Rings / Trinkets ---------------------------------------------------------
  { id = 6414,  name = "Seal of Sylvanas" },
  { id = 2933,  name = "Seal of Wrynn" },
  { id = 13095, name = "Assault Band" },
  { id = 10710, name = "Dragonclaw Ring" },
  { id = 11669, name = "Naglering" },
  { id = 17774, name = "Mark of the Chosen" },
  { id = 10576, name = "Mechanical Dragonling" },
  { id = 1404,  name = "Tidal Charm" },
}

-- Multi-class-ready registry (FEAT-H2..H9 add more keys). Published as a global
-- by contract; returns the Rogue list for standalone use.
GearJourney_ClassGuides = GearJourney_ClassGuides or {}
GearJourney_ClassGuides.ROGUE = Rogue
return Rogue
