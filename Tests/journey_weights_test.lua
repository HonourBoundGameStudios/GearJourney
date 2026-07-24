-- Spec stat weighting -- WeightsFor / ScoreItem / BestPerSlotScored.
-- Run from project root: lua Tests/journey_weights_test.lua

local H = dofile("Tests/harness.lua")
local Engine = dofile("JourneyEngine.lua")

H.start("spec stat weighting")

-- Weights cover all classes, indexed by talent-tab order.
H.eq(Engine.WeightsFor("ROGUE", 1).Agility, 1.0, "rogue values Agility")
H.eq(Engine.WeightsFor("MAGE", 3).Intellect, 1.0, "mage (frost) values Intellect")
H.eq(Engine.WeightsFor("WARRIOR", 3).Stamina, 1.0, "prot warrior values Stamina")
H.ok(Engine.WeightsFor("HUNTER", 2).Agility >= Engine.WeightsFor("HUNTER", 2).Intellect,
     "hunter Agility >= Intellect")
H.eq(Engine.WeightsFor("TINKER", 1), nil, "unknown class -> nil weights")

-- Every class/spec has weights (9 classes, tabs 1..3).
local classes = { "WARRIOR","PALADIN","HUNTER","ROGUE","PRIEST","SHAMAN","MAGE","WARLOCK","DRUID" }
local complete = true
for _, c in ipairs(classes) do
  for s = 1, 3 do
    local w = Engine.WeightsFor(c, s)
    if type(w) ~= "table" or next(w) == nil then complete = false end
  end
end
H.ok(complete, "all 9 classes x 3 specs have non-empty weights")

-- PvP mode bumps Stamina for survivability.
local pve = Engine.WeightsFor("ROGUE", 1)
local pvp = Engine.WeightsFor("ROGUE", 1, "pvp")
H.ok(pvp.Stamina > pve.Stamina, "pvp mode raises Stamina weight")
H.eq(pvp.Agility, pve.Agility, "pvp mode keeps primary weight")

-- ScoreItem dots stats with weights; handles raw and canonical stat keys.
local rogueW = Engine.WeightsFor("ROGUE", 1)
H.eq(Engine.ScoreItem({ stats = { ITEM_MOD_AGILITY_SHORT = 10, ITEM_MOD_STAMINA_SHORT = 4 } }, rogueW),
     10 * 1.0 + 4 * rogueW.Stamina, "scores raw GetItemStats keys")
H.eq(Engine.ScoreItem({ stats = { Agility = 10 } }, rogueW), 10.0, "scores canonical keys too")
H.eq(Engine.ScoreItem({ stats = { Intellect = 20 } }, rogueW), 0, "ignores stats the spec doesn't want")
H.eq(Engine.ScoreItem({ stats = nil }, rogueW), 0, "no stats -> 0")
H.eq(Engine.ScoreItem({ stats = { Agility = 5 } }, nil), 0, "no weights -> 0")

-- ResolveSpec: the guide's spec toggle -- an override wins, else follow talents.
H.eq(Engine.ResolveSpec(2, 1), 2, "override wins over active spec")
H.eq(Engine.ResolveSpec(nil, 3), 3, "nil override -> follow active spec")
H.eq(Engine.ResolveSpec(nil, nil), 1, "no override, no active -> spec 1")
H.eq(Engine.ResolveSpec(0, 2), 2, "invalid override (0) -> active spec")
H.eq(Engine.ResolveSpec("x", 2), 2, "non-numeric override -> active spec")
H.eq(Engine.ResolveSpec(2.9, 1), 2, "override floored to an index")

-- BestPerSlotScored picks the highest-scoring item per slot (not highest ilvl).
local items = {
  { name = "AgiVest", slot = "Chest", ilvl = 20, reqLevel = 20, itemID = 1, stats = { Agility = 12 } },
  { name = "IntVest", slot = "Chest", ilvl = 40, reqLevel = 20, itemID = 2, stats = { Intellect = 20 } },
}
local best = Engine.BestPerSlotScored(items, rogueW)
H.eq(#best, 1, "one per slot")
H.eq(best[1].name, "AgiVest", "agility chest beats higher-ilvl intellect chest for a rogue")

H.done()
