-- JourneyScenarios -- in-client behaviour tests for the parts that can only run
-- inside WoW (Titan button, tooltip, the Provider's live GetItemInfo enrichment,
-- and the Overlay frames). The pure engine/DB is covered offline by Tests/; this
-- file covers everything those tests cannot reach.
--
-- Run it in-game:  /titanjourney run-testing-scenarios   (alias: /tj test)
--
-- Design is lifted from the fleet's Flux Testing Engine (G:\dev\Flux,
-- Services/Testing) and adapted from C# to Lua: a Scenario has an id/name/tags,
-- an optional setup + teardown, and a run(t) body that performs *steps* (actions
-- whose failure aborts the scenario, like Flux's StepFailBehaviour.Stop) and
-- *assertions* (typed checks). A run produces a RunSummary printed to chat:
-- per-scenario PASS/FAIL plus an aggregate "all passed" line.

local S = {}
TitanJourney_Scenarios = S

local scenarios = {}   -- ordered registry

-- ── Output helpers ───────────────────────────────────────────────────────────
local GREEN, RED, GRAY, GOLD, CYAN = "33ff33", "ff5555", "999999", "ffd100", "66ccff"
local function col(hex, s) return "|cff" .. hex .. tostring(s) .. "|r" end
local function out(msg)
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage(msg)
  else
    print(msg)
  end
end

local function hasTag(tags, want)
  if not tags then return false end
  for _, t in ipairs(tags) do if t == want then return true end end
  return false
end

-- ── Assertion / step context handed to each scenario body ────────────────────
local ABORT = {}   -- unique sentinel: a failed step throws this to stop the scenario

local function newCtx()
  local ctx = { passed = 0, failed = 0, fails = {} }

  function ctx.ok(cond, desc)
    if cond then
      ctx.passed = ctx.passed + 1
    else
      ctx.failed = ctx.failed + 1
      ctx.fails[#ctx.fails + 1] = desc
    end
    return cond and true or false
  end

  function ctx.eq(got, want, desc)
    if got == want then return ctx.ok(true, desc) end
    return ctx.ok(false, desc .. " (got " .. tostring(got) .. ", want " .. tostring(want) .. ")")
  end

  function ctx.truthy(v, desc) return ctx.ok(v ~= nil and v ~= false, desc) end

  function ctx.contains(haystack, needle, desc)
    return ctx.ok(type(haystack) == "string"
      and haystack:find(needle, 1, true) ~= nil, desc)
  end

  function ctx.gt(a, b, desc)
    return ctx.ok(type(a) == "number" and a > b, desc
      .. ((type(a) == "number") and "" or " (not a number: " .. tostring(a) .. ")"))
  end

  -- A step is an action; if it errors, record the failure and abort the scenario
  -- (Flux's Stop-on-fail). Pass continueOnFail=true to keep going instead.
  function ctx.step(desc, fn, continueOnFail)
    local ok, err = pcall(fn)
    if ok then
      ctx.passed = ctx.passed + 1
    else
      ctx.failed = ctx.failed + 1
      ctx.fails[#ctx.fails + 1] = desc .. " [step error: " .. tostring(err) .. "]"
      if not continueOnFail then error(ABORT) end
    end
  end

  return ctx
end

-- ── Registration ─────────────────────────────────────────────────────────────
function S.scenario(def) scenarios[#scenarios + 1] = def end

-- ── Runner (orchestrator + reporter) ─────────────────────────────────────────
-- filter: nil = run all; otherwise a tag or a scenario id.
function S.Run(filter)
  out(col(GOLD, "TitanJourney scenarios") .. col(GRAY, "  " .. (date and date("%H:%M:%S") or "")))
  local total, passedScen, failedScen, aPass, aFail = 0, 0, 0, 0, 0
  local records = {}   -- plain-data per-scenario results, persisted to SavedVariables

  for _, sc in ipairs(scenarios) do
    local selected = (not filter) or sc.id == filter or hasTag(sc.tags, filter)
    if selected then
      total = total + 1
      local ctx = newCtx()

      if sc.setup then pcall(sc.setup) end
      local ok, err = pcall(sc.run, ctx)
      if not ok and err ~= ABORT then
        ctx.failed = ctx.failed + 1
        ctx.fails[#ctx.fails + 1] = "scenario error: " .. tostring(err)
      end
      if sc.teardown then pcall(sc.teardown) end

      aPass, aFail = aPass + ctx.passed, aFail + ctx.failed
      local scenPassed = (ctx.failed == 0)
      if scenPassed then passedScen = passedScen + 1 else failedScen = failedScen + 1 end

      out(string.format("  %s  %s  %s",
        scenPassed and col(GREEN, "PASS") or col(RED, "FAIL"),
        col(CYAN, sc.id),
        sc.name .. col(GRAY, "  (" .. ctx.passed .. "/" .. (ctx.passed + ctx.failed) .. ")")))
      for _, f in ipairs(ctx.fails) do out("        " .. col(RED, "- " .. f)) end

      records[#records + 1] = {
        id = sc.id, name = sc.name, passed = scenPassed,
        checks = ctx.passed + ctx.failed, failed = ctx.failed, fails = ctx.fails,
      }
    end
  end

  out(string.format("%s %d scenarios: %s, %s   %s %d checks, %s",
    col(GOLD, "==>"), total,
    col(GREEN, passedScen .. " passed"),
    failedScen > 0 and col(RED, failedScen .. " failed") or col(GRAY, "0 failed"),
    col(GRAY, "|"), aPass + aFail,
    aFail > 0 and col(RED, aFail .. " failed") or col(GREEN, "all passed")))

  -- Persist the run to SavedVariables so it survives to disk on /reload or
  -- logout (the only times WoW flushes TitanJourneyDB). Lets the run be read
  -- back from WTF/.../SavedVariables/TitanJourney.lua without copy-pasting chat.
  local report = {
    when = (date and date("%Y-%m-%d %H:%M:%S")) or "",
    addonVersion = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("TitanJourney", "Version")) or "",
    filter = filter or "(all)",
    scenarios = total, scenariosPassed = passedScen, scenariosFailed = failedScen,
    checks = aPass + aFail, checksFailed = aFail,
    allPassed = (failedScen == 0),
    results = records,
  }
  TitanJourneyDB = TitanJourneyDB or {}
  TitanJourneyDB.lastScenarioRun = report
  out(col(GRAY, "    saved to SavedVariables -- /reload (or log out) to flush it to disk."))
  return failedScen == 0, report
end

-- ── Shared helpers for the scenarios ─────────────────────────────────────────
local function overlayFrame() return _G.TitanJourneyOverlay end
local function openOverlay()
  local O = TitanJourney_Overlay
  if O and not (overlayFrame() and overlayFrame():IsShown()) then O.Toggle() end
end
local function closeOverlay()
  local O = TitanJourney_Overlay
  if O and overlayFrame() and overlayFrame():IsShown() then O.Toggle() end
end

-- ═════════════════════════════════════════════════════════════════════════════
--  Scenarios
-- ═════════════════════════════════════════════════════════════════════════════

S.scenario{
  id = "SCN-ENGINE", name = "Engine self-test passes in-client", tags = { "smoke" },
  run = function(t)
    t.truthy(TitanJourney_Engine, "engine module loaded")
    if t.truthy(TitanJourney_Tests, "in-client test module loaded") then
      local p, f = TitanJourney_Tests.Run()
      t.gt(p, 0, "self-test executed checks")
      t.eq(f, 0, "self-test reports zero failures")
    end
  end,
}

S.scenario{
  id = "SCN-BUTTON", name = "Titan button text resolves", tags = { "smoke", "titan" },
  run = function(t)
    t.truthy(TitanJourney_GetButtonText, "button text function published")
    local label, value = TitanJourney_GetButtonText("Journey")
    t.eq(label, "Next Goal:", "button label is the constant")
    t.truthy(value and value ~= "", "button value is non-empty")
  end,
}

S.scenario{
  id = "SCN-TOOLTIP", name = "Tooltip text builds with footer", tags = { "titan" },
  run = function(t)
    t.truthy(TitanJourney_GetTooltipText, "tooltip function published")
    local tip = TitanJourney_GetTooltipText()
    t.truthy(type(tip) == "string" and #tip > 0, "tooltip returns text")
    t.contains(tip, "Honour Bound Game Studios", "tooltip carries the studio footer")
  end,
}

S.scenario{
  id = "SCN-PROVIDER", name = "Provider publishes an enriched pool", tags = { "data" },
  run = function(t)
    t.truthy(TitanJourney_Items, "TitanJourney_Items is published")
    -- Seeded instantly from the saved cache, so this should be non-empty even
    -- mid-stream on a fresh login (it grows as GetItemInfo resolves).
    t.gt(#(TitanJourney_Items or {}), 0, "pool has at least one item")
    local it = (TitanJourney_Items or {})[1]
    if it then
      t.truthy(it.name and it.slot and it.quality, "an enriched item carries schema fields")
    end
  end,
}

S.scenario{
  id = "SCN-BUILDITEM", name = "BuildItem maps a live game item", tags = { "data" },
  run = function(t)
    local E = TitanJourney_Engine
    local id = 25   -- Worn Shortsword: a starter item, almost always cached
    local _, _, _, equipLoc, icon, classID, subClassID = GetItemInfoInstant(id)
    if not t.truthy(equipLoc, "GetItemInfoInstant returns an equip slot") then return end
    local name, _, quality, ilvl, reqLevel = GetItemInfo(id)
    if not name then
      t.ok(true, "item not cached yet -- live BuildItem skipped (re-run shortly)")
      return
    end
    local item = E.BuildItem({ id = id, sourceType = "", source = "" }, {
      name = name, quality = quality, reqLevel = reqLevel, ilvl = ilvl,
      equipLoc = equipLoc, classID = classID, subClassID = subClassID, icon = icon,
    })
    if t.truthy(item, "BuildItem returns an item") then
      t.eq(item.slot, "Main Hand", "shortsword maps to the Main Hand slot")
      t.truthy(item.icon, "icon carried through")
    end
  end,
}

S.scenario{
  id = "SCN-OWNS", name = "PlayerOwnsFn answers and memoises", tags = { "overlay" },
  run = function(t)
    local O = TitanJourney_Overlay
    if not t.truthy(O and O.PlayerOwnsFn, "PlayerOwnsFn available") then return end
    O._ownsFn = nil
    local fn = O.PlayerOwnsFn()
    t.truthy(type(fn) == "function", "returns a predicate")
    t.eq(fn(nil), false, "nil itemID -> not owned")
    t.eq(fn(0), false, "itemID 0 -> not owned")
    t.ok(O.PlayerOwnsFn() == fn, "memoised: the same closure is returned")
    O._ownsFn = nil
    t.ok(O.PlayerOwnsFn() ~= fn, "cache invalidation rebuilds the closure")
  end,
}

S.scenario{
  id = "SCN-OVERLAY", name = "Manager window opens and closes", tags = { "overlay", "ui" },
  teardown = closeOverlay,
  run = function(t)
    local O = TitanJourney_Overlay
    if not t.truthy(O and O.Toggle, "Overlay.Toggle available") then return end
    closeOverlay()
    t.step("open the window", function() O.Toggle() end)
    local f = overlayFrame()
    t.truthy(f, "overlay frame created")
    t.ok(f and f:IsShown(), "window is shown after the first toggle")
    t.step("close the window", function() O.Toggle() end)
    t.ok(f and not f:IsShown(), "window is hidden after the second toggle")
  end,
}

S.scenario{
  id = "SCN-TABS", name = "Every sidebar tab selects and shows", tags = { "overlay", "ui" },
  teardown = closeOverlay,
  run = function(t)
    local O = TitanJourney_Overlay
    if not t.truthy(O and O.SelectTab, "SelectTab available") then return end
    openOverlay()
    for _, key in ipairs({ "journey", "guide", "browse", "future", "inspect", "settings" }) do
      t.step("select " .. key, function() O.SelectTab(key) end)
      t.eq(O.activeTab, key, "active tab = " .. key)
      local panel = O.panels and O.panels[key]
      t.ok(panel and panel:IsShown(), key .. " panel is shown")
    end
  end,
}

S.scenario{
  id = "SCN-COMPUTE", name = "ComputeList / ComputeCandidates return data", tags = { "overlay" },
  run = function(t)
    local O = TitanJourney_Overlay
    if not t.truthy(O and O.ComputeList, "ComputeList available") then return end
    local cur, lvl = O.ComputeList("current")
    t.truthy(type(cur) == "table", "current list is a table")
    t.truthy(type(lvl) == "number", "player level is a number")
    t.truthy(type(O.ComputeList("future")) == "table", "future list is a table")
    local cands = O.ComputeCandidates("all")
    t.truthy(type(cands) == "table", "candidate list is a table")
    t.ok(#cands <= 400, "candidates respect the render cap (<=400)")
  end,
}

S.scenario{
  id = "SCN-JOURNEY", name = "Add/remove a Journey item round-trips", tags = { "overlay", "db" },
  run = function(t)
    local DB, O = TitanJourney_DB, TitanJourney_Overlay
    if not t.truthy(DB and DB.JourneyAdd, "DB journey ops available") then return end
    local probe = "Scenario Probe Item ZZZ"
    if DB.JourneyContains(probe) then DB.JourneyRemove(probe) end
    DB.JourneyAdd(probe)
    t.ok(DB.JourneyContains(probe), "probe added to the Journey list")
    t.step("render the Journey tab", function() if O and O.RenderJourney then O.RenderJourney() end end)
    DB.JourneyRemove(probe)
    t.ok(not DB.JourneyContains(probe), "probe removed again")
  end,
}

S.scenario{
  id = "SCN-SEARCH", name = "Browse search renders without error", tags = { "overlay" },
  teardown = function()
    if TitanJourney_Overlay then TitanJourney_Overlay.searchText = "" end
    closeOverlay()
  end,
  run = function(t)
    local O = TitanJourney_Overlay
    if not t.truthy(O and O.RenderBrowse, "RenderBrowse available") then return end
    openOverlay()
    O.searchText = "sword"
    t.step("render Browse with a query", function() O.RenderBrowse() end)
    O.searchText = ""
    t.step("render Browse cleared", function() O.RenderBrowse() end)
  end,
}

S.scenario{
  id = "SCN-GUIDE", name = "Class guide renders and subtabs toggle", tags = { "overlay" },
  teardown = closeOverlay,
  run = function(t)
    local O = TitanJourney_Overlay
    if not t.truthy(O and O.RenderGuide, "RenderGuide available") then return end
    openOverlay()
    t.step("render the guide", function() O.RenderGuide() end)
    t.step("weapons subtab", function() O.SelectGuideSubtab("weapons") end)
    t.eq(O.guideSubtab, "weapons", "weapons subtab active")
    t.step("armor subtab", function() O.SelectGuideSubtab("armor") end)
    t.eq(O.guideSubtab, "armor", "armor subtab active")
    t.step("toggle 'show all usable'", function() O.SetGuideShowAll(true); O.SetGuideShowAll(false) end)
  end,
}

S.scenario{
  id = "SCN-INSPECT", name = "Last Inspected tab renders empty state", tags = { "overlay" },
  teardown = closeOverlay,
  run = function(t)
    local O = TitanJourney_Overlay
    if not t.truthy(O and O.RenderInspect, "RenderInspect available") then return end
    openOverlay()
    t.step("render the inspect tab", function() O.RenderInspect() end)
  end,
}

S.scenario{
  id = "SCN-SETTINGS", name = "PvE/PvP mode setting persists", tags = { "db" },
  run = function(t)
    local DB = TitanJourney_DB
    if not t.truthy(DB and DB.SetMode, "DB mode setting available") then return end
    local prev = DB.Mode()
    DB.SetMode("pvp"); t.eq(DB.Mode(), "pvp", "mode set to pvp")
    DB.SetMode("pve"); t.eq(DB.Mode(), "pve", "mode set to pve")
    DB.SetMode(prev)   -- restore the player's real choice
  end,
}

-- ── Slash command ────────────────────────────────────────────────────────────
SLASH_TITANJOURNEY1 = "/titanjourney"
SLASH_TITANJOURNEY2 = "/tj"
SlashCmdList["TITANJOURNEY"] = function(msg)
  msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
  local cmd, rest = msg:match("^(%S*)%s*(.*)$")
  cmd = (cmd or ""):lower()
  rest = (rest ~= "" and rest) or nil

  if cmd == "run-testing-scenarios" or cmd == "run-scenarios"
     or cmd == "test" or cmd == "tests" or cmd == "scenarios" then
    S.Run(rest)
  elseif cmd == "" or cmd == "open" or cmd == "toggle" then
    if TitanJourney_Overlay then TitanJourney_Overlay.Toggle() end
  else
    out(col(GOLD, "TitanJourney commands:"))
    out("  " .. col(CYAN, "/titanjourney") .. " or " .. col(CYAN, "/tj")
      .. col(GRAY, "  -- open the Wishlist Manager"))
    out("  " .. col(CYAN, "/titanjourney run-testing-scenarios")
      .. col(GRAY, "  -- run the in-client behaviour tests"))
    out("  " .. col(GRAY, "    (optional: add a tag e.g. ")
      .. col(CYAN, "run-testing-scenarios overlay") .. col(GRAY, " to run a subset)"))
  end
end
