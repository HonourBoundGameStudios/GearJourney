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

-- Talent-tree background base names per class, in talent-tab order (1..3).
-- Textures live at Interface\TalentFrame\<base>-{TopLeft,TopRight,BottomLeft,
-- BottomRight}. We pick the tab with the most points (the player's spec) and
-- fall back to tab 1; an unknown class or missing texture leaves the dark inset.
local CLASS_TALENT_BG = {
  WARRIOR = { "WarriorArms", "WarriorFury", "WarriorProtection" },
  PALADIN = { "PaladinHoly", "PaladinProtection", "PaladinCombat" },
  HUNTER  = { "HunterBeastMastery", "HunterMarksmanship", "HunterSurvival" },
  ROGUE   = { "RogueAssassination", "RogueCombat", "RogueSubtlety" },
  PRIEST  = { "PriestDiscipline", "PriestHoly", "PriestShadow" },
  SHAMAN  = { "ShamanElementalCombat", "ShamanEnhancement", "ShamanRestoration" },
  MAGE    = { "MageArcane", "MageFire", "MageFrost" },
  WARLOCK = { "WarlockCurses", "WarlockSummoning", "WarlockDestruction" },
  DRUID   = { "DruidBalance", "DruidFeralCombat", "DruidRestoration" },
}

-- Pick the background base name for the player's class and most-spent spec.
local function PlayerTalentBackground()
  local _, class = UnitClass("player")
  local set = class and CLASS_TALENT_BG[class]
  if not set then return nil end

  local idx, best = 1, -1
  if GetNumTalentTabs and GetTalentTabInfo then
    local n = GetNumTalentTabs() or 0
    for i = 1, math.min(n, #set) do
      local _, _, pointsSpent = GetTalentTabInfo(i)
      pointsSpent = tonumber(pointsSpent) or 0
      if pointsSpent > best then best, idx = pointsSpent, i end
    end
  end
  return set[idx]
end

-- The player's spec = the talent tab with the most points (default 1).
local function PlayerSpecIndex()
  local idx, best = 1, -1
  if GetNumTalentTabs and GetTalentTabInfo then
    local n = GetNumTalentTabs() or 0
    for i = 1, n do
      local _, _, pts = GetTalentTabInfo(i)
      pts = tonumber(pts) or 0
      if pts > best then best, idx = pts, i end
    end
  end
  return idx
end

-- Paint the class talent background to fill the whole window, dimmed, on the
-- BACKGROUND layer (sidebar + item rows draw above it). The composite art is a
-- 384x384 image split at 2/3 (TopLeft 256, right/bottom strips 128), so each
-- quadrant is scaled uniformly to preserve aspect; the square is sized to cover
-- the window's larger dimension and the overflow is clipped. Falls back to a
-- letterboxed fit if clipping is unavailable, and to the dark inset for an
-- unknown class / missing texture.
local function ApplyClassBackground(f)
  local base = PlayerTalentBackground()
  if not base then return end
  local prefix = "Interface\\TalentFrame\\" .. base .. "-"

  -- Interior, below the title bar; these offsets define the usable W x H.
  local L, T, R, B = 8, -28, -8, -8
  local holder = CreateFrame("Frame", nil, f)
  holder:SetPoint("TOPLEFT", f, "TOPLEFT", L, T)
  holder:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", R, B)
  -- Draw above the template's dark inset background; BuildLayout raises the
  -- sidebar/content further so item rows still sit on top of the art.
  holder:SetFrameLevel(f:GetFrameLevel() + 5)
  if holder.SetClipsChildren then holder:SetClipsChildren(true) end
  Overlay.bg = holder
  Overlay.bgLevel = holder:GetFrameLevel()

  local W = f:GetWidth() + R - L    -- R is negative (inset from right)
  local H = f:GetHeight() + T + B   -- T and B are negative (insets)
  local S = math.max(W, H)          -- cover the larger dimension

  -- The composite art sits on a square canvas, centred and clipped by holder,
  -- so it covers the window while preserving aspect (overflow cropped). The
  -- canvas is a child *frame*, which SetClipsChildren actually clips (textures
  -- drawn straight on a frame are not clipped).
  local canvas = CreateFrame("Frame", nil, holder)
  canvas:SetSize(S, S)
  canvas:SetPoint("CENTER", holder, "CENTER")

  local seam = S * (256 / 384)              -- the 2/3 split
  local lw, rw = seam, S - seam
  local th, bh = seam, S - seam

  local function quad(suffix, x, yDown, w, h)
    local t = canvas:CreateTexture(nil, "BACKGROUND")
    t:SetTexture(prefix .. suffix)   -- bad path simply draws nothing
    t:SetAlpha(0.42)                 -- dim so text stays readable
    t:SetPoint("TOPLEFT", canvas, "TOPLEFT", x, -yDown)
    t:SetSize(w, h)
    return t
  end

  Overlay.bgTextures = {
    quad("TopLeft",     0,    0,    lw, th),
    quad("TopRight",    lw,   0,    rw, th),
    quad("BottomLeft",  0,    th,   lw, bh),
    quad("BottomRight", lw,   th,   rw, bh),
  }
end

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

-- Item-row visuals (FEAT-C4/C5). ------------------------------------------

local ROW_H, ICON = 42, 32

local QUALITY_COLOR = {
  poor     = { 0.62, 0.62, 0.62 },
  common   = { 1.00, 1.00, 1.00 },
  uncommon = { 0.12, 1.00, 0.00 },
  rare     = { 0.00, 0.44, 0.87 },
  epic     = { 0.64, 0.21, 0.93 },
}

-- Colour the required-level text by reachability relative to the player.
local function LevelColor(req, playerLevel, hi)
  if req <= playerLevel then return 0.25, 0.75, 0.25      -- usable now (green)
  elseif req <= hi then     return 0.95, 0.75, 0.20       -- in window (gold)
  else                      return 0.80, 0.25, 0.20 end   -- beyond  (red)
end

local function SetSolid(tex, r, g, b)
  if tex.SetColorTexture then tex:SetColorTexture(r, g, b)
  else tex:SetTexture("Interface\\Buttons\\WHITE8x8"); tex:SetVertexColor(r, g, b) end
end

-- One pooled item row: quality-bordered icon, name, slot/source line, level.
local function CreateRow(parent)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(ROW_H)

  row.border = row:CreateTexture(nil, "ARTWORK")
  row.border:SetSize(ICON + 4, ICON + 4)
  row.border:SetPoint("LEFT", 2, 0)

  row.icon = row:CreateTexture(nil, "OVERLAY")
  row.icon:SetSize(ICON, ICON)
  row.icon:SetPoint("CENTER", row.border, "CENTER")

  row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.name:SetPoint("TOPLEFT", row.border, "TOPRIGHT", 10, -1)
  row.name:SetJustifyH("LEFT")

  row.sub = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  row.sub:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
  row.sub:SetJustifyH("LEFT")

  row.pin = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
  row.pin:SetSize(58, 20)
  row.pin:SetPoint("RIGHT", -8, 0)

  row.level = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.level:SetPoint("RIGHT", row.pin, "LEFT", -12, 0)
  return row
end

local function FillRow(row, item, playerLevel, hi)
  local qc = QUALITY_COLOR[item.quality] or QUALITY_COLOR.common
  SetSolid(row.border, qc[1], qc[2], qc[3])
  -- Real item icon once enriched (FEAT-E2); paper-doll slot art as a fallback.
  row.icon:SetTexture(item.icon or ("Interface\\PaperDoll\\UI-PaperDoll-Slot-" .. (item.slot or "Chest")))
  row.name:SetText(item.name)
  row.name:SetTextColor(qc[1], qc[2], qc[3])
  local line = (item.slot or "") .. "   " .. (item.sourceType or "") .. ": " .. (item.sourceLabel or "")
  local summary = TitanJourney_Engine and TitanJourney_Engine.StatSummary(item.stats) or ""
  if summary ~= "" then line = line .. "   |cff9d9d9d" .. summary .. "|r" end
  row.sub:SetText(line)
  row.level:SetText("Lv " .. item.reqLevel)
  row.level:SetTextColor(LevelColor(item.reqLevel, playerLevel, hi))

  -- Pin toggle (FEAT-C7): one pinned item, surfaced on the Titan button.
  local pinned = TitanJourney_DB and TitanJourney_DB.Pin() == item.name
  row.pin:SetText(pinned and "Pinned" or "Pin")
  row.pin:SetScript("OnClick", function()
    if TitanJourney_DB then TitanJourney_DB.TogglePin(item.name) end
    if TitanPanelButton_UpdateButton then TitanPanelButton_UpdateButton("Journey") end
    Overlay.RenderCurrentGoals()
  end)
end

-- Render one list tab (key = "current" or "future") into its panel, spec-scored.
function Overlay.RenderTab(key)
  local panel = Overlay.panels and Overlay.panels[key]
  if not panel or not panel.listAnchor then return end
  local engine, items = TitanJourney_Engine, TitanJourney_Items
  if not (engine and items) then return end

  local level = (UnitLevel and UnitLevel("player")) or 1
  local _, class = UnitClass("player")
  local range = engine.DEFAULT_RANGE
  local hi = level + range
  local mode = TitanJourney_DB and TitanJourney_DB.Mode() or "pve"
  local weights = engine.WeightsFor(class, PlayerSpecIndex(), mode)

  local cur, fut = engine.SplitGoals(engine.FilterByClass(items, class), level, range)
  local list = cur
  if key == "future" then
    -- Plan the next stretch, not end-game: cap a band above the window.
    local cap = hi + 20
    list = {}
    for i = 1, #fut do if fut[i].reqLevel <= cap then list[#list + 1] = fut[i] end end
  end
  list = engine.BestPerSlotScored(list, weights)

  panel.rows = panel.rows or {}
  local y = -4
  for i, item in ipairs(list) do
    local row = panel.rows[i]
    if not row then
      row = CreateRow(panel.listAnchor)
      panel.rows[i] = row
    end
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", panel.listAnchor, "TOPLEFT", 0, y)
    row:SetPoint("RIGHT", panel.listAnchor, "RIGHT", 0, 0)
    FillRow(row, item, level, hi)
    row:Show()
    y = y - (ROW_H + 4)
  end
  for i = #list + 1, #panel.rows do panel.rows[i]:Hide() end

  -- Size the scroll child so the scrollbar/clipping cover all rows.
  local childW = (panel.scroll and panel.scroll:GetWidth()) or 0
  if childW < 10 then childW = 500 end
  panel.listAnchor:SetWidth(childW)
  panel.listAnchor:SetHeight(math.max(1, #list * (ROW_H + 4) + 8))

  panel.empty:SetShown(#list == 0)
  if key == "future" then
    panel.sub:SetText(#list > 0 and ("Level " .. (hi + 1) .. " and up") or "")
  else
    panel.sub:SetText(#list > 0 and ("Levels " .. level .. " \226\128\147 " .. hi) or "")
  end
end

-- Refresh both list tabs (called by the provider and on open).
function Overlay.RenderCurrentGoals()
  Overlay.RenderTab("current")
  Overlay.RenderTab("future")
end

-- Build the left tab column and the matching content panels.
local function BuildLayout(f)
  Overlay.tabButtons = {}
  Overlay.panels = {}

  local SIDEBAR_W, TAB_H, TAB_GAP, TOP = 150, 34, 6, -34

  -- Class-flavoured backdrop filling the window (FEAT-C: talent-tree art).
  -- Built first so it sits behind the sidebar and content.
  ApplyClassBackground(f)

  -- Everything interactive must sit above the talent-art backdrop.
  local topLevel = (Overlay.bgLevel or f:GetFrameLevel()) + 5

  -- Content area: right of the sidebar. Panels stack here, one shown at a time.
  local content = CreateFrame("Frame", nil, f)
  content:SetPoint("TOPLEFT", f, "TOPLEFT", SIDEBAR_W + 24, TOP)
  content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 16)
  content:SetFrameLevel(topLevel)
  Overlay.content = content

  for i, tab in ipairs(TABS) do
    -- Sidebar button.
    local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btn:SetSize(SIDEBAR_W, TAB_H)
    btn:SetFrameLevel(topLevel)
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

    if tab.key ~= "settings" then
      -- Subtitle, a scrolling list, and an empty-state line (FEAT-C5/C6).
      local sub = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      sub:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -3)
      panel.sub = sub

      -- ScrollFrame clips the rows to the window and gives a scrollbar; the rows
      -- live on its scroll child so there can be far more than fit on screen.
      local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
      scroll:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -10)
      scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -26, 4)
      scroll:EnableMouseWheel(true)
      scroll:SetScript("OnMouseWheel", function(self, delta)
        local step = (ROW_H + 4) * 3
        local v = self:GetVerticalScroll() - delta * step
        v = math.max(0, math.min(v, self:GetVerticalScrollRange()))
        self:SetVerticalScroll(v)
      end)
      panel.scroll = scroll

      local child = CreateFrame("Frame", nil, scroll)
      child:SetSize(1, 1)
      scroll:SetScrollChild(child)
      panel.listAnchor = child

      local empty = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
      empty:SetPoint("TOPLEFT", scroll, "TOPLEFT", 2, -4)
      empty:SetText("No items in range for your class.")
      empty:Hide()
      panel.empty = empty
    else
      local body = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
      body:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -12)
      body:SetText("(coming soon)")
    end

    Overlay.panels[tab.key] = panel
  end

  Overlay.RenderCurrentGoals()
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
  -- NB: the stop method is StopMovingOrSizing -- there is no Frame:StopMoving,
  -- so wiring f.StopMoving (nil) left the window stuck to the cursor.
  f:SetScript("OnDragStop", f.StopMovingOrSizing)

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
  if frame:IsShown() then
    frame:Hide()
  else
    frame:Show()
    Overlay.RenderCurrentGoals()  -- after Show so scroll widths are valid
  end
end
