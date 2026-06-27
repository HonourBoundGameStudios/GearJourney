-- FEAT-J3: the flavour guard on the generated data files. Each Classic/Retail
-- pair publishes the SAME global (TitanJourney_ItemIndex / _AtlasItems), so under
-- a single .toc that loads every file, only the active flavour's file may
-- populate it -- the wrong-flavour file must early-return without clobbering.
-- We stub WOW_PROJECT_* and reload Compat per flavour. Run from project root:
--   lua Tests/journey_dataset_guard_test.lua

local H = dofile("Tests/harness.lua")
H.start("Dataset flavour guard (FEAT-J3)")

local function loadCompat(projectId, mainline)
  _G.WOW_PROJECT_ID = projectId
  _G.WOW_PROJECT_MAINLINE = mainline
  _G.TitanJourney_Engine = nil      -- avoid the ApplyRetail auto-call at load
  return dofile("JourneyCompat.lua")
end

-- Clear the published global, dofile the data file, return (chunkResult, global).
local function load(file, globalName)
  _G[globalName] = nil
  local t = dofile(file)
  return t, _G[globalName]
end

-- ── Retail flavour: only the *_Retail files may populate ─────────────────────
do
  local C = loadCompat(1, 1)
  H.ok(C.isRetail, "retail flavour detected")
  local idx, g = load("JourneyItemIndex_Retail.lua", "TitanJourney_ItemIndex")
  H.ok(#idx > 0 and g ~= nil, "retail index populates on retail")
  local idx2, g2 = load("JourneyItemIndex.lua", "TitanJourney_ItemIndex")
  H.ok(next(idx2) == nil and g2 == nil, "classic index no-ops on retail")
  local pool, pg = load("JourneyAtlasData_Retail.lua", "TitanJourney_AtlasItems")
  H.ok(#pool > 0 and pg ~= nil, "retail pool populates on retail")
  local pool2, pg2 = load("JourneyAtlasData.lua", "TitanJourney_AtlasItems")
  H.ok(next(pool2) == nil and pg2 == nil, "classic pool no-ops on retail")
end

-- ── Classic flavour: only the base files may populate ────────────────────────
do
  local C = loadCompat(2, 1)
  H.ok(C.isClassic, "classic flavour detected")
  local idx, g = load("JourneyItemIndex.lua", "TitanJourney_ItemIndex")
  H.ok(#idx > 0 and g ~= nil, "classic index populates on classic")
  local idx2, g2 = load("JourneyItemIndex_Retail.lua", "TitanJourney_ItemIndex")
  H.ok(next(idx2) == nil and g2 == nil, "retail index no-ops on classic")
  local pool, pg = load("JourneyAtlasData.lua", "TitanJourney_AtlasItems")
  H.ok(#pool > 0 and pg ~= nil, "classic pool populates on classic")
  local pool2, pg2 = load("JourneyAtlasData_Retail.lua", "TitanJourney_AtlasItems")
  H.ok(next(pool2) == nil and pg2 == nil, "retail pool no-ops on classic")
end

-- ── No Compat (offline default): guard is skipped, files load fully ──────────
do
  _G.TitanJourney_Compat = nil
  local idx = load("JourneyItemIndex.lua", "TitanJourney_ItemIndex")
  H.ok(#idx > 0, "with no Compat present the guard is skipped (offline tests/fixtures)")
end

H.done()
