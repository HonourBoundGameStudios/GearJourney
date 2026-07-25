-- JourneyCompat -- flavour detection + spec resolution. We can't run the real
-- WoW APIs offline, so we stub the globals the compat layer reads and reload it
-- under each flavour. (Compat is the only file allowed to branch on flavour.)
-- Run from project root: lua Tests/journey_compat_test.lua

local H = dofile("Tests/harness.lua")
H.start("JourneyCompat flavour seam")

-- Helper: clear the flavour/spec globals, set the given ones, then (re)load the
-- module fresh so its load-time flavour detection re-runs.
local function loadWith(globals)
  for _, k in ipairs({
    "WOW_PROJECT_ID", "WOW_PROJECT_MAINLINE",
    "GetSpecialization", "GetSpecializationInfo",
    "GetNumTalentTabs", "GetTalentTabInfo",
  }) do _G[k] = nil end
  for k, v in pairs(globals) do _G[k] = v end
  return dofile("JourneyCompat.lua")
end

-- ── Retail flavour ────────────────────────────────────────────────────────────
do
  local C = loadWith({
    WOW_PROJECT_ID = 1, WOW_PROJECT_MAINLINE = 1,
    GetSpecialization = function() return 2 end,
    GetSpecializationInfo = function(i) return 250 + i end,
    -- Classic talent APIs also present should be IGNORED on Retail:
    GetNumTalentTabs = function() return 3 end,
    GetTalentTabInfo = function() return nil, nil, 99 end,
  })
  H.ok(C.isRetail, "WOW_PROJECT_ID == MAINLINE -> isRetail")
  H.ok(not C.isClassic, "not isClassic on Retail")
  local idx, id = C.PlayerSpec()
  H.eq(idx, 2, "Retail spec index from GetSpecialization")
  H.eq(id, 252, "Retail spec id from GetSpecializationInfo")
  H.eq(C.TalentBackgroundBase("MAGE", { MAGE = { "a", "b", "c" } }), nil,
    "no talent-tree art on Retail")
end

-- ── Retail with no active spec (early login) ─────────────────────────────────
do
  local C = loadWith({
    WOW_PROJECT_ID = 1, WOW_PROJECT_MAINLINE = 1,
    GetSpecialization = function() return nil end,
  })
  local idx = C.PlayerSpec()
  H.eq(idx, 1, "Retail falls back to spec 1 when none active")
end

-- ── Classic Era flavour ──────────────────────────────────────────────────────
do
  local tabs = { {0}, {31}, {5} }   -- tab 2 has the most points
  local C = loadWith({
    WOW_PROJECT_ID = 2, WOW_PROJECT_MAINLINE = 1,   -- era != mainline
    GetNumTalentTabs = function() return #tabs end,
    GetTalentTabInfo = function(i) return "Tab" .. i, nil, tabs[i][1] end,
  })
  H.ok(C.isClassic, "era project -> isClassic")
  H.ok(not C.isRetail, "not isRetail on Classic")
  local idx, id = C.PlayerSpec()
  H.eq(idx, 2, "Classic spec = talent tab with most points")
  H.eq(id, nil, "Classic returns no spec id")
  local set = C.TalentBackgroundBase("MAGE", { MAGE = { "MageArcane", "MageFire", "MageFrost" } })
  H.eq(type(set), "table", "Classic returns the class talent-bg set")
  H.eq(set[1], "MageArcane", "talent-bg set carries the base names")
end

-- ── SpecNames: Classic talent tabs that lead with a numeric id ───────────────
-- Real clients (e.g. paladin tabs 381/382/383) return id FIRST, then the name,
-- then pointsSpent -- so we must pick the name string, not return #1.
do
  local C = loadWith({
    WOW_PROJECT_ID = 2, WOW_PROJECT_MAINLINE = 1,
    GetNumTalentTabs = function() return 3 end,
    GetTalentTabInfo = function(i)
      local n = ({ "Holy", "Protection", "Retribution" })[i]
      return 380 + i, n, "Interface\\Icons\\Spell_Holy_" .. i, 0  -- id, name, icon, points
    end,
  })
  local names = C.SpecNames()
  H.eq(names[1], "Holy", "SpecNames picks the name, not the leading id")
  H.eq(names[2], "Protection", "second tab name")
  H.eq(names[3], "Retribution", "third tab name")
end

-- ── SpecNames: name-first signature still works ──────────────────────────────
do
  local C = loadWith({
    WOW_PROJECT_ID = 2, WOW_PROJECT_MAINLINE = 1,
    GetNumTalentTabs = function() return 3 end,
    GetTalentTabInfo = function(i) return ({ "Arms", "Fury", "Prot" })[i], nil, 0 end,
  })
  H.eq(C.SpecNames()[2], "Fury", "name-first signature also resolves")
end

-- ── SpecNames: Retail specialization names ───────────────────────────────────
do
  local C = loadWith({
    WOW_PROJECT_ID = 1, WOW_PROJECT_MAINLINE = 1,
    GetNumSpecializations = function() return 3 end,
    GetSpecializationInfo = function(i)
      return 60 + i, ({ "Balance", "Feral", "Restoration" })[i], "desc", 12345
    end,
  })
  H.eq(C.SpecNames()[3], "Restoration", "Retail SpecNames from GetSpecializationInfo")
end

-- ── SpecNames: no talent API -> "Spec N" fallback ────────────────────────────
do
  local C = loadWith({ WOW_PROJECT_ID = 2, WOW_PROJECT_MAINLINE = 1 })
  H.eq(C.SpecNames()[1], "Spec 1", "fallback label when no talent API")
end

-- ── No talent info at all (very early / unknown) ─────────────────────────────
do
  local C = loadWith({ WOW_PROJECT_ID = 2, WOW_PROJECT_MAINLINE = 1 })
  H.eq(C.PlayerSpec(), 1, "defaults to spec 1 with no talent API")
end

H.done()
