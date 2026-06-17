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

H.done()
