-- Headless smoke test for the floating pill (EPIC-L / FLOAT-2..5 wiring).
-- Loads the REAL chain (LibStub -> LDB -> Engine/Host/DB/GearJourney) and then
-- JourneyFloatButton.lua under a minimal WoW-API stub, and asserts the frame
-- wiring: the pill loads without error, mirrors the published LDB object, routes
-- clicks + tooltip through it, builds its right-click menu, round-trips its saved
-- position, and honours the hidden-by-default / show-hide toggle. Pixels (fonts,
-- icon art, on-screen placement) still need the in-client eye-verify -- this
-- proves the Lua wiring loads and behaves. Run from root:
--   lua Tests/journey_float_smoke_test.lua

local H = dofile("Tests/harness.lua")

-- Minimal WoW API stub --------------------------------------------------------
local frames = {}

local function newRegion()
  local r = {}
  function r:SetSize() end
  function r:SetPoint() end
  function r:SetTexture(t) self.texture = t end
  function r:SetJustifyH() end
  function r:SetText(s) self.value = s end
  function r:GetStringWidth() return 100 end   -- fixed so Layout is deterministic
  return r
end

function CreateFrame(_, name, _, _)
  local f = { name = name, events = {}, scripts = {}, points = {}, shown = true }
  function f:SetHeight(h) self.h = h end
  function f:SetWidth(w) self.w = w end
  function f:GetWidth() return self.w or 0 end
  function f:GetHeight() return self.h or 0 end
  function f:SetFrameStrata() end
  function f:SetBackdrop() end
  function f:SetBackdropColor() end
  function f:SetMovable() end
  function f:RegisterForDrag() end
  function f:RegisterForClicks() end
  function f:StartMoving() end
  function f:StopMovingOrSizing() end
  function f:ClearAllPoints() self.points = {} end
  function f:SetPoint(pt, _, _, x, y) self.points[#self.points + 1] = { pt, x, y } end
  function f:GetCenter() return self.cx, self.cy end
  function f:Show() self.shown = true end
  function f:Hide() self.shown = false end
  function f:RegisterEvent(e) self.events[e] = true end
  function f:SetScript(k, fn) self.scripts[k] = fn end
  function f:CreateTexture() return newRegion() end
  function f:CreateFontString() return newRegion() end
  frames[#frames + 1] = f
  return f
end

StaticPopupDialogs = {}
OKAY = "Okay"
C_AddOns = { GetAddOnMetadata = function() return "smoke" end }
securecallfunction = function(fn, ...) return fn(...) end
geterrorhandler = function() return function(err) error(err, 2) end end

H.start("Floating pill wiring (headless smoke)")

-- Load the real chain in .toc order, then the float last (as the .toc lists it).
dofile("Libs/LibStub.lua")
dofile("Libs/CallbackHandler-1.0.lua")
dofile("Libs/LibDataBroker-1.1.lua")
dofile("JourneyEngine.lua")
dofile("JourneyHost.lua")
dofile("JourneyDB.lua")
dofile("GearJourney.lua")

-- UIParent needs real geometry for the clamp math; centre it on a 1920x1080 screen.
UIParent = CreateFrame("Frame")
UIParent.w, UIParent.h, UIParent.cx, UIParent.cy = 1920, 1080, 960, 540

local boundary = #frames          -- float frames are the ones created after here
dofile("JourneyFloatButton.lua")

-- Identify the float's frames.
local bar
for _, f in ipairs(frames) do if f.name == "GearJourneyFloatButton" then bar = f end end
H.ok(bar ~= nil, "the pill frame is created and named GearJourneyFloatButton")

local placer
for i = boundary + 1, #frames do
  if frames[i].events["PLAYER_ENTERING_WORLD"] then placer = frames[i] end
end
H.ok(placer ~= nil, "a float frame watches PLAYER_ENTERING_WORLD")

-- FLOAT-5: hidden by default (opt-in) -- the pill is Hide()'d at file load.
H.eq(bar.shown, false, "pill is hidden at load (opt-in default)")

-- FLOAT-2/3: the pill mirrors the published LDB object. Drive a refresh and
-- confirm the attribute-changed callback repaints the pill's text.
local obj = LibStub("LibDataBroker-1.1", true):GetDataObjectByName("GearJourney")
GearJourney_Overlay = {
  ComputeList = function() return { { name = "Blade of Verifying", reqLevel = 20 } }, 10 end,
  PlayerOwnsFn = function() return function() return false end end,
  JourneyItems = function() return {}, 10 end,
  Toggle = function() end,
}
GearJourney_RefreshButton()
H.ok(bar.scripts.OnClick ~= nil, "pill has an OnClick handler")
-- Apply() writes "<label>: <text>"; the published object carries that live goal.
H.eq(obj.text, "Blade of Verifying (Lv. 20) - In 10 Levels",
  "published object carries the live goal the pill mirrors")

-- FLOAT-3: left-click routes through the published object's OnClick (opens mgr).
local toggled = false
GearJourney_Overlay.Toggle = function() toggled = true end
bar.scripts.OnClick(bar, "LeftButton")
H.ok(toggled, "left-click routes through dataObj.OnClick (opens the manager)")

-- FLOAT-3: hovering builds the tooltip through the object's OnTooltipShow.
local tipLines = {}
GameTooltip = {
  SetOwner = function() end, SetPoint = function() end,
  Show = function() end, Hide = function() end,
  AddLine = function(_, s) tipLines[#tipLines + 1] = s end,
}
bar.scripts.OnEnter(bar)
H.eq(tipLines[1], "Gear Journey", "hover renders the shared tooltip (titled once)")

-- FLOAT-5: right-click builds the pill's menu -- the shared entries plus the
-- float-only "Lock position", reachable alongside "Show Gear Journey bar".
local menuLabels = {}
local rootStub = {
  CreateTitle = function(_, s) menuLabels[#menuLabels + 1] = s end,
  CreateButton = function(_, s) menuLabels[#menuLabels + 1] = s end,
  CreateCheckbox = function(_, s) menuLabels[#menuLabels + 1] = s end,
}
MenuUtil = { CreateContextMenu = function(self, fn) fn(self, rootStub) end }
bar.scripts.OnClick(bar, "RightButton")
local sawLock, sawShow = false, false
for _, s in ipairs(menuLabels) do
  if s == "Lock position" then sawLock = true end
  if s == "Show Gear Journey bar" then sawShow = true end
end
H.ok(sawShow, "menu offers 'Show Gear Journey bar' (shared entry)")
H.ok(sawLock, "menu offers 'Lock position' (float-only entry)")

-- FLOAT-4: drag-to-move persistence round-trips through DB.Float() with a clamp.
-- Drop the pill 300px right / 100px up of centre; the saved offset must match.
bar.cx, bar.cy = 960 + 300, 540 + 100
GearJourney_FloatSavePosition()
local f = GearJourney_DB.Float()
H.eq(f.point, "CENTER", "saved anchor is CENTER")
H.eq(f.x, 300, "saved x is the dropped offset")
H.eq(f.y, 100, "saved y is the dropped offset")

-- FLOAT-4: an off-screen saved spot is clamped back on login, never off the edge.
f.x, f.y = 99999, 99999
placer.scripts.OnEvent(placer, "PLAYER_ENTERING_WORLD")
local last = bar.points[#bar.points]
H.ok(last ~= nil and last[2] <= 895 and last[3] <= 530,
  "login clamps an off-screen saved spot back on-screen")

-- FLOAT-4/5: drag is refused while locked (no StartMoving path taken).
f.locked = true
local moved = false
bar.StartMoving = function() moved = true end
bar.scripts.OnDragStart(bar)
H.ok(not moved, "locked pill refuses to start moving")
f.locked = false

-- FLOAT-5: show/hide toggle drives both the frame and the persisted flag.
GearJourney_FloatSetShown(true)
H.eq(bar.shown, true, "show toggle shows the pill")
H.eq(GearJourney_DB.Float().hidden, false, "show toggle clears the persisted hidden flag")
H.ok(GearJourney_FloatShown(), "FloatShown() reports visible")
GearJourney_FloatSetShown(false)
H.eq(bar.shown, false, "hide toggle hides the pill")
H.eq(GearJourney_DB.Float().hidden, true, "hide toggle sets the persisted hidden flag")

H.done()
