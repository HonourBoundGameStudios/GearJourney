-- JourneyOverlay -- the Wishlist Manager window (EPIC-C).
--
-- Frame/event code only: native Blizzard frame art (no custom textures). The
-- data shaping it displays comes from the pure engine (JourneyEngine.lua), so
-- this file stays thin. WoW-only; not loaded by the standalone tests.

local Overlay = {}
TitanJourney_Overlay = Overlay

local OVERLAY_NAME = "TitanJourneyOverlay"
local frame  -- created lazily on first toggle

-- Classic dialog look used only if BasicFrameTemplateWithInset is unavailable.
local FALLBACK_BACKDROP = {
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile = true, tileSize = 32, edgeSize = 32,
  insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

-- Sidebar tab definitions (FEAT-C3). Order is top-to-bottom.
local TABS = {
  { key = "current",  label = "Current Goals" },
  { key = "future",   label = "Future Planner" },
  { key = "settings", label = "Settings" },
}

-- SelectTab(key): mark one sidebar button active (locked highlight) and show
-- only its content panel. Safe to call before the layout exists.
function Overlay.SelectTab(key)
  Overlay.activeTab = key
  if not Overlay.tabButtons then return end
  for k, btn in pairs(Overlay.tabButtons) do
    if k == key then btn:LockHighlight() else btn:UnlockHighlight() end
  end
  for k, panel in pairs(Overlay.panels) do
    panel:SetShown(k == key)
  end
end

-- Build the left tab column and the matching content panels.
local function BuildLayout(f)
  Overlay.tabButtons = {}
  Overlay.panels = {}

  local SIDEBAR_W, TAB_H, TAB_GAP, TOP = 150, 34, 6, -34

  -- Content area: right of the sidebar. Panels stack here, one shown at a time.
  local content = CreateFrame("Frame", nil, f)
  content:SetPoint("TOPLEFT", f, "TOPLEFT", SIDEBAR_W + 24, TOP)
  content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 16)
  Overlay.content = content

  for i, tab in ipairs(TABS) do
    -- Sidebar button.
    local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btn:SetSize(SIDEBAR_W, TAB_H)
    btn:SetPoint("TOPLEFT", f, "TOPLEFT", 14, TOP - (i - 1) * (TAB_H + TAB_GAP))
    btn:SetText(tab.label)
    btn:SetScript("OnClick", function() Overlay.SelectTab(tab.key) end)
    Overlay.tabButtons[tab.key] = btn

    -- Matching content panel with a header; body filled in by later items.
    local panel = CreateFrame("Frame", nil, content)
    panel:SetAllPoints(content)

    local header = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetText(tab.label)

    local body = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    body:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -12)
    body:SetText("(coming soon)")

    Overlay.panels[tab.key] = panel
  end

  Overlay.SelectTab(Overlay.activeTab or "current")
end

-- Build the window once, preferring the native inset template and degrading to
-- a hand-backdropped frame so a missing template can never blank the screen.
local function CreateOverlay()
  if frame then return frame end

  local ok, f = pcall(CreateFrame, "Frame", OVERLAY_NAME, UIParent, "BasicFrameTemplateWithInset")
  if not ok or not f then
    f = CreateFrame("Frame", OVERLAY_NAME, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    if f.SetBackdrop then f:SetBackdrop(FALLBACK_BACKDROP) end
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
  end

  f:SetSize(720, 480)
  f:SetPoint("CENTER")
  f:SetFrameStrata("HIGH")
  f:SetToplevel(true)
  f:SetClampedToScreen(true)

  -- Title: template exposes a fontstring; fall back to a global lookup / our own.
  local title = f.TitleText or _G[OVERLAY_NAME .. "TitleText"]
  if not title then
    title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -8)
  end
  title:SetText("Journey Wishlist Manager")

  -- Draggable by the title bar.
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMoving)

  -- Close with Escape like a standard panel.
  tinsert(UISpecialFrames, OVERLAY_NAME)

  BuildLayout(f)

  f:Hide()
  frame = f
  return frame
end

-- Public: flip the window open/closed (wired to the Titan button's left-click).
function Overlay.Toggle()
  CreateOverlay()
  if frame:IsShown() then frame:Hide() else frame:Show() end
end
