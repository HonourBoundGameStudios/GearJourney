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

  f:Hide()
  frame = f
  return frame
end

-- Public: flip the window open/closed (wired to the Titan button's left-click).
function Overlay.Toggle()
  CreateOverlay()
  if frame:IsShown() then frame:Hide() else frame:Show() end
end
