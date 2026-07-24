-- JourneyFloatButton -- Gear Journey's own always-on floating display (EPIC-L).
-- A small draggable pill (mount icon + next-goal text) parented to UIParent, so
-- the button needs no Titan slot. It renders OUR published LDB data object; this
-- file owns only the frame. FLOAT-1 is the skeleton: the pill appears with a
-- placeholder; live text (FLOAT-2), click/tooltip (FLOAT-3), and drag persistence
-- (FLOAT-4) land in later commits.

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

-- Drag to move (no persistence yet -- FLOAT-4). LeftButton drag coexists with a
-- future LeftButton click: WoW fires OnClick only when the pointer didn't drag.
bar:SetMovable(true)
bar:RegisterForDrag("LeftButton")
bar:SetScript("OnDragStart", function(self) self:StartMoving() end)
bar:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

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
