-- JourneyCompat -- the ONLY file that branches on game flavour (WOW_PROJECT_ID).
--
-- Everything else (the pure engine, the provider, the overlay) stays
-- flavour-agnostic and calls through here for the handful of things that
-- genuinely differ between Classic and Retail:
--   * spec detection  (Classic talent tabs  vs  Retail GetSpecialization)
--   * the talent-tree background art         (Classic only)
--
-- Phase 0 of the Retail port (see Research/retail-port-spike.md). The Retail
-- rule/stat/weight tables (Phases 2-3) will also be applied from here, by
-- overlaying the Engine's default (Classic) tables when isRetail -- the engine
-- keeps owning the algorithms; this file owns the per-flavour facts.

local Compat = {}
GearJourney_Compat = Compat

-- Flavour detection. WOW_PROJECT_* exist on every modern client; guard anyway so
-- the file is harmless if loaded somewhere they aren't defined.
local PROJECT  = rawget(_G, "WOW_PROJECT_ID")
local MAINLINE = rawget(_G, "WOW_PROJECT_MAINLINE")
Compat.isRetail  = (PROJECT ~= nil and MAINLINE ~= nil and PROJECT == MAINLINE)
Compat.isClassic = not Compat.isRetail

-- PlayerSpec() -> specIndex (1..N), specID|nil
--   Retail:  the active specialization (GetSpecialization gives 1..numSpecs in
--            Blizzard's canonical order, which is the order the weight tables use).
--   Classic: the talent tab with the most points (talent-tab order, default 1).
-- Returns 1 when nothing can be resolved (e.g. very early in login) so callers
-- always get a usable index.
function Compat.PlayerSpec()
  if Compat.isRetail and GetSpecialization then
    local idx = GetSpecialization()
    if not idx or idx < 1 then return 1, nil end
    local id = GetSpecializationInfo and GetSpecializationInfo(idx)
    return idx, id
  end
  local idx, best = 1, -1
  if GetNumTalentTabs and GetTalentTabInfo then
    local n = GetNumTalentTabs() or 0
    for i = 1, n do
      local _, _, pts = GetTalentTabInfo(i)
      pts = tonumber(pts) or 0
      if pts > best then best, idx = pts, i end
    end
  end
  return idx, nil
end

-- SpecNames() -> array of up to 3 spec names in weight-table order.
--   Retail:  GetSpecializationInfo(i) names each of the player's specs.
--   Classic: GetTalentTabInfo(i) names each talent tab.
-- Used to label the Class Guide's spec toggle; capped at 3 to match the engine's
-- 3-spec weight model. Falls back to "Spec 1/2/3" if the API isn't available yet.
function Compat.SpecNames()
  local names = {}
  if Compat.isRetail and GetNumSpecializations and GetSpecializationInfo then
    local n = math.min(GetNumSpecializations() or 0, 3)
    for i = 1, n do names[i] = select(2, GetSpecializationInfo(i)) end
  elseif GetNumTalentTabs and GetTalentTabInfo then
    local n = math.min(GetNumTalentTabs() or 0, 3)
    for i = 1, n do names[i] = (GetTalentTabInfo(i)) end
  end
  for i = 1, 3 do
    if names[i] == nil or names[i] == "" then names[i] = "Spec " .. i end
  end
  return names
end

-- TalentBackgroundBase(classToken) -> texture base name or nil
--   Classic decorates the window with the spec's talent-tree art under
--   Interface\TalentFrame\<base>-{TopLeft,...}. Those textures don't exist on
--   Retail, so we return nil there (the overlay then just shows the dark inset).
--   `bgTable` is the overlay's CLASS_TALENT_BG map (injected to avoid a back-dep).
function Compat.TalentBackgroundBase(classToken, bgTable)
  if Compat.isRetail then return nil end
  local set = classToken and bgTable and bgTable[classToken]
  if not set then return nil, 0 end
  return set
end

-- WantsDataset(isRetailFile) -> bool. Guard for the flavour-specific generated
-- data files (JourneyAtlasData[_Retail], JourneyItemIndex[_Retail]). Each pair
-- publishes the SAME global (GearJourney_AtlasItems / _ItemIndex), so under a
-- single multi-flavour .toc that loads every file, the wrong-flavour file would
-- clobber the right one by load order. Each generated file early-returns unless
-- WantsDataset matches, so only the active flavour's data populates the global.
-- (Offline tests dofile a data file with no Compat present -> guard is skipped.)
function Compat.WantsDataset(isRetailFile)
  if isRetailFile then return Compat.isRetail end
  return Compat.isClassic
end

-- ── Retail rule tables (Phase 2) ─────────────────────────────────────────────
-- One armor type per class (no Classic multi-type/level-gates), including the
-- four classes Classic never had. Overlaid onto the Engine by ApplyRetail.
local RETAIL_CLASS_ARMOR = {
  WARRIOR     = { Plate = true },
  PALADIN     = { Plate = true },
  DEATHKNIGHT = { Plate = true },
  HUNTER      = { Mail = true },
  SHAMAN      = { Mail = true },
  EVOKER      = { Mail = true },
  ROGUE       = { Leather = true },
  DRUID       = { Leather = true },
  MONK        = { Leather = true },
  DEMONHUNTER = { Leather = true },
  MAGE        = { Cloth = true },
  PRIEST      = { Cloth = true },
  WARLOCK     = { Cloth = true },
}

-- Caster-DPS specs by GetSpecialization index (these don't want healing-only
-- gear). Classes with no caster-DPS spec are simply absent.
local RETAIL_CASTER_DPS = {
  MAGE    = { true,  true,  true },          -- Arcane / Fire / Frost
  WARLOCK = { true,  true,  true },          -- Affliction / Demonology / Destruction
  PRIEST  = { false, false, true },          -- Discipline / Holy / Shadow
  DRUID   = { true,  false, false, false },  -- Balance / Feral / Guardian / Restoration
  SHAMAN  = { true,  false, false },         -- Elemental / Enhancement / Restoration
  EVOKER  = { true,  false, true },          -- Devastation / Preservation / Augmentation
}

-- GetItemStats keys for the four Retail secondaries -> canonical names. Both the
-- plain and _SHORT forms are mapped since the key form has varied across builds.
local RETAIL_STAT_KEYS = {
  ITEM_MOD_CRIT_RATING          = "Crit",        ITEM_MOD_CRIT_RATING_SHORT    = "Crit",
  ITEM_MOD_HASTE_RATING         = "Haste",       ITEM_MOD_HASTE_RATING_SHORT   = "Haste",
  ITEM_MOD_MASTERY_RATING       = "Mastery",     ITEM_MOD_MASTERY_RATING_SHORT = "Mastery",
  ITEM_MOD_VERSATILITY          = "Versatility", ITEM_MOD_CR_VERSATILITY_DAMAGE_DONE = "Versatility",
}
local RETAIL_SECONDARIES = { "Crit", "Haste", "Mastery", "Versatility" }
local RETAIL_SECONDARY_ABBR = { Crit = "Crit", Haste = "Haste", Mastery = "Mast", Versatility = "Vers" }

-- Per-spec weights, GetSpecialization order. Primary stat = 1.0, Stamina by role,
-- and a flat 0.5 across all four secondaries: a deliberate *starting model* that
-- gets secondaries into scoring (vs Classic ignoring them entirely). Per-spec
-- secondary tuning is a follow-up (PORT, Phase 3 polish).
local function wt(primary, stamina)
  local t = { Stamina = stamina, Crit = 0.5, Haste = 0.5, Mastery = 0.5, Versatility = 0.5 }
  t[primary] = 1.0
  return t
end
local DPS, TANK = 0.4, 0.6   -- Stamina weight by role
local STR, AGI, INT = "Strength", "Agility", "Intellect"
local RETAIL_CLASS_SPEC_WEIGHTS = {
  WARRIOR     = { wt(STR, DPS),  wt(STR, DPS),  wt(STR, TANK) },               -- Arms/Fury/Prot
  PALADIN     = { wt(INT, DPS),  wt(STR, TANK), wt(STR, DPS) },                -- Holy/Prot/Ret
  DEATHKNIGHT = { wt(STR, TANK), wt(STR, DPS),  wt(STR, DPS) },               -- Blood/Frost/Unholy
  HUNTER      = { wt(AGI, DPS),  wt(AGI, DPS),  wt(AGI, DPS) },               -- BM/MM/SV
  ROGUE       = { wt(AGI, DPS),  wt(AGI, DPS),  wt(AGI, DPS) },               -- Assa/Outlaw/Sub
  MONK        = { wt(AGI, TANK), wt(INT, DPS),  wt(AGI, DPS) },               -- BrM/MW/WW
  DRUID       = { wt(INT, DPS),  wt(AGI, DPS),  wt(AGI, TANK), wt(INT, DPS) }, -- Bal/Feral/Guardian/Resto
  DEMONHUNTER = { wt(AGI, DPS),  wt(AGI, TANK) },                              -- Havoc/Vengeance
  SHAMAN      = { wt(INT, DPS),  wt(AGI, DPS),  wt(INT, DPS) },               -- Ele/Enh/Resto
  PRIEST      = { wt(INT, DPS),  wt(INT, DPS),  wt(INT, DPS) },               -- Disc/Holy/Shadow
  MAGE        = { wt(INT, DPS),  wt(INT, DPS),  wt(INT, DPS) },               -- Arcane/Fire/Frost
  WARLOCK     = { wt(INT, DPS),  wt(INT, DPS),  wt(INT, DPS) },               -- Affl/Demo/Destro
  EVOKER      = { wt(INT, DPS),  wt(INT, DPS),  wt(INT, DPS) },               -- Devastation/Preservation/Augmentation
}

-- ApplyRetail(Engine): overlay the Retail facts onto the (Classic-default)
-- engine. Idempotent; safe to call once at load on Retail, or from tests.
function Compat.ApplyRetail(Engine)
  if not Engine or Engine.__retailApplied then return end
  Engine.__retailApplied = true

  Engine.CLASS_ARMOR        = RETAIL_CLASS_ARMOR
  Engine.CASTER_DPS         = RETAIL_CASTER_DPS
  Engine.CLASS_SPEC_WEIGHTS = RETAIL_CLASS_SPEC_WEIGHTS
  -- Retail has no armor-skill level-gates (proficiency is granted by class/spec).
  Engine.ArmorWearableAtLevel = function() return true end
  -- v1: no weapon-proficiency filter on Retail (permissive). A per-class Retail
  -- WEAPON_PROF table can replace this later; empty => CanUseWeapon passes all.
  Engine.WEAPON_PROF = {}

  -- Teach the engine the four Retail secondaries (scoring + display).
  for k, v in pairs(RETAIL_STAT_KEYS) do Engine.STAT_KEY[k] = v end
  for _, s in ipairs(RETAIL_SECONDARIES) do
    Engine.STAT_ORDER[#Engine.STAT_ORDER + 1] = s
    Engine.STAT_ABBR[s] = RETAIL_SECONDARY_ABBR[s]
  end
end

-- Apply automatically on a real Retail client (Engine is loaded just before us).
if Compat.isRetail and GearJourney_Engine then
  Compat.ApplyRetail(GearJourney_Engine)
end

return Compat
