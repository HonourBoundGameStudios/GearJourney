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
TitanJourney_Compat = Compat

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

-- ApplyRetail(Engine): overlay the Retail facts onto the (Classic-default)
-- engine. Idempotent; safe to call once at load on Retail, or from tests.
function Compat.ApplyRetail(Engine)
  if not Engine then return end
  Engine.CLASS_ARMOR = RETAIL_CLASS_ARMOR
  Engine.CASTER_DPS  = RETAIL_CASTER_DPS
  -- Retail has no armor-skill level-gates (proficiency is granted by class/spec).
  Engine.ArmorWearableAtLevel = function() return true end
  -- v1: no weapon-proficiency filter on Retail (permissive). A per-class Retail
  -- WEAPON_PROF table can replace this later; empty => CanUseWeapon passes all.
  Engine.WEAPON_PROF = {}
end

-- Apply automatically on a real Retail client (Engine is loaded just before us).
if Compat.isRetail and TitanJourney_Engine then
  Compat.ApplyRetail(TitanJourney_Engine)
end

return Compat
