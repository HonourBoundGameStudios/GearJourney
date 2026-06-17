-- JourneyRogueData -- curated Rogue leveling gear guide (EPIC-H / FEAT-H1).
--
-- Best-in-slot-focused, not exhaustive. We store ONLY itemIDs: every other
-- fact (name, quality, reqLevel, slot, stats, icon) is resolved at runtime by
-- the provider via GetItemInfo, exactly like the rest of the addon. The overlay
-- buckets each item into its level band by the enriched reqLevel and drops
-- anything not Rogue-usable through Engine.CanUse, so an ID in the wrong place
-- self-corrects in-game.
--
-- IDs are verified against JourneyAtlasData.lua (harvested from AtlasLootClassic
-- and already enriched into TitanJourney_Items). Expand band-by-band as reviewed
-- on a live Rogue.
local Rogue = {
  -- Daggers / 1H swords / maces / fists / axes, leather armor, cloaks, rings,
  -- trinkets. Grouped here loosely low->high; actual band is computed at runtime.
  888,    -- Naga Battle Gloves (BFD)
  1482,   -- Shadowfang (SFK)
  1486,   -- Tree Bark Jacket (BFD)
  1489,   -- Gloomshroud Armor (SFK)
  1935,   -- Assassin's Blade (SFK)
  5191,   -- Cruel Barb (Deadmines)
  5193,   -- Cape of the Brotherhood (Deadmines)
  6459,   -- Savage Trodders (WC)
  7714,   -- Hypnotic Blade (Scarlet Monastery)
  7718,   -- Herod's Shoulder (Scarlet Monastery Armory)
  9379,   -- Sang'thraze the Deflector (Zul'Farrak)
  9418,   -- Stoneslayer (Uldaman)
  9461,   -- Charged Gear (Gnomeregan)
  9476,   -- Big Bad Pauldrons (Zul'Farrak)
  10413,  -- Gloves of the Fang (Wailing Caverns)
  10761,  -- Coldrage Dagger (Razorfen Downs)
  11669,  -- Naglering (Blackrock Depths)
  11684,  -- Ironfoe (Blackrock Depths)
  11810,  -- Force of Will (Blackrock Depths)
  12590,  -- Felstriker (Upper Blackrock Spire)
  12753,  -- Skin of Shadow (Scholomance)
  13167,  -- Fist of Omokk (Lower Blackrock Spire)
  15972,  -- Glinting Steel Dagger (Blacksmithing)
  16995,  -- Heartseeker (Blacksmithing)
  17730,  -- Gatorbite Axe (Maraudon)
  18392,  -- Distracting Dagger (Dire Maul West)
}

-- Multi-class-ready registry (FEAT-H2..H9 add more keys). Published as a global
-- by contract; returns the Rogue list for standalone use.
TitanJourney_ClassGuides = TitanJourney_ClassGuides or {}
TitanJourney_ClassGuides.ROGUE = Rogue
return Rogue
