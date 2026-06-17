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

-- Sidebar tab definitions (FEAT-C3). Order is top-to-bottom; the first is the
-- landing tab. "Journey Items" is a read-only browse of the saved Journey List.
local TABS = {
  { key = "journey",  label = "Journey Items",  icon = "Interface\\Icons\\INV_Misc_Map_01" },
  { key = "guide",    label = "Class Guide",    icon = "Interface\\Icons\\INV_Misc_Book_09" },
  { key = "browse",   label = "Browse",         icon = "Interface\\Icons\\INV_Misc_Spyglass_02" },
  { key = "future",   label = "Future Planner", icon = "Interface\\Icons\\INV_Misc_PocketWatch_01" },
  { key = "settings", label = "Settings",       icon = "Interface\\Icons\\Trade_Engineering" },
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

  -- Fill the holder rect *directly* with the four quadrants (stretched to fit).
  -- The holder sits wholly inside the frame, so the dimmed art can never bleed
  -- past the window edges -- no reliance on SetClipsChildren (which on some
  -- clients failed to crop an oversized centred canvas, leaking out the bottom).
  local seamX = W * (256 / 384)             -- the composite's 2/3 split
  local seamY = H * (256 / 384)

  local function quad(suffix, x, yDown, w, h)
    local t = holder:CreateTexture(nil, "BACKGROUND")
    t:SetTexture(prefix .. suffix)   -- bad path simply draws nothing
    t:SetAlpha(0.42)                 -- dim so text stays readable
    t:SetPoint("TOPLEFT", holder, "TOPLEFT", x, -yDown)
    t:SetSize(w, h)
    return t
  end

  Overlay.bgTextures = {
    quad("TopLeft",     0,     0,     seamX,     seamY),
    quad("TopRight",    seamX, 0,     W - seamX, seamY),
    quad("BottomLeft",  0,     seamY, seamX,     H - seamY),
    quad("BottomRight", seamX, seamY, W - seamX, H - seamY),
  }
end

-- SelectTab(key): mark one sidebar button active (locked highlight) and show
-- only its content panel. Safe to call before the layout exists.
function Overlay.SelectTab(key)
  Overlay.activeTab = key
  if not Overlay.tabButtons then return end
  for k, btn in pairs(Overlay.tabButtons) do
    if k == key then btn:LockHighlight() else btn:UnlockHighlight() end
    if btn.text then
      if k == key then btn.text:SetTextColor(1.0, 0.82, 0.30) else btn.text:SetTextColor(0.9, 0.9, 0.9) end
    end
  end
  for k, panel in pairs(Overlay.panels) do
    panel:SetShown(k == key)
  end
  -- The source/lookahead bar applies to the pool-filtered tabs only (Browse,
  -- Future). Journey Items shows the saved list verbatim, so no filter bar.
  if Overlay.controlBar then Overlay.controlBar:SetShown(key == "browse" or key == "future") end
end

-- Item-row visuals (FEAT-C4/C5). ------------------------------------------

local ROW_H, ICON = 50, 34

local QUALITY_COLOR = {
  poor      = { 0.62, 0.62, 0.62 },
  common    = { 1.00, 1.00, 1.00 },
  uncommon  = { 0.12, 1.00, 0.00 },
  rare      = { 0.00, 0.44, 0.87 },
  epic      = { 0.64, 0.21, 0.93 },
  legendary = { 1.00, 0.50, 0.00 },
}

-- Quality hex (matches QUALITY_COLOR) for inline-coloured item names.
local QUALITY_HEX = {
  poor = "ff9d9d9d", common = "ffffffff", uncommon = "ff1eff00",
  rare = "ff0070dd", epic = "ffa335ee", legendary = "ffff8000",
}
-- Source label colour by sourceType (dungeon name, Quest, Vendor, ...).
local SOURCE_COLOR = {
  Dungeon = "ffff8c40", Drop = "ffff8c40", Quest = "ffffe04d",
  Crafted = "ff66dd66", Vendor = "ffd0d0d0", Faction = "ff7fc7ff", PvP = "ffff6a6a",
}
-- SourceDisplay(item) -> text, hex (the dungeon/instance name or a coarse type).
local function SourceDisplay(item)
  local st, lbl = item.sourceType, item.sourceLabel
  if st and st ~= "" and lbl and lbl ~= "" then return lbl, SOURCE_COLOR[st] or "ffb0b0b0" end
  if st and st ~= "" then return st, SOURCE_COLOR[st] or "ffb0b0b0" end
  if lbl and lbl ~= "" then return lbl, "ffb0b0b0" end
  return nil
end

-- Per-stat colours for the row's stat line. Stats are upgrades, so everything
-- reads green (red looked like a penalty); slight shade variation per stat.
local STAT_COLOR = {
  Agility   = "ff4dff4d",  -- bright green
  Strength  = "ff7fdf6a",  -- green
  Stamina   = "ff9be88a",  -- light green
  Intellect = "ff6ad9a0",  -- green-teal
  Spirit    = "ff8fe0b0",  -- green-teal
}

-- Build a coloured "+9 Agi  +5 Sta" string from an item's stats, or "" if none.
local function ColoredStats(item)
  local engine = TitanJourney_Engine
  if not (engine and engine.StatParts) then return "" end
  local parts, out = engine.StatParts(item.stats), {}
  for _, p in ipairs(parts) do
    local c = STAT_COLOR[p.name] or "ffd0d0d0"
    out[#out + 1] = "|c" .. c .. "+" .. p.value .. " " .. p.abbr .. "|r"
  end
  return table.concat(out, "  ")
end

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

  -- Name + coloured source beside it. Right edge stops short of the buttons so
  -- long names/effects clip rather than run under the Add/Remove controls.
  row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.name:SetPoint("TOPLEFT", row.border, "TOPRIGHT", 10, 0)
  row.name:SetPoint("RIGHT", row, "RIGHT", -118, 0)
  row.name:SetJustifyH("LEFT")
  row.name:SetWordWrap(false)

  -- Slot + DPS/Speed line.
  row.sub = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  row.sub:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
  row.sub:SetPoint("RIGHT", row, "RIGHT", -118, 0)
  row.sub:SetJustifyH("LEFT")
  row.sub:SetWordWrap(false)

  -- Stats + effect line, coloured.
  row.stats = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  row.stats:SetPoint("TOPLEFT", row.sub, "BOTTOMLEFT", 0, -2)
  row.stats:SetPoint("RIGHT", row, "RIGHT", -118, 0)
  row.stats:SetJustifyH("LEFT")
  row.stats:SetWordWrap(false)

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
  -- Name (quality-coloured) + the source/dungeon name beside it, coloured.
  local qhex = QUALITY_HEX[item.quality] or QUALITY_HEX.common
  local nameText = "|c" .. qhex .. (item.name or "") .. "|r"
  local srcText, srcHex = SourceDisplay(item)
  if srcText then nameText = nameText .. "  |c" .. srcHex .. srcText .. "|r" end
  row.name:SetText(nameText)

  -- Slot + weapon DPS / Speed.
  local subline = item.slot or ""
  if item.dps then subline = subline .. "   |cffffd100DPS " .. string.format("%.1f", item.dps) .. "|r" end
  if item.speed then subline = subline .. "   |cffe0e0e0Speed " .. string.format("%.2f", item.speed) .. "|r" end
  row.sub:SetText(subline)

  -- Stats + on-equip/use effect.
  local statline = ColoredStats(item)
  if item.effect and item.effect ~= "" then
    local ef = item.effect
    if #ef > 64 then ef = ef:sub(1, 61) .. "..." end
    statline = (statline ~= "" and (statline .. "   ") or "") .. "|cff7ce07c" .. ef .. "|r"
  end
  row.stats:SetText(statline)
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

-- A flat slot-filter chip: dark fill + thin gold border, with a gold hover/
-- selected glow (replaces the default red UIPanelButton look). LockHighlight()
-- marks it selected; width auto-fits the label.
local function MakeChip(parent, label)
  local b = CreateFrame("Button", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  b:SetHeight(20)
  if b.SetBackdrop then
    b:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1,
    })
    b:SetBackdropColor(0.10, 0.10, 0.13, 0.92)
    b:SetBackdropBorderColor(0.40, 0.34, 0.18, 1)
  end
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(0.85, 0.66, 0.20, 0.40)
  b:SetHighlightTexture(hl)
  local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  fs:SetPoint("CENTER", 0, 0)
  fs:SetText(label)
  b:SetFontString(fs)
  b:SetWidth(math.max((fs:GetStringWidth() or 30) + 18, 34))
  return b
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

-- The class/level/owned-aware candidate pool shared by every view: enabled
-- sources + rarities, usable by class, not owned, no healing-only for DPS.
local function UsablePool(engine, items, class, level, spec)
  local pool = engine.FilterBySource(items, TitanJourney_DB and TitanJourney_DB.Sources())
  pool = engine.FilterByQuality(pool, TitanJourney_DB and TitanJourney_DB.Qualities())
  pool = engine.FilterByClass(pool, class, level)
  pool = engine.FilterOwned(pool, Overlay.PlayerOwnsFn())
  pool = engine.RejectHealingForDPS(pool, engine.IsCasterDPS(class, spec))
  return pool
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
  local spec = PlayerSpecIndex()
  local weights = engine.WeightsFor(class, spec, TitanJourney_DB and TitanJourney_DB.Mode() or "pve")
  local cur, fut = engine.SplitGoals(UsablePool(engine, items, class, level, spec), level, range)
  local list = cur
  if bucket == "future" then
    -- Plan the next stretch, not end-game: cap a band above the window.
    local cap = hi + 20
    list = {}
    for i = 1, #fut do if fut[i].reqLevel <= cap then list[#list + 1] = fut[i] end end
  end
  return engine.BestPerSlotScored(list, weights), level, hi
end

-- Slot names differ across the chips, the enriched pool, and the index; fold
-- them onto the chip vocabulary so slot filtering is consistent.
local SLOT_CANON = {
  Finger = "Ring", ["One-Hand"] = "Main Hand", ["Two-Hand"] = "Main Hand",
  ["Held In Off-hand"] = "Off Hand",
}
local function CanonSlot(s) return SLOT_CANON[s] or s end
-- Source types the Crafted/Dungeon/Faction/PvP/Quest checkboxes manage; coarse
-- index sources (Drop/Vendor) bypass that filter so nothing is hidden.
local MANAGED_SOURCES = { Crafted = true, Dungeon = true, Faction = true, PvP = true, Quest = true }
local CANDIDATE_CAP = 400

-- ComputeCandidates(slot) -> list, level, hi. The Selector's gear: every
-- equippable the class can use (from the exhaustive index, enriched copy
-- preferred for stats), filtered by slot / quality / source / owned, and the
-- lookahead window unless "All levels" is on. Sorted by required level.
function Overlay.ComputeCandidates(slot)
  local engine, items = TitanJourney_Engine, TitanJourney_Items
  local level = (UnitLevel and UnitLevel("player")) or 1
  if not (engine and items) then return {}, level, level end
  local _, class = UnitClass("player")
  local range = (TitanJourney_DB and TitanJourney_DB.Lookahead()) or engine.DEFAULT_RANGE
  local hi = level + range
  local spec = PlayerSpecIndex()
  local weights = engine.WeightsFor(class, spec, TitanJourney_DB and TitanJourney_DB.Mode() or "pve")
  local allLevels = Overlay.browseAllLevels
  local owns = Overlay.PlayerOwnsFn()
  local quals = TitanJourney_DB and TitanJourney_DB.Qualities()
  local sources = TitanJourney_DB and TitanJourney_DB.Sources()

  local cands = {}
  if Overlay.dungeonFilter then
    -- Soloed dungeon: every usable piece from that instance (the enriched pool
    -- carries the instance label; no window/cap so the whole table shows).
    for i = 1, #items do
      local it = items[i]
      if it.sourceLabel == Overlay.dungeonFilter
         and (slot == "all" or CanonSlot(it.slot) == slot)
         and (not quals or quals[it.quality])
         and engine.CanUse(it, class, level)
         and not (owns and owns(it.itemID)) then
        cands[#cands + 1] = it
      end
    end
  else
    -- Enriched items by id (stats/dps/fine source) overlaid onto index rows.
    local byId = {}
    for i = 1, #items do local e = items[i]; if e.itemID then byId[e.itemID] = e end end
    local source = TitanJourney_ItemIndex or items
    for i = 1, #source do
      local raw = source[i]
      local it = (raw.itemID and byId[raw.itemID]) or raw
      local st = it.sourceType
      local sourceOk = not (st and MANAGED_SOURCES[st]) or not (sources and sources[st] == false)
      if (slot == "all" or CanonSlot(it.slot) == slot)
         and (allLevels or (it.reqLevel or 0) <= hi)
         and (not quals or quals[it.quality])
         and sourceOk
         and engine.CanUse(it, class, level)
         and not (owns and owns(it.itemID)) then
        cands[#cands + 1] = it
      end
    end
  end
  table.sort(cands, function(a, b)
    -- Browse in level order; break ties by spec score, then name.
    if (a.reqLevel or 0) ~= (b.reqLevel or 0) then return (a.reqLevel or 0) < (b.reqLevel or 0) end
    local sa, sb = engine.ScoreItem(a, weights), engine.ScoreItem(b, weights)
    if sa ~= sb then return sa > sb end
    return (a.name or "") < (b.name or "")
  end)
  for i = #cands, CANDIDATE_CAP + 1, -1 do cands[i] = nil end  -- cap for render perf
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
      -- Prefer the enriched pool (has stats); fall back to the exhaustive index
      -- so items added from search still resolve.
      local it = engine.FindByName(items, n)
        or (TitanJourney_ItemIndex and engine.FindByName(TitanJourney_ItemIndex, n))
      if it then out[#out + 1] = it end
    end
  end
  return out, level
end

-- Render the Journey Items tab: the saved Journey List as a single scrolling
-- list (journey mode = Remove + reorder), with a "next goal" subheader.
function Overlay.RenderJourney()
  local panel = Overlay.panels and Overlay.panels.journey
  if not panel or not panel.listAnchor then return end
  local engine = TitanJourney_Engine
  local jitems, jlevel = Overlay.JourneyItems()
  local range = (TitanJourney_DB and TitanJourney_DB.Lookahead()) or 10
  panel.rows = panel.rows or {}
  RenderRowsInto(panel.scroll, panel.listAnchor, panel.rows, jitems, jlevel, jlevel + range, "journey")
  panel.empty:SetShown(#jitems == 0)

  local names = (TitanJourney_DB and TitanJourney_DB.Journey()) or {}
  local goal = engine and engine.NextJourneyGoal(jitems, names, jlevel, Overlay.PlayerOwnsFn())
  if goal then
    panel.sub:SetText("Next: " .. goal.name .. " (Lv " .. goal.reqLevel .. ") - "
      .. engine.ProximityLabel(goal.reqLevel, jlevel))
  else
    panel.sub:SetText(#jitems > 0 and "All journey gear acquired!" or "")
  end
end

-- Render a banded list (band header + its rows) into a scroll child, pooling
-- both the band-header fontstrings and the item rows. `bands` is an array of
-- { label = string, items = { item, ... } }, already non-empty and ordered.
local function RenderBandedInto(scroll, anchor, rowPool, hdrPool, bands, level)
  local y, ri, hi = -4, 0, 0
  for _, band in ipairs(bands) do
    hi = hi + 1
    local hdr = hdrPool[hi]
    if not hdr then
      hdr = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
      hdrPool[hi] = hdr
    end
    hdr:ClearAllPoints()
    hdr:SetPoint("TOPLEFT", anchor, "TOPLEFT", 2, y)
    hdr:SetText(band.label)
    hdr:Show()
    y = y - 24
    for _, item in ipairs(band.items) do
      ri = ri + 1
      local row = rowPool[ri]
      if not row then row = CreateRow(anchor); rowPool[ri] = row end
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, y)
      row:SetPoint("RIGHT", anchor, "RIGHT", 0, 0)
      FillRow(row, item, level, level)   -- colour levels relative to current
      ConfigRowAction(row, item, "add")  -- Add / On List toggle
      row:Show()
      y = y - (ROW_H + 4)
    end
    y = y - 10  -- gap between bands
  end
  for i = ri + 1, #rowPool do rowPool[i]:Hide() end
  for i = hi + 1, #hdrPool do hdrPool[i]:Hide() end
  local w = (scroll and scroll:GetWidth()) or 0
  if w < 10 then w = 280 end
  anchor:SetWidth(w)
  anchor:SetHeight(math.max(1, -y + 8))
end

-- Weapons | Armor sub-tab toggle for the Class Guide.
Overlay.guideSubtab = Overlay.guideSubtab or "weapons"
function Overlay.SelectGuideSubtab(which)
  Overlay.guideSubtab = which
  local panel = Overlay.panels and Overlay.panels.guide
  if panel and panel.subtabs then
    for k, b in pairs(panel.subtabs) do
      if k == which then b:LockHighlight() else b:UnlockHighlight() end
    end
  end
  Overlay.RenderGuide()
end

-- Toggle between curated suggestions and the whole usable pool.
function Overlay.SetGuideShowAll(on)
  Overlay.guideShowAll = on and true or false
  Overlay.RenderGuide()
end

-- Render the Class Guide tab: a curated, best-in-slot-focused gear list for the
-- player's class (EPIC-H), resolved from itemIDs against the enriched pool and
-- grouped into level bands. Split into Weapons / Armor sub-tabs; items not
-- usable by the class are dropped, and a "best dungeon to run" hint is shown.
function Overlay.RenderGuide()
  local panel = Overlay.panels and Overlay.panels.guide
  if not panel or not panel.listAnchor then return end
  local engine, items = TitanJourney_Engine, TitanJourney_Items
  local locClass, class = UnitClass("player")
  local level = (UnitLevel and UnitLevel("player")) or 1
  local guide = class and TitanJourney_ClassGuides and TitanJourney_ClassGuides[class]
  panel.header:SetText((locClass or "Class") .. " Gear Guide"
    .. (Overlay.guideShowAll and "  |cff66ccff(all usable)|r" or "  |cff999999(suggestions)|r"))

  -- "Best dungeon to run now" hint (most usable upgrades around your level).
  if panel.hint then
    local dungeon, n = engine and engine.BestDungeon(items, class, level, Overlay.PlayerOwnsFn())
    if dungeon and n and n > 0 then
      panel.hint:SetText("|cffffd100Best run now:|r " .. engine.PrettySource(dungeon)
        .. "  |cff66dd66(" .. n .. " upgrade" .. (n == 1 and "" or "s") .. ")|r")
    else
      panel.hint:SetText("")
    end
  end

  panel.hdrs = panel.hdrs or {}
  panel.rows = panel.rows or {}
  if not (engine and items and guide) then
    RenderBandedInto(panel.scroll, panel.listAnchor, panel.rows, panel.hdrs, {}, level)
    panel.empty:SetText(guide and "Loading gear\226\128\166"
      or "No curated guide yet for your class. (Rogue available; more coming.)")
    panel.empty:Show()
    return
  end

  -- Resolve IDs -> enriched items, keep only usable, filter by the active
  -- sub-tab (Weapons vs Armor), then enforce quality: weapons are kept and
  -- ranked by item level; armor/jewelry must score > 0 (carry offensive stats),
  -- dropping defensive-only pieces. Buckets are sorted best-first.
  local wantWeapon = (Overlay.guideSubtab ~= "armor")
  local spec = PlayerSpecIndex()
  local weights = engine.WeightsFor(class, spec, (TitanJourney_DB and TitanJourney_DB.Mode()) or "pve")
  -- Source: the curated suggestions, or the whole usable pool in "All" mode.
  local buckets, seen = {}, {}
  local function consider(it)
    if not (it and it.itemID) or seen[it.itemID] then return end
    if not engine.CanUse(it, class, level) then return end
    seen[it.itemID] = true
    local isWeapon = (it.itemClassID == 2)
    local score = engine.ScoreItem(it, weights)
    -- Drop off-spec gear (e.g. caster Int weapons in a hunter's guide).
    local offspec = engine.IsOffSpec(it, weights)
    local keep
    if wantWeapon then
      keep = isWeapon and not offspec
    else
      keep = (not isWeapon) and not offspec and score > 0
    end
    if keep then
      local bi = engine.BandIndex(it.reqLevel)
      buckets[bi] = buckets[bi] or {}
      buckets[bi][#buckets[bi] + 1] = { item = it, score = score }
    end
  end
  if Overlay.guideShowAll then
    for i = 1, #items do consider(items[i]) end
  else
    for _, entry in ipairs(guide) do consider(engine.FindByID(items, entry.id)) end
  end
  local bands = {}
  for bi = 1, #engine.LEVEL_BANDS do
    local b = buckets[bi]
    if b and #b > 0 then
      table.sort(b, function(a, c)
        if a.score ~= c.score then return a.score > c.score end       -- best stats first
        local ad, cd = a.item.dps or 0, c.item.dps or 0               -- then weapon DPS
        if ad ~= cd then return ad > cd end
        local ai, ci = a.item.ilvl or 0, c.item.ilvl or 0
        if ai ~= ci then return ai > ci end
        return (a.item.name or "") < (c.item.name or "")
      end)
      local list = {}
      for i = 1, #b do list[i] = b[i].item end
      bands[#bands + 1] = { label = engine.LEVEL_BANDS[bi].label, items = list }
    end
  end

  RenderBandedInto(panel.scroll, panel.listAnchor, panel.rows, panel.hdrs, bands, level)
  panel.empty:SetText("No matching gear yet \226\128\148 items still loading from the server.")
  panel.empty:SetShown(#bands == 0)
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

-- Solo a dungeon as the Browse source (toggles off if already selected).
function Overlay.SelectDungeon(label)
  Overlay.dungeonFilter = (Overlay.dungeonFilter == label) and nil or label
  Overlay.RenderBrowse()
end

-- AtlasLoot integration (EPIC-I): detect the addon, and open its window on
-- demand. Deep-selection to a specific instance is a later spike; for now we
-- just surface the window (stable, public API).
local function HasAtlasLoot()
  local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded)
  return loaded and loaded("AtlasLootClassic") and _G.AtlasLoot ~= nil
end
function Overlay.OpenAtlasLoot()
  if not HasAtlasLoot() then return end
  pcall(function()
    local gui = _G.AtlasLoot.GUI
    if gui and gui.frame and gui.frame:IsShown() then return end
    if gui and gui.Toggle then gui:Toggle() end
  end)
end

-- Initials abbreviation for a dungeon label, e.g. "Shadowfang Keep" -> "SFK".
local function DungeonAbbrev(label)
  local engine = TitanJourney_Engine
  local s = (engine and engine.PrettySource(label)) or label
  local letters = {}
  for w in s:gmatch("%S+") do letters[#letters + 1] = w:sub(1, 1):upper() end
  local a = table.concat(letters):sub(1, 3)
  if a == "" then a = (s:sub(1, 2)):upper() end
  return a
end

-- Populate the dungeon-filter bar with the dungeons offering the most usable,
-- unowned gear in the player's window. Buttons are pooled; click solos a source.
local function RenderDungeonBar(panel, class, level)
  local bar, pool = panel.dungeonBar, panel.dungeonBtns
  if not bar then return end
  local engine, items = TitanJourney_Engine, TitanJourney_Items
  local lookahead = (TitanJourney_DB and TitanJourney_DB.Lookahead()) or 10
  local ownsFn = Overlay.PlayerOwnsFn()
  local counts, order = {}, {}
  for i = 1, #(items or {}) do
    local it = items[i]
    local r = it.reqLevel or 0
    if it.sourceType == "Dungeon" and it.sourceLabel and it.sourceLabel ~= ""
       and r >= level - 2 and r <= level + lookahead
       and engine.CanUse(it, class, level) and not ownsFn(it.itemID) then
      if not counts[it.sourceLabel] then order[#order + 1] = it.sourceLabel end
      counts[it.sourceLabel] = (counts[it.sourceLabel] or 0) + 1
    end
  end
  table.sort(order, function(a, b)
    if counts[a] ~= counts[b] then return counts[a] > counts[b] end
    return a < b
  end)

  -- "All" sits first; highlight it when no dungeon is soloed. Dungeon icons
  -- start to its right.
  local x = 0
  if panel.dungeonAll then
    if Overlay.dungeonFilter then panel.dungeonAll:UnlockHighlight() else panel.dungeonAll:LockHighlight() end
    x = panel.dungeonAll:GetWidth() + 8
  end
  local n = 0
  for idx = 1, math.min(#order, 10) do
    n = n + 1
    local label = order[idx]
    local b = pool[n]
    if not b then
      b = CreateFrame("Button", nil, bar, BackdropTemplateMixin and "BackdropTemplate" or nil)
      b:SetSize(24, 24)
      if b.SetBackdrop then
        b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8",
          edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        b:SetBackdropColor(0.10, 0.10, 0.13, 0.92)
        b:SetBackdropBorderColor(0.40, 0.34, 0.18, 1)
      end
      local ic = b:CreateTexture(nil, "ARTWORK")
      ic:SetPoint("TOPLEFT", 1, -1); ic:SetPoint("BOTTOMRIGHT", -1, 1)
      ic:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
      ic:SetTexCoord(0.08, 0.92, 0.08, 0.92); ic:SetAlpha(0.5)
      local ab = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      ab:SetPoint("CENTER", 0, 0); b.ab = ab
      local hl = b:CreateTexture(nil, "HIGHLIGHT")
      hl:SetAllPoints(); hl:SetColorTexture(0.85, 0.66, 0.20, 0.40)
      b:SetHighlightTexture(hl)
      pool[n] = b
    end
    b.ab:SetText(DungeonAbbrev(label))
    b:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetText(engine.PrettySource(label))
      GameTooltip:AddLine(counts[label] .. " upgrade(s) in range", 0.6, 0.9, 0.6)
      GameTooltip:AddLine("Left-click: filter to this dungeon", 0.8, 0.8, 0.8)
      if HasAtlasLoot() then
        GameTooltip:AddLine("Right-click: open AtlasLoot", 0.8, 0.8, 0.8)
      end
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", function(self, button)
      if button == "RightButton" then Overlay.OpenAtlasLoot() else Overlay.SelectDungeon(label) end
    end)
    b:ClearAllPoints(); b:SetPoint("LEFT", bar, "LEFT", x, 0)
    x = x + 28
    if Overlay.dungeonFilter == label then b:LockHighlight() else b:UnlockHighlight() end
    b:Show()
  end
  for i = n + 1, #pool do pool[i]:Hide() end
  -- A dungeon filtered out of the window clears the stale selection.
  if Overlay.dungeonFilter and not counts[Overlay.dungeonFilter] then
    Overlay.dungeonFilter = nil
  end
end

-- Render the Browse tab: selector candidates (left) + Journey List (right).
function Overlay.RenderBrowse()
  local panel = Overlay.panels and Overlay.panels.browse
  if not panel or not panel.selAnchor then return end
  local engine = TitanJourney_Engine
  local _, pclass = UnitClass("player")
  RenderDungeonBar(panel, pclass, (UnitLevel and UnitLevel("player")) or 1)

  -- A non-empty search box overrides the slot selector and scans the whole
  -- enriched database by name; otherwise show the usual slot candidates.
  local cands, level, hi
  local q = Overlay.searchText
  if q and q ~= "" then
    level = (UnitLevel and UnitLevel("player")) or 1
    hi = level
    -- Search the exhaustive equippable index (every weapon/armor), falling back
    -- to the enriched pool if the index isn't loaded.
    local source = TitanJourney_ItemIndex or TitanJourney_Items
    local hits = engine and engine.SearchByName(source, q, 600) or {}
    -- Prefer the enriched copy of a hit (it carries stats) over the bare index
    -- row; optionally keep only items this character can use.
    local byId = {}
    for i = 1, #(TitanJourney_Items or {}) do
      local e = TitanJourney_Items[i]
      if e.itemID then byId[e.itemID] = e end
    end
    local _, class = UnitClass("player")
    cands = {}
    for _, it in ipairs(hits) do
      local row = byId[it.itemID] or it
      if not (Overlay.searchUsable and engine and not engine.CanUse(row, class, level)) then
        cands[#cands + 1] = row
        if #cands >= 250 then break end
      end
    end
    if panel.selHdr then
      panel.selHdr:SetText("Search: |cffffffff" .. q .. "|r (" .. #cands
        .. (Overlay.searchUsable and ", usable" or "") .. ")")
    end
  else
    -- ComputeCandidates handles the soloed-dungeon source directly now.
    cands, level, hi = Overlay.ComputeCandidates(Overlay.selectorSlot or "all")
    if panel.selHdr then
      if Overlay.dungeonFilter then
        panel.selHdr:SetText("Selector \226\128\148 " .. engine.PrettySource(Overlay.dungeonFilter))
      else
        panel.selHdr:SetText("Selector")
      end
    end
  end
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
  Overlay.RenderJourney()
  Overlay.RenderGuide()
  Overlay.RenderBrowse()
  Overlay.RenderTab("future")
end

-- Bottom control bar shared by the list tabs (FEAT-C8/C9): source-filter
-- checkboxes + a lookahead slider, both persisted and re-rendering live.
local SOURCE_FILTERS = { "Crafted", "Dungeon", "Quest", "Faction", "PvP" }

local function BuildControlBar(content, topLevel)
  local bar = CreateFrame("Frame", nil, content)
  bar:SetHeight(34)
  bar:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 2, 2)
  bar:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -2, 2)
  bar:SetFrameLevel(topLevel)
  Overlay.controlBar = bar

  -- Lookahead slider on the LEFT (frees the right side for the rarity filters).
  local start = (TitanJourney_DB and TitanJourney_DB.Lookahead()) or 10
  local slider = CreateFrame("Slider", "TitanJourneyLookSlider", bar, "OptionsSliderTemplate")
  slider:SetWidth(110)
  slider:SetPoint("LEFT", bar, "LEFT", 12, 0)
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

  local x = 12 + 110 + 24   -- source filters begin to the right of the slider
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
    x = x + 72
  end

  -- Rarity filters (FEAT-G2), coloured by quality.
  x = x + 10
  local RARITY = {
    { key = "uncommon",  label = "Uncommon",  color = "ff1eff00" },
    { key = "rare",      label = "Rare",      color = "ff0070dd" },
    { key = "epic",      label = "Epic",      color = "ffa335ee" },
    { key = "legendary", label = "Legendary", color = "ffff8000" },
  }
  for _, r in ipairs(RARITY) do
    local cb = CreateFrame("CheckButton", nil, bar, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    cb:SetPoint("LEFT", bar, "LEFT", x, 0)
    cb:SetChecked(not (TitanJourney_DB and TitanJourney_DB.Qualities()[r.key] == false))
    cb:SetScript("OnClick", function(self)
      if TitanJourney_DB then TitanJourney_DB.Qualities()[r.key] = self:GetChecked() and true or false end
      Overlay.RenderCurrentGoals()
    end)
    local lbl = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lbl:SetPoint("LEFT", cb, "RIGHT", 1, 0)
    lbl:SetText("|c" .. r.color .. r.label .. "|r")
    -- Advance past the checkbox + this label so a wide label can't overlap the
    -- next checkbox; fixed strides would assume equal widths.
    x = x + 22 + 1 + (lbl:GetStringWidth() or 56) + 14
  end
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
    -- Sidebar button: icon + label on a flat dark plate; gold glow on
    -- hover/selected (SelectTab locks the highlight + golds the label).
    local btn = CreateFrame("Button", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
    btn:SetSize(SIDEBAR_W, TAB_H)
    btn:SetFrameLevel(topLevel)
    btn:SetPoint("TOPLEFT", f, "TOPLEFT", 14, TOP - (i - 1) * (TAB_H + TAB_GAP))
    if btn.SetBackdrop then
      btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1,
      })
      btn:SetBackdropColor(0.09, 0.09, 0.12, 0.85)
      btn:SetBackdropBorderColor(0.38, 0.32, 0.18, 1)
    end
    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(0.85, 0.66, 0.20, 0.32)
    btn:SetHighlightTexture(hl)
    local ic = btn:CreateTexture(nil, "ARTWORK")
    ic:SetSize(22, 22)
    ic:SetPoint("LEFT", 7, 0)
    ic:SetTexture(tab.icon)
    ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)  -- trim the stock icon border
    local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("LEFT", ic, "RIGHT", 8, 0)
    lbl:SetText(tab.label)
    btn.text = lbl
    btn:SetScript("OnClick", function() Overlay.SelectTab(tab.key) end)
    Overlay.tabButtons[tab.key] = btn

    -- Matching content panel with a header; body filled in by later items.
    local panel = CreateFrame("Frame", nil, content)
    panel:SetAllPoints(content)

    local header = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetText(tab.label)

    if tab.key == "journey" then
      -- Journey Items: a single full-width scrolling list of the saved Journey
      -- List. No filter bar (it shows the list verbatim), so the scroll runs to
      -- the bottom inset rather than reserving room for the control bar.
      local sub = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      sub:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -3)
      sub:SetPoint("RIGHT", panel, "RIGHT", -4, 0)
      sub:SetJustifyH("LEFT")
      panel.sub = sub
      local scroll, child = MakeScroll(panel)
      scroll:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -10)
      scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -26, 40)
      panel.scroll, panel.listAnchor = scroll, child
      -- Clickable empty state -> jumps straight to the Browse tab.
      local empty = CreateFrame("Button", nil, panel)
      empty:SetPoint("TOPLEFT", scroll, "TOPLEFT", 2, -4)
      empty:SetSize(380, 20)
      local et = empty:CreateFontString(nil, "OVERLAY", "GameFontDisable")
      et:SetPoint("LEFT")
      et:SetText("Your Journey list is empty \226\128\148 |cff66ccffopen Browse|r to add gear.")
      empty:SetFontString(et)
      empty:SetScript("OnClick", function() Overlay.SelectTab("browse") end)
      empty:Hide()
      panel.empty = empty

    elseif tab.key == "guide" then
      -- Class Guide: header (retitled per class at render), a best-dungeon hint,
      -- Weapons | Armor sub-tabs, then a band-grouped scrolling list.
      panel.header = header
      local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      hint:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -5)
      hint:SetPoint("RIGHT", panel, "RIGHT", -4, 0)
      hint:SetJustifyH("LEFT")
      panel.hint = hint

      panel.subtabs = {}
      local sx = 0
      for _, st in ipairs({ { k = "weapons", l = "Weapons" }, { k = "armor", l = "Armor" } }) do
        local b = MakeChip(panel, st.l)
        b:SetHeight(22)
        b:SetWidth(math.max(b:GetWidth(), 92))
        b:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", sx, -6)
        b:SetScript("OnClick", function() Overlay.SelectGuideSubtab(st.k) end)
        panel.subtabs[st.k] = b
        sx = sx + b:GetWidth() + 6
      end
      -- Suggestions <-> All toggle (show the whole usable pool, not just picks).
      local allCb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
      allCb:SetSize(22, 22)
      allCb:SetPoint("LEFT", panel.subtabs.armor, "RIGHT", 18, 0)
      allCb:SetChecked(Overlay.guideShowAll and true or false)
      local albl = allCb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      albl:SetPoint("LEFT", allCb, "RIGHT", 1, 0)
      albl:SetText("Show all usable")
      allCb:SetScript("OnClick", function(self) Overlay.SetGuideShowAll(self:GetChecked()) end)

      local scroll, child = MakeScroll(panel)
      scroll:SetPoint("TOPLEFT", panel.subtabs.weapons, "BOTTOMLEFT", 0, -8)
      scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -26, 40)
      panel.scroll, panel.listAnchor = scroll, child
      local empty = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
      empty:SetPoint("TOPLEFT", scroll, "TOPLEFT", 2, -4)
      empty:SetText("No curated guide yet for your class.")
      empty:Hide()
      panel.empty = empty

    elseif tab.key == "browse" then
      -- Search box (top-right): searches the whole DB by name, 3s after typing
      -- stops (debounced). A non-empty query overrides the slot selector.
      local searchLbl = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      local search = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
      search:SetAutoFocus(false)
      search:SetSize(170, 20)
      search:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, 2)
      searchLbl:SetPoint("RIGHT", search, "LEFT", -8, 0)
      searchLbl:SetText("Search all weapons & armor")
      search:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        if Overlay._searchTimer then Overlay._searchTimer:Cancel() end
        Overlay._searchTimer = C_Timer.NewTimer(3, function()
          Overlay.searchText = (text:gsub("^%s+", ""):gsub("%s+$", ""))
          Overlay.RenderBrowse()
        end)
      end)
      -- Enter searches immediately (skip the debounce wait).
      search:SetScript("OnEnterPressed", function(self)
        if Overlay._searchTimer then Overlay._searchTimer:Cancel() end
        Overlay.searchText = ((self:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", ""))
        self:ClearFocus()
        Overlay.RenderBrowse()
      end)
      search:SetScript("OnEscapePressed", function(self)
        self:SetText(""); self:ClearFocus()
        if Overlay._searchTimer then Overlay._searchTimer:Cancel() end
        Overlay.searchText = ""; Overlay.RenderBrowse()
      end)
      -- "Usable by me" narrows search results to gear this class can equip.
      local usableCb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
      usableCb:SetSize(20, 20)
      usableCb:SetPoint("TOPRIGHT", search, "BOTTOMRIGHT", 2, -2)
      usableCb:SetChecked(Overlay.searchUsable and true or false)
      local ucLbl = usableCb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      ucLbl:SetPoint("RIGHT", usableCb, "LEFT", -2, 0)
      ucLbl:SetText("Usable by me")
      usableCb:SetScript("OnClick", function(self)
        Overlay.searchUsable = self:GetChecked() and true or false
        Overlay.RenderBrowse()
      end)

      -- Slot chips row (All + each equipment slot).
      local chipBar = CreateFrame("Frame", nil, panel)
      chipBar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
      chipBar:SetPoint("RIGHT", panel, "RIGHT", -4, 0)
      panel.chipButtons = {}
      local CHIP_SLOTS = { "all", "Head", "Neck", "Shoulder", "Back", "Chest", "Wrist",
        "Hands", "Waist", "Legs", "Feet", "Ring", "Trinket", "Main Hand", "Off Hand", "Ranged" }
      local cx, cy = 0, 0
      for _, s in ipairs(CHIP_SLOTS) do
        local b = MakeChip(chipBar, s == "all" and "All" or s)
        local w = b:GetWidth()
        if cx + w > 560 then cx = 0; cy = cy - 24 end
        b:SetPoint("TOPLEFT", chipBar, "TOPLEFT", cx, cy)
        cx = cx + w + 4
        b:SetScript("OnClick", function() Overlay.SelectChip(s); Overlay.RenderBrowse() end)
        panel.chipButtons[s] = b
      end
      chipBar:SetHeight(-cy + 24)

      -- Dungeon source filters: small icon buttons populated per level window
      -- (RenderDungeonBar). Clicking one solos that dungeon as the source.
      local dungeonBar = CreateFrame("Frame", nil, panel)
      dungeonBar:SetPoint("TOPLEFT", chipBar, "BOTTOMLEFT", 0, -2)
      dungeonBar:SetPoint("RIGHT", panel, "RIGHT", -4, 0)
      dungeonBar:SetHeight(26)
      panel.dungeonBar = dungeonBar
      panel.dungeonBtns = {}
      -- "All" clears the dungeon filter (highlighted when nothing is soloed).
      local dAll = MakeChip(dungeonBar, "All")
      dAll:SetHeight(24)
      dAll:SetWidth(math.max(dAll:GetWidth(), 36))
      dAll:SetPoint("LEFT", dungeonBar, "LEFT", 0, 0)
      dAll:SetScript("OnClick", function() Overlay.dungeonFilter = nil; Overlay.RenderBrowse() end)
      panel.dungeonAll = dAll

      -- Two panes: Selector (left) | Journey List (right).
      local leftPane = CreateFrame("Frame", nil, panel)
      leftPane:SetPoint("TOPLEFT", dungeonBar, "BOTTOMLEFT", 0, -6)
      leftPane:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 40)
      leftPane:SetWidth(420)
      local rightPane = CreateFrame("Frame", nil, panel)
      rightPane:SetPoint("TOPLEFT", leftPane, "TOPRIGHT", 14, 0)
      rightPane:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, 40)

      local selHdr = leftPane:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      selHdr:SetPoint("TOPLEFT", leftPane, "TOPLEFT", 2, 0)
      selHdr:SetText("Selector")
      panel.selHdr = selHdr
      -- "All levels" shows usable gear for the slot beyond the lookahead window.
      local allLvlCb = CreateFrame("CheckButton", nil, leftPane, "UICheckButtonTemplate")
      allLvlCb:SetSize(20, 20)
      allLvlCb:SetPoint("TOPRIGHT", leftPane, "TOPRIGHT", -26, 3)
      allLvlCb:SetChecked(Overlay.browseAllLevels and true or false)
      local allLvlLbl = allLvlCb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      allLvlLbl:SetPoint("RIGHT", allLvlCb, "LEFT", -1, 0)
      allLvlLbl:SetText("All levels")
      allLvlCb:SetScript("OnClick", function(self)
        Overlay.browseAllLevels = self:GetChecked() and true or false
        Overlay.RenderBrowse()
      end)
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

      -- Dev/Test: run the engine smoke tests in-client (DEV-1).
      local testBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
      testBtn:SetSize(110, 22)
      testBtn:SetPoint("TOPLEFT", note, "BOTTOMLEFT", -2, -24)
      testBtn:SetText("Run Tests")
      local result = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      result:SetPoint("LEFT", testBtn, "RIGHT", 10, 0)
      result:SetText("|cff888888engine self-test|r")
      testBtn:SetScript("OnClick", function()
        if not TitanJourney_Tests then return end
        local p, fcount, fails = TitanJourney_Tests.Run()
        if fcount == 0 then
          result:SetText(string.format("|cff33ff33%d passed, 0 failed|r", p))
        else
          result:SetText(string.format("|cffff5555%d passed, %d failed|r  %s",
            p, fcount, table.concat(fails, ", ")))
        end
      end)
    end

    Overlay.panels[tab.key] = panel
  end

  BuildControlBar(content, topLevel)
  Overlay.SelectChip(Overlay.selectorSlot or "all")
  Overlay.SelectGuideSubtab(Overlay.guideSubtab or "weapons")
  Overlay.RenderCurrentGoals()
  Overlay.SelectTab(Overlay.activeTab or "journey")
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

  f:SetSize(1060, 520)  -- two-pane Browse + full control bar (5 sources, 4 rarities, slider)
  f:SetPoint("CENTER")
  f:SetFrameStrata("HIGH")
  f:SetToplevel(true)
  f:SetClampedToScreen(true)

  -- Title: a larger font collides with the template's thin title bar, so we
  -- draw our own on a bordered banner plate straddling the top edge. Blank the
  -- template's title fontstring so the two don't double up.
  local tmplTitle = f.TitleText or _G[OVERLAY_NAME .. "TitleText"]
  if tmplTitle then tmplTitle:SetText("") end

  local banner = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
  banner:SetPoint("TOP", f, "TOP", 0, 14)
  banner:SetFrameStrata("HIGH")
  banner:SetFrameLevel(f:GetFrameLevel() + 20)
  if banner.SetBackdrop then
    banner:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 14,
      insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    banner:SetBackdropBorderColor(0.85, 0.68, 0.22)  -- soft gold
  end
  local title = banner:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
  title:SetPoint("CENTER", banner, "CENTER", 0, 0)
  title:SetText("Titan Journey")
  banner:SetSize((title:GetStringWidth() or 150) + 48, 40)

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
