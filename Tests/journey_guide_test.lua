-- Class gear guide helpers (EPIC-H): itemID lookup + level-band bucketing.
-- Run from project root:  lua Tests/journey_guide_test.lua

local H = dofile("Tests/harness.lua")
local Engine = dofile("JourneyEngine.lua")

H.start("class guide helpers")

-- FindByID -----------------------------------------------------------------
local pool = {
  { itemID = 5191, name = "Cruel Barb" },
  { itemID = 11684, name = "Ironfoe" },
}
H.eq(Engine.FindByID(pool, 11684).name, "Ironfoe", "FindByID hits")
H.eq(Engine.FindByID(pool, 999), nil, "FindByID miss -> nil")
H.eq(Engine.FindByID(pool, nil), nil, "FindByID nil id -> nil")

-- BandIndex ----------------------------------------------------------------
H.eq(Engine.BandIndex(1), 1, "level 1 -> band 1")
H.eq(Engine.BandIndex(10), 1, "level 10 -> band 1 (boundary)")
H.eq(Engine.BandIndex(11), 2, "level 11 -> band 2 (boundary)")
H.eq(Engine.BandIndex(38), 4, "level 38 -> band 4")
H.eq(Engine.BandIndex(60), 6, "level 60 -> band 6")
H.eq(Engine.BandIndex(61), 6, "above 60 clamps to band 6")
H.eq(Engine.BandIndex(0), 1, "level 0 -> band 1")
H.eq(Engine.BandIndex(nil), 1, "nil -> band 1")

H.eq(#Engine.LEVEL_BANDS, 6, "six level bands defined")

-- BestDungeon -------------------------------------------------------------
-- Neutral items (no armorType / not weapons) so CanUse passes for any class.
local dungeons = {
  { itemID = 1, sourceType = "Dungeon", sourceLabel = "Deadmines", reqLevel = 18 },
  { itemID = 2, sourceType = "Dungeon", sourceLabel = "Deadmines", reqLevel = 20 },
  { itemID = 3, sourceType = "Dungeon", sourceLabel = "Wailing Caverns", reqLevel = 19 },
  { itemID = 4, sourceType = "Dungeon", sourceLabel = "Deadmines", reqLevel = 40 }, -- out of window
  { itemID = 5, sourceType = "Quest",   sourceLabel = "Westfall", reqLevel = 18 },   -- not a dungeon
}
local best, n = Engine.BestDungeon(dungeons, "ROGUE", 18, nil)
H.eq(best, "Deadmines", "picks the dungeon with most in-window upgrades")
H.eq(n, 2, "counts only in-window dungeon items")

local owns = function(id) return id == 1 or id == 2 end  -- owns both Deadmines items
local best2 = Engine.BestDungeon(dungeons, "ROGUE", 18, owns)
H.eq(best2, "Wailing Caverns", "owned items excluded -> next dungeon wins")

-- SearchByName ------------------------------------------------------------
local pool2 = {
  { name = "Cruel Barb" }, { name = "Assassin's Blade" }, { name = "Cruel Hand" },
}
H.eq(#Engine.SearchByName(pool2, "cruel"), 2, "case-insensitive substring match")
H.eq(Engine.SearchByName(pool2, "blade")[1].name, "Assassin's Blade", "partial match")
H.eq(#Engine.SearchByName(pool2, "cruel", 1), 1, "limit honoured")
H.eq(#Engine.SearchByName(pool2, ""), 0, "empty query -> no results")

-- DpsFromTooltip ----------------------------------------------------------
H.eq(Engine.DpsFromTooltip("Speed 2.50\n(36.4 damage per second)"), 36.4, "parses DPS")
H.eq(Engine.DpsFromTooltip("12 - 18 Damage\n(15.0 damage per second)"), 15.0, "parses whole DPS")
H.eq(Engine.DpsFromTooltip("No weapon line here"), nil, "no DPS -> nil")
H.eq(Engine.DpsFromTooltip(nil), nil, "nil -> nil")

H.done()
