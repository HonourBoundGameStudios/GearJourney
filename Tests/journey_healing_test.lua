-- Bug: pure-healing gear offered to caster DPS. +spell-power (damage&healing)
-- is fine; healing-only is not. Run from project root:
--   lua Tests/journey_healing_test.lua

local H = dofile("Tests/harness.lua")
local Engine = dofile("JourneyEngine.lua")

H.start("no healing-only gear for caster DPS")

-- Classify a tooltip: "both" = has any damage component (DPS-usable),
-- "healing" = healing only, nil = no spell effect.
H.eq(Engine.SpellTypeFromTooltip("Increases damage and healing done by magical spells and effects by up to 9."),
     "both", "damage+healing -> both")
H.eq(Engine.SpellTypeFromTooltip("Increases healing done by spells and effects by up to 22."),
     "healing", "healing only -> healing")
H.eq(Engine.SpellTypeFromTooltip("Increases spell damage by 5."), "both", "spell damage -> both")
H.eq(Engine.SpellTypeFromTooltip("+4 Intellect"), nil, "no spell effect -> nil")
H.eq(Engine.SpellTypeFromTooltip(nil), nil, "nil -> nil")

-- Which specs are caster DPS (talent-tab order).
H.ok(Engine.IsCasterDPS("MAGE", 3), "frost mage is caster DPS")
H.ok(Engine.IsCasterDPS("PRIEST", 3), "shadow priest is caster DPS")
H.ok(not Engine.IsCasterDPS("PRIEST", 2), "holy priest is not")
H.ok(Engine.IsCasterDPS("SHAMAN", 1), "elemental shaman is caster DPS")
H.ok(not Engine.IsCasterDPS("SHAMAN", 3), "resto shaman is not")
H.ok(not Engine.IsCasterDPS("WARRIOR", 1), "warrior is not caster DPS")

-- Reject healing-only items only for caster DPS.
local function names(list)
  local t = {}
  for i = 1, #list do t[i] = list[i].name end
  return table.concat(t, ",")
end
local items = {
  { name = "SpellRobe", spellType = "both" },
  { name = "HealRobe", spellType = "healing" },
  { name = "StatBelt" },  -- no spell effect
}
H.eq(names(Engine.RejectHealingForDPS(items, true)), "SpellRobe,StatBelt", "DPS drops healing-only")
H.eq(#Engine.RejectHealingForDPS(items, false), 3, "non-DPS keeps all")

H.done()
