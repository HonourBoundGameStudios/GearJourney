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
  { key = "browse",   label = "Browse" },
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

-- Returns a predicate: does the player already own this itemID? Checks equipped
-- slots plus bags and bank (GetItemCount). Snapshots equipped once per call.
function Overlay.PlayerOwnsFn()
  local equipped = {}
  if GetInventoryItemID then
    for slot = 1, 19 do
      local id = GetInventoryItemID("player", slot)
      if id then equipped[id] = true end
    end
  end
  return function(itemID)
    if not itemID then return false end
    if equipped[itemID] then return true end
    return (GetItemCount and GetItemCount(itemID, true) or 0) > 0  -- bags + bank
  end
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
  -- The source/lookahead bar applies to the list tabs only.
  if Overlay.controlBar then Overlay.controlBar:SetShown(key ~= "settings") end
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

-- Row tooltip (FEAT-C10) with SHIFT-to-compare against equipped gear.
local hoverOwner, hoverItemID
local function ShowRowTooltip(owner, itemID)
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:SetHyperlink("item:" .. itemID)
  if IsShiftKeyDown() and GameTooltip_ShowCompareItem then GameTooltip_ShowCompareItem() end
  GameTooltip:Show()
end

-- Holding/releasing SHIFT while hovering re-shows the tooltip with comparison.
local modWatcher = CreateFrame("Frame")
modWatcher:RegisterEvent("MODIFIER_STATE_CHANGED")
modWatcher:SetScript("OnEvent", function(_, _, key)
  if hoverItemID and (key == "LSHIFT" or key == "RSHIFT") then
    ShowRowTooltip(hoverOwner, hoverItemID)
  end
end)

-- One pooled item row: quality-bordered icon, name, slot/source line, level.
local function CreateRow(parent)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(ROW_H)

  row:EnableMouse(true)
  row:SetScript("OnEnter", function(self)
    if not self.itemID then return end
    hoverOwner, hoverItemID = self, self.itemID
    ShowRowTooltip(self, self.itemID)
  end)
  row:SetScript("OnLeave", function() hoverItemID = nil; GameTooltip:Hide() end)

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

  row.action = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
  row.action:SetSize(58, 20)
  row.action:SetPoint("RIGHT", -8, 0)

  -- Reorder buttons (shown only in the Journey List).
  row.down = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
  row.down:SetSize(20, 18); row.down:SetText("v")
  row.down:SetPoint("RIGHT", row.action, "LEFT", -4, 0)
  row.up = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
  row.up:SetSize(20, 18); row.up:SetText("^")
  row.up:SetPoint("RIGHT", row.down, "LEFT", -2, 0)
  row.up:Hide(); row.down:Hide()

  row.level = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.level:SetPoint("RIGHT", row.action, "LEFT", -12, 0)
  return row
end

local function FillRow(row, item, playerLevel, hi)
  row.itemID = item.itemID  -- for the hover tooltip (FEAT-C10)
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
end

-- Refresh the Titan button + both list views after a Journey-List change.
local function RefreshAll()
  if TitanPanelButton_UpdateButton then TitanPanelButton_UpdateButton("Journey") end
  Overlay.RenderCurrentGoals()
end

-- Configure a row's right-side action. "add" toggles Journey-List membership
-- (selector / future); "journey" shows Remove + up/down reorder.
local function ConfigRowAction(row, item, mode)
  if mode == "journey" then
    row.up:Show(); row.down:Show(); row.level:Hide()
    row.action:SetWidth(24); row.action:SetText("X")
    row.action:SetScript("OnClick", function()
      if TitanJourney_DB then TitanJourney_DB.JourneyRemove(item.name) end
      RefreshAll()
    end)
    row.up:SetScript("OnClick", function()
      if TitanJourney_DB then TitanJourney_DB.JourneyMove(item.name, -1) end
      RefreshAll()
    end)
    row.down:SetScript("OnClick", function()
      if TitanJourney_DB then TitanJourney_DB.JourneyMove(item.name, 1) end
      RefreshAll()
    end)
  else
    row.up:Hide(); row.down:Hide(); row.level:Show()
    row.level:ClearAllPoints(); row.level:SetPoint("RIGHT", row.action, "LEFT", -12, 0)
    row.action:SetWidth(58)
    local on = TitanJourney_DB and TitanJourney_DB.JourneyContains(item.name)
    row.action:SetText(on and "On List" or "Add")
    row.action:SetScript("OnClick", function()
      if TitanJourney_DB then TitanJourney_DB.JourneyToggle(item.name) end
      RefreshAll()
    end)
  end
end

-- Create a scrolling list (caller anchors it); returns scroll, child.
local function MakeScroll(parent)
  local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, delta)
    local step = (ROW_H + 4) * 3
    local v = self:GetVerticalScroll() - delta * step
    v = math.max(0, math.min(v, self:GetVerticalScrollRange()))
    self:SetVerticalScroll(v)
  end)
  local child = CreateFrame("Frame", nil, scroll)
  child:SetSize(1, 1)
  scroll:SetScrollChild(child)
  return scroll, child
end

-- Render a list into a scroll child, pooling rows in `pool`.
local function RenderRowsInto(scroll, anchor, pool, list, level, hi, mode)
  local y = -4
  for i, item in ipairs(list) do
    local row = pool[i]
    if not row then row = CreateRow(anchor); pool[i] = row end
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, y)
    row:SetPoint("RIGHT", anchor, "RIGHT", 0, 0)
    FillRow(row, item, level, hi)
    ConfigRowAction(row, item, mode)
    row:Show()
    y = y - (ROW_H + 4)
  end
  for i = #list + 1, #pool do pool[i]:Hide() end
  local w = (scroll and scroll:GetWidth()) or 0
  if w < 10 then w = 280 end
  anchor:SetWidth(w)
  anchor:SetHeight(math.max(1, #list * (ROW_H + 4) + 8))
end

-- ComputeList(bucket) -> list, level, hi
--   The spec-scored, best-per-slot suggestions for "current" or "future".
--   Shared by the overlay and the Titan button so they never disagree (Bug 3).
function Overlay.ComputeList(bucket)
  local engine, items = TitanJourney_Engine, TitanJourney_Items
  local level = (UnitLevel and UnitLevel("player")) or 1
  if not (engine and items) then return {}, level, level end
  local _, class = UnitClass("player")
  local range = (TitanJourney_DB and TitanJourney_DB.Lookahead()) or engine.DEFAULT_RANGE
  local hi = level + range
  local mode = TitanJourney_DB and TitanJourney_DB.Mode() or "pve"
  local weights = engine.WeightsFor(class, PlayerSpecIndex(), mode)

  -- Filter by enabled sources, usable-by-class, drop owned, drop healing-only
  -- gear for caster DPS.
  local enabled = TitanJourney_DB and TitanJourney_DB.Sources()
  local usable = engine.FilterOwned(
    engine.FilterByClass(engine.FilterBySource(items, enabled), class, level),
    Overlay.PlayerOwnsFn())
  usable = engine.RejectHealingForDPS(usable, engine.IsCasterDPS(class, PlayerSpecIndex()))
  local cur, fut = engine.SplitGoals(usable, level, range)
  local list = cur
  if bucket == "future" then
    -- Plan the next stretch, not end-game: cap a band above the window.
    local cap = hi + 20
    list = {}
    for i = 1, #fut do if fut[i].reqLevel <= cap then list[#list + 1] = fut[i] end end
  end
  return engine.BestPerSlotScored(list, weights), level, hi
end

-- ComputeCandidates(slot) -> list, level, hi. The Selector's gear: usable, not
-- owned, within reach (reqLevel <= level+lookahead), optional slot, best-first.
function Overlay.ComputeCandidates(slot)
  local engine, items = TitanJourney_Engine, TitanJourney_Items
  local level = (UnitLevel and UnitLevel("player")) or 1
  if not (engine and items) then return {}, level, level end
  local _, class = UnitClass("player")
  local range = (TitanJourney_DB and TitanJourney_DB.Lookahead()) or engine.DEFAULT_RANGE
  local hi = level + range
  local spec = PlayerSpecIndex()
  local weights = engine.WeightsFor(class, spec, TitanJourney_DB and TitanJourney_DB.Mode() or "pve")
  local enabled = TitanJourney_DB and TitanJourney_DB.Sources()
  local usable = engine.FilterOwned(
    engine.FilterByClass(engine.FilterBySource(items, enabled), class, level),
    Overlay.PlayerOwnsFn())
  usable = engine.RejectHealingForDPS(usable, engine.IsCasterDPS(class, spec))

  local cands = {}
  for i = 1, #usable do
    local it = usable[i]
    if it.reqLevel <= hi and (slot == "all" or it.slot == slot) then cands[#cands + 1] = it end
  end
  table.sort(cands, function(a, b)
    local sa, sb = engine.ScoreItem(a, weights), engine.ScoreItem(b, weights)
    if sa ~= sb then return sa > sb end
    return (a.reqLevel or 0) < (b.reqLevel or 0)
  end)
  return cands, level, hi
end

-- JourneyItems() -> list, level. The saved Journey List resolved to items, in order.
function Overlay.JourneyItems()
  local engine, items = TitanJourney_Engine, TitanJourney_Items
  local level = (UnitLevel and UnitLevel("player")) or 1
  local names = (TitanJourney_DB and TitanJourney_DB.Journey()) or {}
  local out = {}
  if engine and items then
    for _, n in ipairs(names) do
      local it = engine.FindByName(items, n)
      if it then out[#out + 1] = it end
    end
  end
  return out, level
end

-- Render one list tab (key = "current" or "future") into its panel, spec-scored.
function Overlay.RenderTab(key)
  local panel = Overlay.panels and Overlay.panels[key]
  if not panel or not panel.listAnchor then return end
  local list, level, hi = Overlay.ComputeList(key)
  panel.rows = panel.rows or {}
  RenderRowsInto(panel.scroll, panel.listAnchor, panel.rows, list, level, hi, "add")
  panel.empty:SetShown(#list == 0)
  if key == "future" then
    panel.sub:SetText(#list > 0 and ("Level " .. (hi + 1) .. " and up") or "")
  else
    panel.sub:SetText(#list > 0 and ("Levels " .. level .. " \226\128\147 " .. hi) or "")
  end
end

-- Highlight the chosen slot chip and remember the selection.
Overlay.selectorSlot = Overlay.selectorSlot or "all"
function Overlay.SelectChip(slot)
  Overlay.selectorSlot = slot
  local panel = Overlay.panels and Overlay.panels.browse
  if panel and panel.chipButtons then
    for k, b in pairs(panel.chipButtons) do
      if k == slot then b:LockHighlight() else b:UnlockHighlight() end
    end
  end
end

-- Render the Browse tab: selector candidates (left) + Journey List (right).
function Overlay.RenderBrowse()
  local panel = Overlay.panels and Overlay.panels.browse
  if not panel or not panel.selAnchor then return end
  local engine = TitanJourney_Engine

  local cands, level, hi = Overlay.ComputeCandidates(Overlay.selectorSlot or "all")
  panel.selRows = panel.selRows or {}
  RenderRowsInto(panel.selScroll, panel.selAnchor, panel.selRows, cands, level, hi, "add")
  panel.selEmpty:SetShown(#cands == 0)

  local jitems, jlevel = Overlay.JourneyItems()
  local range = (TitanJourney_DB and TitanJourney_DB.Lookahead()) or 10
  panel.jRows = panel.jRows or {}
  RenderRowsInto(panel.jScroll, panel.jAnchor, panel.jRows, jitems, jlevel, jlevel + range, "journey")
  panel.jEmpty:SetShown(#jitems == 0)

  local names = (TitanJourney_DB and TitanJourney_DB.Journey()) or {}
  local goal = engine and engine.NextJourneyGoal(jitems, names, jlevel, Overlay.PlayerOwnsFn())
  if goal then
    panel.jNext:SetText("Next: " .. goal.name .. " (Lv " .. goal.reqLevel .. ") - "
      .. engine.ProximityLabel(goal.reqLevel, jlevel))
  else
    panel.jNext:SetText(#jitems > 0 and "All journey gear acquired!" or "Add gear from the selector.")
  end
end

-- Refresh the browse + future views (called by the provider and on open).
function Overlay.RenderCurrentGoals()
  Overlay.RenderBrowse()
  Overlay.RenderTab("future")
end

-- Bottom control bar shared by the list tabs (FEAT-C8/C9): source-filter
-- checkboxes + a lookahead slider, both persisted and re-rendering live.
local SOURCE_FILTERS = { "Crafted", "Dungeon", "Faction", "PvP" }

local function BuildControlBar(content, topLevel)
  local bar = CreateFrame("Frame", nil, content)
  bar:SetHeight(34)
  bar:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 2, 2)
  bar:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -2, 2)
  bar:SetFrameLevel(topLevel)
  Overlay.controlBar = bar

  local x = 4
  for _, key in ipairs(SOURCE_FILTERS) do
    local cb = CreateFrame("CheckButton", nil, bar, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    cb:SetPoint("LEFT", bar, "LEFT", x, 0)
    cb:SetChecked(not (TitanJourney_DB and TitanJourney_DB.Sources()[key] == false))
    cb:SetScript("OnClick", function(self)
      if TitanJourney_DB then TitanJourney_DB.Sources()[key] = self:GetChecked() and true or false end
      Overlay.RenderCurrentGoals()
    end)
    local lbl = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lbl:SetPoint("LEFT", cb, "RIGHT", 1, 0)
    lbl:SetText(key)
    x = x + 84
  end

  -- Lookahead slider (1..15) on the right.
  local start = (TitanJourney_DB and TitanJourney_DB.Lookahead()) or 10
  local slider = CreateFrame("Slider", "TitanJourneyLookSlider", bar, "OptionsSliderTemplate")
  slider:SetWidth(130)
  slider:SetPoint("RIGHT", bar, "RIGHT", -12, 0)
  slider:SetMinMaxValues(1, 15)
  slider:SetValueStep(1)
  if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
  slider:SetValue(start)
  _G["TitanJourneyLookSliderLow"]:SetText("1")
  _G["TitanJourneyLookSliderHigh"]:SetText("15")
  local txt = _G["TitanJourneyLookSliderText"]
  txt:SetText("Lookahead +" .. start)
  slider:SetScript("OnValueChanged", function(self, v)
    v = math.floor(v + 0.5)
    txt:SetText("Lookahead +" .. v)
    if TitanJourney_DB then TitanJourney_DB.SetLookahead(v) end
    Overlay.RenderCurrentGoals()
  end)
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

    if tab.key == "browse" then
      -- Slot chips row (All + each equipment slot).
      local chipBar = CreateFrame("Frame", nil, panel)
      chipBar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
      chipBar:SetPoint("RIGHT", panel, "RIGHT", -4, 0)
      panel.chipButtons = {}
      local CHIP_SLOTS = { "all", "Head", "Neck", "Shoulder", "Back", "Chest", "Wrist",
        "Hands", "Waist", "Legs", "Feet", "Ring", "Trinket", "Main Hand", "Off Hand", "Ranged" }
      local cx, cy = 0, 0
      for _, s in ipairs(CHIP_SLOTS) do
        local b = CreateFrame("Button", nil, chipBar, "UIPanelButtonTemplate")
        b:SetText(s == "all" and "All" or s)
        b:SetHeight(18)
        local w = (b:GetTextWidth() or 30) + 16
        if w < 30 then w = 30 end
        if cx + w > 560 then cx = 0; cy = cy - 22 end
        b:SetWidth(w)
        b:SetPoint("TOPLEFT", chipBar, "TOPLEFT", cx, cy)
        cx = cx + w + 4
        b:SetScript("OnClick", function() Overlay.SelectChip(s); Overlay.RenderBrowse() end)
        panel.chipButtons[s] = b
      end
      chipBar:SetHeight(-cy + 22)

      -- Two panes: Selector (left) | Journey List (right).
      local leftPane = CreateFrame("Frame", nil, panel)
      leftPane:SetPoint("TOPLEFT", chipBar, "BOTTOMLEFT", 0, -8)
      leftPane:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 40)
      leftPane:SetWidth(420)
      local rightPane = CreateFrame("Frame", nil, panel)
      rightPane:SetPoint("TOPLEFT", leftPane, "TOPRIGHT", 14, 0)
      rightPane:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, 40)

      local selHdr = leftPane:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      selHdr:SetPoint("TOPLEFT", leftPane, "TOPLEFT", 2, 0)
      selHdr:SetText("Selector")
      local selScroll, selAnchor = MakeScroll(leftPane)
      selScroll:SetPoint("TOPLEFT", selHdr, "BOTTOMLEFT", 0, -4)
      selScroll:SetPoint("BOTTOMRIGHT", leftPane, "BOTTOMRIGHT", -24, 0)
      panel.selScroll, panel.selAnchor = selScroll, selAnchor
      local selEmpty = leftPane:CreateFontString(nil, "OVERLAY", "GameFontDisable")
      selEmpty:SetPoint("TOPLEFT", selScroll, "TOPLEFT", 2, -4)
      selEmpty:SetText("No matching gear.")
      selEmpty:Hide()
      panel.selEmpty = selEmpty

      local jHdr = rightPane:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      jHdr:SetPoint("TOPLEFT", rightPane, "TOPLEFT", 2, 0)
      jHdr:SetText("Journey List")
      local jNext = rightPane:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      jNext:SetPoint("TOPLEFT", jHdr, "BOTTOMLEFT", 0, -3)
      jNext:SetPoint("RIGHT", rightPane, "RIGHT", -4, 0)
      jNext:SetJustifyH("LEFT")
      panel.jNext = jNext
      local jScroll, jAnchor = MakeScroll(rightPane)
      jScroll:SetPoint("TOPLEFT", jNext, "BOTTOMLEFT", 0, -6)
      jScroll:SetPoint("BOTTOMRIGHT", rightPane, "BOTTOMRIGHT", -24, 0)
      panel.jScroll, panel.jAnchor = jScroll, jAnchor
      local jEmpty = rightPane:CreateFontString(nil, "OVERLAY", "GameFontDisable")
      jEmpty:SetPoint("TOPLEFT", jScroll, "TOPLEFT", 2, -4)
      jEmpty:SetText("Add gear from the selector.")
      jEmpty:Hide()
      panel.jEmpty = jEmpty

    elseif tab.key == "future" then
      -- Single scrolling list (best-per-slot, just above the lookahead window).
      local sub = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      sub:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -3)
      panel.sub = sub
      local scroll, child = MakeScroll(panel)
      scroll:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -10)
      scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -26, 40)
      panel.scroll, panel.listAnchor = scroll, child
      local empty = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
      empty:SetPoint("TOPLEFT", scroll, "TOPLEFT", 2, -4)
      empty:SetText("No upcoming gear for your class.")
      empty:Hide()
      panel.empty = empty

    else
      -- Settings (QUAL-5): PvE/PvP weighting toggle.
      local mode = TitanJourney_DB and TitanJourney_DB.Mode() or "pve"
      local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
      cb:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 2, -16)
      cb:SetChecked(mode == "pvp")
      cb:SetScript("OnClick", function(self)
        if TitanJourney_DB then TitanJourney_DB.SetMode(self:GetChecked() and "pvp" or "pve") end
        Overlay.RenderCurrentGoals()
      end)
      local lbl = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      lbl:SetPoint("LEFT", cb, "RIGHT", 4, 0)
      lbl:SetText("PvP weighting (favour Stamina for survivability)")

      local note = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
      note:SetPoint("TOPLEFT", cb, "BOTTOMLEFT", 4, -14)
      note:SetWidth(440)
      note:SetJustifyH("LEFT")
      note:SetText("PvE ranks gear by your spec's primary stats; PvP adds Stamina. "
        .. "Changes apply to the Browse and Future Planner rankings.")
    end

    Overlay.panels[tab.key] = panel
  end

  BuildControlBar(content, topLevel)
  Overlay.SelectChip(Overlay.selectorSlot or "all")
  Overlay.RenderCurrentGoals()
  Overlay.SelectTab(Overlay.activeTab or "browse")
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

  f:SetSize(880, 520)  -- wide enough for the two-pane Browse layout
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

-- Inventory changes (looted/bought/equipped an item) re-filter the suggestions.
local invWatcher = CreateFrame("Frame")
invWatcher:RegisterEvent("BAG_UPDATE_DELAYED")
invWatcher:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
invWatcher:SetScript("OnEvent", function()
  if TitanPanelButton_UpdateButton then TitanPanelButton_UpdateButton("Journey") end
  Overlay.RenderCurrentGoals()
end)

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
