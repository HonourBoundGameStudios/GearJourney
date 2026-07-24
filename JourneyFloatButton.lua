-- JourneyFloatButton -- Gear Journey's own always-on floating display (EPIC-L).
-- A small draggable pill (mount icon + next-goal text) parented to UIParent, so
-- the button needs no Titan slot. It renders OUR published LDB data object; this
-- file owns only the frame. FLOAT-2 mirrors our published LDB object so the pill
-- shows live text/icon; FLOAT-3 routes clicks and the hover tooltip back through
-- that object's own OnClick / OnTooltipShow; FLOAT-4 remembers where you drag it.

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
-- Default position: clearly on-screen so first load is obvious (FLOAT-4 persists
-- a moved position; until then it re-centres each /reload).
bar:SetPoint("CENTER", UIParent, "CENTER", 0, 200)

-- Drag to move, then remember it (FLOAT-4). LeftButton drag coexists with the
-- LeftButton click (FLOAT-3): WoW fires OnClick only when the pointer didn't drag.
bar:SetMovable(true)
bar:RegisterForDrag("LeftButton")
bar:SetScript("OnDragStart", function(self) self:StartMoving() end)
bar:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  GearJourney_FloatSavePosition()   -- clamp + persist the dropped spot
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

-- FLOAT-3: click + tooltip passthrough. We add no behaviour of our own -- the
-- pill simply invokes the published object's OnClick (Left -> Wishlist, Right ->
-- context menu) and OnTooltipShow (which titles itself, so we don't add a line).
bar:RegisterForClicks("LeftButtonUp", "RightButtonUp")
bar:SetScript("OnClick", function(self, button)
  if dataObj and dataObj.OnClick then dataObj.OnClick(self, button) end
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

-- SavedVariables are only populated around login, so restore then (the file-load
-- SetPoint above keeps the pill visible until this fires).
local placer = CreateFrame("Frame")
placer:RegisterEvent("PLAYER_ENTERING_WORLD")
placer:SetScript("OnEvent", RestorePosition)
