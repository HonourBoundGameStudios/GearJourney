-- Headless smoke test for the LDB host chain (EPIC-K / IND-7 functional ACs).
-- Loads the REAL libraries (LibStub -> CallbackHandler -> LibDataBroker) and the
-- real Engine/DB/Host/shim under a minimal WoW-API stub, then asserts the data
-- object publishes, refreshes, tooltips, and click-routes. Pixels (fonts, icons,
-- bar placement) still need the in-client eye-verify -- this proves the wiring.
-- Run from project root: lua Tests/journey_ldb_smoke_test.lua

local H = dofile("Tests/harness.lua")

-- Minimal WoW API stub --------------------------------------------------------
local frames = {}
function CreateFrame()
  local f = { events = {}, scripts = {} }
  function f:RegisterEvent(e) self.events[e] = true end
  function f:SetScript(k, fn) self.scripts[k] = fn end
  frames[#frames + 1] = f
  return f
end
StaticPopupDialogs = {}
OKAY = "Okay"
C_AddOns = { GetAddOnMetadata = function() return "smoke" end }
-- CallbackHandler dispatches through WoW's secure-call wrappers.
securecallfunction = function(fn, ...) return fn(...) end
geterrorhandler = function() return function(err) error(err, 2) end end

H.start("LDB host chain (headless smoke)")

-- Load the real chain in .toc order --------------------------------------------
dofile("Libs/LibStub.lua")
dofile("Libs/CallbackHandler-1.0.lua")
dofile("Libs/LibDataBroker-1.1.lua")
dofile("JourneyEngine.lua")
dofile("JourneyHost.lua")
dofile("JourneyDB.lua")
dofile("TitanJourney.lua")

-- IND-2 AC (headless analog of /dump): the lib is reachable through LibStub.
local ldb = LibStub("LibDataBroker-1.1", true)
H.ok(ldb ~= nil, "LibStub serves LibDataBroker-1.1")

-- IND-3: the data object exists with the spec'd shape.
local obj = ldb:GetDataObjectByName("GearJourney")
H.ok(obj ~= nil, "data object 'GearJourney' is published")
H.eq(obj.type, "data source", "type is a spec'd LDB data source")
H.ok(obj.icon ~= nil, "icon set")
H.eq(type(obj.OnClick), "function", "OnClick declared")
H.eq(type(obj.OnTooltipShow), "function", "OnTooltipShow declared")

-- IND-3: refresh with no engine data falls back to the placeholder.
TitanJourney_RefreshButton()
H.eq(obj.text, "\226\128\148", "refresh without overlay -> em-dash placeholder")

-- IND-3: with a (stub) overlay the REAL BuildButtonText drives obj.text.
TitanJourney_Overlay = {
  ComputeList = function() return { { name = "Sword of Testing", reqLevel = 12 } }, 10 end,
  PlayerOwnsFn = function() return function() return false end end,
  JourneyItems = function() return {}, 10 end,
}
TitanJourney_RefreshButton()
H.eq(obj.text, "Sword of Testing (Lv. 12) - In 2 Levels",
  "refresh publishes the engine's next-goal text")

-- LDB contract: writing .text fired the attribute callback displays subscribe to.
local fired = {}
ldb.RegisterCallback({}, "LibDataBroker_AttributeChanged", function(_, name, key)
  fired[#fired + 1] = name .. "." .. key
end)
TitanJourney_Overlay.ComputeList = function()
  return { { name = "Axe of Later", reqLevel = 14 } }, 10
end
TitanJourney_RefreshButton()
H.eq(fired[#fired], "GearJourney.text", "text write fires the display callback")

-- IND-3: tooltip body renders through a display-supplied tooltip frame.
local lines = {}
local tip = { AddLine = function(_, s) lines[#lines + 1] = s end }
obj.OnTooltipShow(tip)
H.eq(lines[1], "Gear Journey", "tooltip titled")
local sawEmpty = false
for _, s in ipairs(lines) do
  if s:find("Journey List is empty") then sawEmpty = true end
end
H.ok(sawEmpty, "tooltip body comes from the real GetTooltipText")

-- IND-3/4: click routing -- LeftButton toggles the manager; RightButton without
-- MenuUtil (Classic-safe guard) is a no-op, not an error.
local toggled = false
TitanJourney_Overlay.Toggle = function() toggled = true end
obj.OnClick(nil, "LeftButton")
H.ok(toggled, "LeftButton opens the manager")
obj.OnClick(nil, "RightButton")
H.ok(true, "RightButton without MenuUtil is guarded (no error)")

-- IND-5: first PLAYER_ENTERING_WORLD registers the minimap launcher (guarded
-- when LibDBIcon is absent) and refreshes -- the whole handler must not error.
local watcher
for _, f in ipairs(frames) do
  if f.events["PLAYER_ENTERING_WORLD"] then watcher = f end
end
H.ok(watcher ~= nil, "a frame watches PLAYER_ENTERING_WORLD")
watcher.scripts.OnEvent(watcher, "PLAYER_ENTERING_WORLD")
H.eq(obj.text, "Axe of Later (Lv. 14) - In 4 Levels",
  "login event refreshes the button text")
H.eq(TitanJourney_DB.Minimap().hide, false, "minimap state initialised (shown, no Titan)")

H.done()
