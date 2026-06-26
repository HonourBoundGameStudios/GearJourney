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

return Compat
