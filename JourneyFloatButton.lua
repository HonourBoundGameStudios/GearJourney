-- JourneyFloatButton -- Gear Journey's own always-on floating display (EPIC-L).
-- A small draggable pill (mount icon + next-goal text) parented to UIParent, so
-- the button needs no Titan slot. It renders OUR published LDB data object; this
-- file owns only the frame. FLOAT-2 mirrors our published LDB object so the pill
-- shows live text/icon; FLOAT-3 routes clicks and the hover tooltip back through
-- that object's own OnClick / OnTooltipShow; FLOAT-4 remembers where you drag it;
-- FLOAT-5 adds the right-click menu (lock + show/hide) -- hidden by default.

local ICON = "Interface\\Icons\\Ability_Mount_RidingHorse"
local BAR_HEIGHT = 20
local ICON_SIZE  = 14
local ICON_GAP   = 4
local PAD        = 6      -- inner horizontal padding on each side

-- The pill -------------------------------------------------------------------
local bar = CreateFrame("Button", "GearJourneyFloatButton", UIParent, "BackdropTemplate")
bar:SetHeight(BAR_HEIGHT)
bar:SetFrameStrata("MEDIUM")
bar:SetBackdrop({ bgFile = "Interface\\BUTTONS\\WHITE8X8" })
bar:SetBackdropColor(0, 0, 0, 0.6)
-- Default position; FLOAT-4 restores a moved spot at login. Hidden at file-load
-- so the opt-in default (FLOAT-5) never flashes before login applies the saved
-- visibility.
bar:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
bar:Hide()

-- Drag to move, then remember it (FLOAT-4). LeftButton drag coexists with the
-- LeftButton click (FLOAT-3): WoW fires OnClick only when the pointer didn't drag.
bar:SetMovable(true)
bar:RegisterForDrag("LeftButton")
bar:SetScript("OnDragStart", function(self)
  if GearJourney_DB.Float().locked then return end   -- FLOAT-5: locked = no move
  self:StartMoving()
  self.isMoving = true
end)
bar:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  if self.isMoving then
    self.isMoving = false
    GearJourney_FloatSavePosition()   -- clamp + persist the dropped spot
  end
end)

local icon = bar:CreateTexture(nil, "ARTWORK")
icon:SetSize(ICON_SIZE, ICON_SIZE)
icon:SetPoint("LEFT", bar, "LEFT", PAD, 0)
icon:SetTexture(ICON)

local text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
text:SetPoint("LEFT", icon, "RIGHT", ICON_GAP, 0)
text:SetJustifyH("LEFT")
text:SetText("Next Goal: \226\128\148")   -- placeholder until FLOAT-2 wires live text

-- Size the pill to its contents (icon + measured text + padding both sides).
local function Layout()
  bar:SetWidth(PAD + ICON_SIZE + ICON_GAP + math.max(text:GetStringWidth(), 1) + PAD)
end
Layout()

-- FLOAT-2: render our published "GearJourney" LDB object. The float owns no data
-- of its own -- it mirrors the object every other display hosts, so its text and
-- icon always match the Titan plugin and the minimap button, and update on the
-- same events (level-up / loot) via the shared attribute-changed callback.
local ldb = LibStub and LibStub("LibDataBroker-1.1", true)

-- The object the pill is currently mirroring. FLOAT-3 hangs the click and
-- tooltip handlers off it so the float behaves exactly like every other host.
local dataObj

local function Apply(obj)
  if not obj then return end
  dataObj = obj
  if obj.icon then icon:SetTexture(obj.icon) end
  text:SetText((obj.label or "Next Goal") .. ": " .. (obj.text or "\226\128\148"))
  Layout()
end

if ldb then
  -- Seed from the object as it stands now (published before this file loads).
  for name, obj in ldb:DataObjectIterator() do
    if name == "GearJourney" then Apply(obj); break end
  end
  -- Then track it: setting dataObj.text/icon in GearJourney.lua fires this.
  ldb.RegisterCallback(bar, "LibDataBroker_AttributeChanged",
    function(_, name, _, _, obj)
      if name == "GearJourney" then Apply(obj) end
    end)
end

-- FLOAT-3/5: click + tooltip. Left-click passes through to the published object
-- (opens the Wishlist); the tooltip reuses OnTooltipShow verbatim (it titles
-- itself, so we add no line). Right-click builds the pill's own menu (FLOAT-5):
-- the shared entries plus a "Lock position" toggle unique to the float.
bar:RegisterForClicks("LeftButtonUp", "RightButtonUp")
bar:SetScript("OnClick", function(self, button)
  if button == "RightButton" then
    if MenuUtil and GearJourney_PopulateContextMenu then
      MenuUtil.CreateContextMenu(self, function(_, root)
        GearJourney_PopulateContextMenu(root)
        root:CreateCheckbox("Lock position",
          function() return GearJourney_DB.Float().locked end,
          function() local f = GearJourney_DB.Float(); f.locked = not f.locked end)
      end)
    end
  elseif dataObj and dataObj.OnClick then
    dataObj.OnClick(self, button)
  end
end)

bar:SetScript("OnEnter", function(self)
  if not (dataObj and dataObj.OnTooltipShow) then return end
  GameTooltip:SetOwner(self, "ANCHOR_NONE")
  GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
  dataObj.OnTooltipShow(GameTooltip)
  GameTooltip:Show()
end)
bar:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- FLOAT-4: drag-to-move persistence. Position is a CENTER-anchored offset from
-- the screen centre, stored in GearJourney_DB.Float() and clamped on-screen by
-- the pure Engine.ClampToScreen (so it survives /reload, logout, and a smaller
-- resolution next login without ever landing off the edge).
local function ClampedOffset(x, y)
  return GearJourney_Engine.ClampToScreen(
    x, y, bar:GetWidth(), bar:GetHeight(), UIParent:GetWidth(), UIParent:GetHeight())
end

function GearJourney_FloatSavePosition()
  local cx, cy = bar:GetCenter()
  local ux, uy = UIParent:GetCenter()
  if not (cx and ux) then return end            -- not laid out yet; nothing to save
  local x, y = ClampedOffset(cx - ux, cy - uy)
  local f = GearJourney_DB.Float()
  f.point, f.x, f.y = "CENTER", x, y
  bar:ClearAllPoints()
  bar:SetPoint("CENTER", UIParent, "CENTER", x, y)
end

local function RestorePosition()
  local f = GearJourney_DB.Float()
  local x, y = ClampedOffset(f.x, f.y)
  bar:ClearAllPoints()
  bar:SetPoint(f.point or "CENTER", UIParent, f.point or "CENTER", x, y)
end

-- FLOAT-5: visibility. The pill is hidden by default (opt-in); the shared menu's
-- "Show Gear Journey bar" toggle drives these, so it can be brought back from the
-- minimap after being hidden. State lives in DB.Float().hidden, so it persists.
function GearJourney_FloatShown()
  return not GearJourney_DB.Float().hidden
end
function GearJourney_FloatSetShown(shown)
  GearJourney_DB.Float().hidden = not shown
  if shown then bar:Show() else bar:Hide() end
end

-- SavedVariables are only populated around login, so restore position AND apply
-- the saved visibility then (hidden by default until the player opts in).
local placer = CreateFrame("Frame")
placer:RegisterEvent("PLAYER_ENTERING_WORLD")
placer:SetScript("OnEvent", function()
  RestorePosition()
  GearJourney_FloatSetShown(GearJourney_FloatShown())
end)
