-- Display helpers -- PrettySource / StatSummary.
-- Run from project root: lua Tests/journey_display_test.lua

local H = dofile("Tests/harness.lua")
local Engine = dofile("JourneyEngine.lua")

H.start("display helpers")

-- PrettySource spaces CamelCase instance keys but leaves apostrophes alone.
H.eq(Engine.PrettySource("TheDeadmines"), "The Deadmines", "CamelCase -> spaced")
H.eq(Engine.PrettySource("BlackfathomDeeps"), "Blackfathom Deeps", "spaces each word")
H.eq(Engine.PrettySource("TheTempleOfAtal'Hakkar"), "The Temple Of Atal'Hakkar", "keeps apostrophe word")
H.eq(Engine.PrettySource("Zul'Farrak"), "Zul'Farrak", "apostrophe name unchanged")
H.eq(Engine.PrettySource("Tailoring"), "Tailoring", "single word unchanged")
H.eq(Engine.PrettySource(""), "", "empty stays empty")

-- StatSummary lists primary stats in a fixed order with short labels.
H.eq(Engine.StatSummary({ ITEM_MOD_AGILITY_SHORT = 12, ITEM_MOD_STAMINA_SHORT = 5 }),
     "+12 Agi +5 Sta", "raw keys, fixed order")
H.eq(Engine.StatSummary({ Intellect = 10, Spirit = 4 }), "+10 Int +4 Spi", "canonical keys")
H.eq(Engine.StatSummary(nil), "", "no stats -> empty")
H.eq(Engine.StatSummary({}), "", "empty stats -> empty")

-- BuildItem stores a prettified source label.
local it = Engine.BuildItem(
  { id = 9, sourceType = "Dungeon", source = "TheDeadmines" },
  { name = "X", quality = 2, reqLevel = 18, equipLoc = "INVTYPE_CHEST", classID = 4, subClassID = 2 })
H.eq(it.sourceLabel, "The Deadmines", "BuildItem prettifies source label")

H.done()
