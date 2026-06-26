-- Retail secondary stats + spec weights -- ApplyRetail teaches the engine the
-- four Retail secondaries (Crit/Haste/Mastery/Versatility) and swaps in
-- spec-weight tables for all 13 classes (GetSpecialization order). Offline.
-- Run from project root: lua Tests/journey_retail_weights_test.lua

local H = dofile("Tests/harness.lua")
local E = dofile("JourneyEngine.lua")
local C = dofile("JourneyCompat.lua")

H.start("Retail secondary stats + spec weights")
C.ApplyRetail(E)

-- Secondary GetItemStats keys now resolve to canonical names ------------------
H.eq(E.STAT_KEY["ITEM_MOD_CRIT_RATING"], "Crit", "crit key mapped")
H.eq(E.STAT_KEY["ITEM_MOD_HASTE_RATING"], "Haste", "haste key mapped")
H.eq(E.STAT_KEY["ITEM_MOD_MASTERY_RATING"], "Mastery", "mastery key mapped")
H.eq(E.STAT_KEY["ITEM_MOD_VERSATILITY"], "Versatility", "versatility key mapped")
-- primaries still mapped (merge, not replace)
H.eq(E.STAT_KEY["ITEM_MOD_AGILITY_SHORT"], "Agility", "primary keys preserved")

-- Every class has weights, with Retail spec counts ---------------------------
local CLASSES = { "WARRIOR","PALADIN","HUNTER","ROGUE","PRIEST","SHAMAN","MAGE",
  "WARLOCK","DRUID","DEATHKNIGHT","DEMONHUNTER","MONK","EVOKER" }
for _, cls in ipairs(CLASSES) do
  local t = E.CLASS_SPEC_WEIGHTS[cls]
  H.ok(type(t) == "table" and #t > 0, "weights present for " .. cls)
end
H.eq(#E.CLASS_SPEC_WEIGHTS.DRUID, 4, "Druid has 4 specs")
H.eq(#E.CLASS_SPEC_WEIGHTS.DEMONHUNTER, 2, "Demon Hunter has 2 specs")
H.eq(#E.CLASS_SPEC_WEIGHTS.EVOKER, 3, "Evoker has 3 specs")
H.eq(#E.CLASS_SPEC_WEIGHTS.DEATHKNIGHT, 3, "Death Knight has 3 specs")

-- Primary stat per representative spec ---------------------------------------
H.eq(E.PrimaryStat(E.WeightsFor("MAGE", 1)), "Intellect", "Mage primary Intellect")
H.eq(E.PrimaryStat(E.WeightsFor("WARRIOR", 1)), "Strength", "Warrior primary Strength")
H.eq(E.PrimaryStat(E.WeightsFor("ROGUE", 1)), "Agility", "Rogue primary Agility")
H.eq(E.PrimaryStat(E.WeightsFor("DEATHKNIGHT", 1)), "Strength", "DK primary Strength")
H.eq(E.PrimaryStat(E.WeightsFor("EVOKER", 1)), "Intellect", "Evoker primary Intellect")
H.eq(E.PrimaryStat(E.WeightsFor("DEMONHUNTER", 1)), "Agility", "DH primary Agility")

-- Secondaries factor into scoring --------------------------------------------
local w = E.WeightsFor("MAGE", 3)   -- Frost
H.ok((w.Crit or 0) > 0 and (w.Haste or 0) > 0, "Retail weights include secondaries")
local withHaste = { stats = { ITEM_MOD_INTELLECT_SHORT = 10, ITEM_MOD_HASTE_RATING = 10 } }
local plain     = { stats = { ITEM_MOD_INTELLECT_SHORT = 10 } }
H.ok(E.ScoreItem(withHaste, w) > E.ScoreItem(plain, w), "haste raises an item's score")

-- Secondary stats now show in the row stat line ------------------------------
local parts = E.StatParts({ ITEM_MOD_INTELLECT_SHORT = 8, ITEM_MOD_CRIT_RATING = 5 })
local hasInt, hasCrit = false, false
for _, p in ipairs(parts) do
  if p.name == "Intellect" then hasInt = true end
  if p.name == "Crit" then hasCrit = true end
end
H.ok(hasInt and hasCrit, "StatParts lists primary + secondary on Retail")

-- Idempotent: applying twice doesn't duplicate the stat order ----------------
local before = #E.STAT_ORDER
C.ApplyRetail(E)
H.eq(#E.STAT_ORDER, before, "ApplyRetail is idempotent (no duplicate stat order)")

H.done()
