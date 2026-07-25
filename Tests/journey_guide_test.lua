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
H.eq(Engine.BandIndex(59), 6, "level 59 -> band 6 (51-59)")
H.eq(Engine.BandIndex(60), 7, "level 60 -> its own band 7")
H.eq(Engine.BandIndex(61), 7, "above 60 -> band 7")
H.eq(Engine.BandIndex(0), 1, "level 0 -> band 1")
H.eq(Engine.BandIndex(nil), 1, "nil -> band 1")

H.eq(#Engine.LEVEL_BANDS, 7, "seven level bands defined (60 split out)")

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

H.eq(Engine.SpeedFromText("Speed 2.50"), 2.5, "parses weapon speed")
H.eq(Engine.SpeedFromText("speed 1.80"), 1.8, "case-insensitive speed")
H.eq(Engine.SpeedFromText("Damage"), nil, "no speed -> nil")

-- IsOffSpec: caster gear rejected for a physical spec (hunter weights Int 0.4) --
local hunterW = Engine.WeightsFor("HUNTER", 1, "pve")
H.ok(Engine.IsOffSpec({ stats = { Intellect = 20, Spirit = 10 } }, hunterW),
     "pure caster gear is off-spec for a hunter")
H.ok(not Engine.IsOffSpec({ stats = { Agility = 15, Stamina = 8 } }, hunterW),
     "agility gear is on-spec for a hunter")
H.ok(not Engine.IsOffSpec({ stats = { Agility = 10, Intellect = 8 } }, hunterW),
     "hybrid (agi+int) kept for a hunter")
H.ok(not Engine.IsOffSpec({ stats = {} }, hunterW), "no primary stats (plain weapon) kept")
local mageW = Engine.WeightsFor("MAGE", 1, "pve")
H.ok(Engine.IsOffSpec({ stats = { Agility = 12 } }, mageW),
     "pure agility gear is off-spec for a mage")

-- Caster specs also reject defensive/Stamina-only gear with no caster value --
-- the Warden Staff case (Stamina only) leaking into a Resto/Balance druid list.
local restoW = Engine.WeightsFor("DRUID", 3, "pve")   -- Restoration: Int primary
H.ok(Engine.IsOffSpec({ stats = { Stamina = 11 } }, restoW),
     "stamina-only defensive weapon is off-spec for a caster (Warden Staff)")
H.ok(not Engine.IsOffSpec({ stats = { Stamina = 11 } }, Engine.WeightsFor("DRUID", 2, "pve")),
     "...but that same staff is kept for Feral (physical spec)")
H.ok(not Engine.IsOffSpec({ stats = { Intellect = 10, Stamina = 9 } }, restoW),
     "int+stamina caster piece is kept")
H.ok(not Engine.IsOffSpec({ stats = { Spirit = 8, Stamina = 6 } }, restoW),
     "spirit+stamina caster piece is kept")
H.ok(not Engine.IsOffSpec({ stats = {} }, restoW),
     "a plain no-stat weapon (e.g. wand) is not off-spec for a caster")

-- A statless melee DPS weapon (Arcanite Reaper: pure damage, no stats, no spell
-- effect) is off-spec for a caster -- it must not leak into a healer's weapon list.
H.ok(Engine.IsOffSpec({ itemClassID = 2, itemSubClassID = 5, stats = {} }, restoW),
     "statless melee DPS weapon is off-spec for a caster")
-- ...but a wand (statless, yet the caster's ranged implement) is kept.
H.ok(not Engine.IsOffSpec({ itemClassID = 2, itemSubClassID = 19, stats = {} }, restoW),
     "a wand is kept for a caster")
-- ...and a statless weapon that grants spell power / healing is kept.
H.ok(not Engine.IsOffSpec({ itemClassID = 2, itemSubClassID = 4, stats = {}, spellType = "healing" }, restoW),
     "a spell-effect weapon with no listed stats is kept for a caster")
-- An Int mace stays kept; a statless melee weapon is still fine for a physical spec.
H.ok(not Engine.IsOffSpec({ itemClassID = 2, itemSubClassID = 4, stats = { Intellect = 8 } }, restoW),
     "an Int mace is kept for a caster")
H.ok(not Engine.IsOffSpec({ itemClassID = 2, itemSubClassID = 5, stats = {} },
     Engine.WeightsFor("DRUID", 2, "pve")),
     "statless melee weapon is kept for a physical spec")

H.done()
