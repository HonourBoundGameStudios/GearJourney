-- TitanJourney — a Titan Panel plugin (modelled on the fleet's TitanWeaponSkills addon).
local _G = getfenv(0)
local ADDON_ID = "Journey"                                  -- short id Titan keys plugin state on
local TITAN_BUTTON_NAME = "TitanPanel" .. ADDON_ID .. "Button"
local VERSION = "0.9.0"

-- Honour Bound Game Studios branding (About dialog + tooltip footer). ---------
local Colors = {
  LightGray = "|cffbbbbbb",
  Gray      = "|cff595959",   -- subtle divider rule
  Reset     = "|r",
}
-- ASCII hyphens only -- FRIZQT has no box-drawing glyphs (they render as TOFU).
local TOOLTIP_RULE = Colors.Gray .. "------------------------------" .. Colors.Reset
local HBGS_LOGO = "|TInterface\\AddOns\\TitanJourney\\Media\\HBGS-Logo:14:14|t "
local HBGS_URL = "https://store.steampowered.com/curator/44062210-Honour-Bound-Game-Studios/"

StaticPopupDialogs["JOURNEY_ABOUT"] = {
  text = "Honour Bound Game Studios\nTitanJourney v" .. VERSION
      .. "\n\nSelect and copy the link below (Ctrl-C):",
  button1 = OKAY,
  hasEditBox = true,
  editBoxWidth = 350,
  OnShow = function(self)
    local editBox = self.editBox or (self.GetEditBox and self:GetEditBox())
    editBox:SetText(HBGS_URL)
    editBox:HighlightText()
    editBox:SetFocus()
  end,
  EditBoxOnEnterPressed  = function(self) self:GetParent():Hide() end,
  EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
  timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

-- Button text: return (label, value). Global by contract — Titan stores the reference.
-- Thin wiring only: pull the player level from the client and delegate the
-- formatting to the pure engine (FEAT-B1, tested offline).
function TitanJourney_GetButtonText(id)
    local engine = TitanJourney_Engine
    local overlay = TitanJourney_Overlay
    if not (engine and overlay and overlay.ComputeList) then
        return "Next Goal:", "—"
    end
    -- Same spec-scored best-per-slot list the overlay shows (Bug 3 fix), so the
    -- button's suggestion always appears in the Current Goals list.
    local list, level = overlay.ComputeList("current")
    -- If the player has a Journey List, surface the nearest entry; else default.
    local journey = TitanJourney_DB and TitanJourney_DB.Journey()
    if journey and #journey > 0 then
        local all = TitanJourney_Items or list
        local goal = engine.NextJourneyGoal(all, journey, level, overlay.PlayerOwnsFn())
        if goal then return engine.BuildButtonText(all, level, nil, goal.name) end
    end
    -- Nothing in the current window (common at low levels / sparse brackets)?
    -- Surface the nearest upcoming goal instead of a dead "None in range".
    if #list == 0 then
        local fut = overlay.ComputeList("future")
        if fut and fut[1] then return engine.BuildButtonText(fut, level, nil, fut[1].name) end
    end
    return engine.BuildButtonText(list, level, nil, nil)
end

-- Tooltip body shown on hover (vertical tooltip only -- never the bar text).
-- Footer carries the studio brand, framed by ASCII rules.
function TitanJourney_GetTooltipText()
    local body = "Left-click to open the Journey manager.\nRight-click for options."
    local footer = HBGS_LOGO .. Colors.LightGray .. "Honour Bound Game Studios" .. Colors.Reset
    return TOOLTIP_RULE .. "\n" .. body .. "\n" .. TOOLTIP_RULE .. "\n" .. footer
end

-- Right-click dropdown menu (Titan's UIDropDownMenu scheme).
local function PrepareMenu()
    TitanPanelRightClickMenu_AddTitle(TitanPlugins[ADDON_ID].menuText)

    local info = {}
    info.text = "About Honour Bound Game Studios"
    info.func = function() StaticPopup_Show("JOURNEY_ABOUT") end
    info.notCheckable = 1
    TitanPanelRightClickMenu_AddButton(info)
    TitanPanelRightClickMenu_AddSpacer()

    TitanPanelRightClickMenu_AddToggleIcon(ADDON_ID)
    TitanPanelRightClickMenu_AddToggleRightSide(ADDON_ID)
    TitanPanelRightClickMenu_AddSpacer()
    TitanPanelRightClickMenu_AddHide(ADDON_ID)
end

-- Titan reads self.registry in the button's OnLoad.
local function OnLoad(self)
    self.registry = {
        id = ADDON_ID,
        category = "Information",
        version = VERSION,
        menuText = "TitanJourney",
        menuTextFunction = PrepareMenu,
        tooltipTitle = "TitanJourney",
        buttonTextFunction = TitanJourney_GetButtonText,
        tooltipTextFunction = TitanJourney_GetTooltipText,
        icon = "Interface\\Icons\\Ability_Mount_RidingHorse",
        iconWidth = 16,
        controlVariables = {
            ShowIcon = true,
            DisplayOnRightSide = false,
        },
        savedVariables = {
            ShowIcon = true,
            DisplayOnRightSide = false,
        },
    }
end

local function OnEvent(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        TitanPanelButton_UpdateButton(ADDON_ID)
    end
end

-- TitanWeaponSkills builds its frame in Lua rather than shipping an XML — same here.
local function CreateTitanButton()
    if _G[TITAN_BUTTON_NAME] then return end
    local frame = CreateFrame("Frame", nil, UIParent)
    local window = CreateFrame("Button", TITAN_BUTTON_NAME, frame, "TitanPanelComboTemplate")
    window:SetFrameStrata("FULLSCREEN")
    OnLoad(window)
    window:RegisterEvent("PLAYER_ENTERING_WORLD")
    window:SetScript("OnShow", function(self) TitanPanelButton_OnShow(self) end)
    window:SetScript("OnEvent", function(self, event, ...) OnEvent(self, event, ...) end)
    window:SetScript("OnClick", function(self, button)
        -- Left-click opens the Wishlist Manager; right-click keeps Titan's menu.
        if button == "LeftButton" and TitanJourney_Overlay then
            TitanJourney_Overlay.Toggle()
        else
            TitanPanelButton_OnClick(self, button)
        end
    end)
end

-- ## Dependencies: Titan in the .toc guarantees Titan loaded first, so TITAN_ID exists.
if TITAN_ID then
    CreateTitanButton()
end
