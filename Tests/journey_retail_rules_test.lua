-- Retail rule overlay -- Compat.ApplyRetail(Engine) swaps the Classic armor/
-- class/level-gate rules for Retail ones (single armor type per class incl.
-- DK/DH/Monk/Evoker, no armor level-gates, Retail caster-DPS spec map).
-- Pure table ops, so fully offline-testable. Run from project root:
--   lua Tests/journey_retail_rules_test.lua

local H = dofile("Tests/harness.lua")
local E = dofile("JourneyEngine.lua")
local C = dofile("JourneyCompat.lua")

H.start("Retail rule overlay")

H.ok(type(C.ApplyRetail) == "function", "Compat.ApplyRetail exists")
C.ApplyRetail(E)

-- Single armor type per class, including the four classes Classic never had ----
H.ok(E.CanUse({ armorType = "Plate" },   "DEATHKNIGHT", 10), "DK wears plate")
H.ok(not E.CanUse({ armorType = "Cloth" }, "DEATHKNIGHT", 10), "DK not cloth")
H.ok(E.CanUse({ armorType = "Mail" },    "EVOKER", 10), "Evoker wears mail")
H.ok(not E.CanUse({ armorType = "Plate" }, "EVOKER", 10), "Evoker not plate")
H.ok(E.CanUse({ armorType = "Leather" }, "MONK", 10), "Monk wears leather")
H.ok(not E.CanUse({ armorType = "Mail" }, "MONK", 10), "Monk not mail")
H.ok(E.CanUse({ armorType = "Leather" }, "DEMONHUNTER", 10), "DH wears leather")
H.ok(not E.CanUse({ armorType = "Plate" }, "DEMONHUNTER", 10), "DH not plate")

-- No Classic armor level-gates on Retail (plate/mail usable from any level) -----
H.ok(E.CanUse({ armorType = "Plate" }, "WARRIOR", 10), "Retail: plate at lvl 10 (no gate)")
H.ok(E.CanUse({ armorType = "Mail" },  "HUNTER", 10),  "Retail: mail at lvl 10 (no gate)")
H.ok(E.CanUse({ armorType = "Plate" }, "PALADIN", 1),  "Retail: paladin plate at lvl 1")

-- Existing classes keep the right single type --------------------------------
H.ok(E.CanUse({ armorType = "Cloth" }, "MAGE", 10), "Mage cloth")
H.ok(not E.CanUse({ armorType = "Leather" }, "MAGE", 10), "Mage not leather")
H.ok(E.CanUse({ armorType = "Mail" }, "SHAMAN", 10), "Shaman mail")
H.ok(not E.CanUse({ armorType = "Leather" }, "SHAMAN", 10), "Shaman not leather (Retail)")

-- Shields unchanged (Warrior/Paladin/Shaman) ----------------------------------
H.ok(E.CanUse({ itemClassID = 4, itemSubClassID = 6 }, "WARRIOR", 10), "warrior shield")
H.ok(not E.CanUse({ itemClassID = 4, itemSubClassID = 6 }, "DEATHKNIGHT", 10), "DK no shield")

-- Weapons are permissive on Retail (v1 simplification: no proficiency filter) --
H.ok(E.CanUseWeapon("MAGE", 0), "Retail v1: weapons permissive (mage 'axe' passes)")
H.ok(E.CanUseWeapon("EVOKER", 7), "Retail v1: evoker weapon passes")

-- Retail caster-DPS spec map (drops healing-only gear for these) ---------------
H.ok(E.IsCasterDPS("EVOKER", 1), "Evoker Devastation is caster DPS")
H.ok(not E.IsCasterDPS("EVOKER", 2), "Evoker Preservation (heal) is not")
H.ok(E.IsCasterDPS("PRIEST", 3), "Priest Shadow is caster DPS")
H.ok(not E.IsCasterDPS("PRIEST", 1), "Priest Discipline (heal) is not")
H.ok(E.IsCasterDPS("DRUID", 1), "Druid Balance is caster DPS")
H.ok(not E.IsCasterDPS("DRUID", 4), "Druid Restoration (heal) is not")
H.ok(not E.IsCasterDPS("WARRIOR", 1), "Warrior is never caster DPS")

H.done()
