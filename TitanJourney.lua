-- Gear Journey (formerly TitanJourney; the folder/.toc keep the old name so
-- SavedVariables survive) — published as a LibDataBroker data source (EPIC-K).
-- Any LDB display hosts the button: Titan Panel (via its LDB bridge), Bazooka,
-- ElvUI DataTexts, our own future HonourBar, or the LibDBIcon minimap fallback.
-- Single source of truth: read the version straight from the .toc so the About
-- dialog and the data object can never drift from the packaged version.
local GetMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
local VERSION = (GetMeta and GetMeta("TitanJourney", "Version")) or "dev"

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
  text = "Honour Bound Game Studios\nGear Journey v" .. VERSION
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

local QUALITY_HEX = {
    poor = "ff9d9d9d", common = "ffffffff", uncommon = "ff1eff00",
    rare = "ff0070dd", epic = "ffa335ee", legendary = "ffff8000",
}

-- Tooltip body shown on hover (vertical tooltip only -- never the bar text):
-- the player's Journey List, then the click hints, then the studio footer.
function TitanJourney_GetTooltipText()
    local overlay, engine = TitanJourney_Overlay, TitanJourney_Engine
    local lines = {}
    if overlay and overlay.JourneyItems and engine then
        local items, level = overlay.JourneyItems()
        if #items == 0 then
            lines[#lines + 1] = Colors.LightGray .. "Journey List is empty." .. Colors.Reset
        else
            lines[#lines + 1] = Colors.LightGray .. "Journey List" .. Colors.Reset
            for i = 1, math.min(#items, 12) do
                local it = items[i]
                local hex = QUALITY_HEX[it.quality] or "ffffffff"
                local prox = engine.ProximityLabel and engine.ProximityLabel(it.reqLevel, level) or ""
                local pcolor = (it.reqLevel <= level) and "ff33ff33" or "ffffd100"
                lines[#lines + 1] = "|c" .. hex .. it.name .. "|r " .. Colors.Gray .. "Lv "
                    .. it.reqLevel .. Colors.Reset .. "  |c" .. pcolor .. prox .. "|r"
            end
            if #items > 12 then
                lines[#lines + 1] = Colors.Gray .. "...and " .. (#items - 12) .. " more" .. Colors.Reset
            end
        end
    end
    local list = table.concat(lines, "\n")
    local clicks = Colors.LightGray .. "Left-click" .. Colors.Reset .. ": open the Journey manager\n"
        .. Colors.LightGray .. "Right-click" .. Colors.Reset .. ": options"
    local footer = HBGS_LOGO .. Colors.LightGray .. "Honour Bound Game Studios" .. Colors.Reset
    return TOOLTIP_RULE .. "\n" .. list .. "\n" .. TOOLTIP_RULE .. "\n"
        .. clicks .. "\n" .. TOOLTIP_RULE .. "\n" .. footer
end

-- The LDB data object: the one thing every display addon hosts. Displays call
-- the scripts; we own the text/icon and update them via TitanJourney_RefreshButton.
local ldb = LibStub and LibStub("LibDataBroker-1.1", true)
local dataObj
if ldb then
    dataObj = ldb:NewDataObject("GearJourney", {
        type = "data source",
        label = "Next Goal",
        text = "\226\128\148",                    -- em dash placeholder until first refresh
        icon = "Interface\\Icons\\Ability_Mount_RidingHorse",
        OnClick = function(frame, button)
            -- Left-click opens the Wishlist Manager; right-click the context
            -- menu. Ours regardless of host (IND-4) -- Blizzard MenuUtil, the
            -- same post-UIDropDownMenu API the overlay already uses.
            if button == "LeftButton" and TitanJourney_Overlay then
                TitanJourney_Overlay.Toggle()
            elseif button == "RightButton" and MenuUtil then
                MenuUtil.CreateContextMenu(frame, function(_, root)
                    root:CreateTitle("Gear Journey")
                    root:CreateButton("About Honour Bound Game Studios", function()
                        if TitanJourney_Overlay and TitanJourney_Overlay.OpenTo then
                            TitanJourney_Overlay.OpenTo("about")
                        else
                            StaticPopup_Show("JOURNEY_ABOUT")
                        end
                    end)
                    root:CreateCheckbox("Show minimap button",
                        function() return not TitanJourney_DB.Minimap().hide end,
                        function()
                            local mm = TitanJourney_DB.Minimap()
                            mm.hide = not mm.hide
                            local dbicon = LibStub("LibDBIcon-1.0", true)
                            if dbicon then
                                if mm.hide then dbicon:Hide("GearJourney")
                                else dbicon:Show("GearJourney") end
                            end
                        end)
                end)
            end
        end,
        OnTooltipShow = function(tooltip)
            -- Same body the Titan tooltip showed; displays hand us their tooltip
            -- frame. AddLine splits on embedded newlines; no wrap (bar tooltip).
            tooltip:AddLine("Gear Journey")
            for line in (TitanJourney_GetTooltipText() .. "\n"):gmatch("(.-)\n") do
                tooltip:AddLine(line)
            end
        end,
    })
end

-- Repaint = write the data object; every hosting display reacts via the LDB
-- attribute-changed callback (Titan's bridge included).
function TitanJourney_HostRefresh()
    if dataObj == nil then return end
    local _, value = TitanJourney_GetButtonText()
    dataObj.text = value or "\226\128\148"
end

-- Refresh the text on login and whenever the player's level changes (the
-- lookahead window shifts), so the next goal stays current (FEAT-B3). First
-- fire also registers the LibDBIcon minimap launcher (IND-5) -- deferred to
-- here because its saved state lives in TitanJourneyDB, populated at login.
local minimapRegistered = false
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:RegisterEvent("PLAYER_LEVEL_UP")
watcher:SetScript("OnEvent", function()
    if not minimapRegistered then
        minimapRegistered = true
        local dbicon = LibStub and LibStub("LibDBIcon-1.0", true)
        if dbicon and dataObj then
            dbicon:Register("GearJourney", dataObj, TitanJourney_DB.Minimap())
        end
    end
    TitanJourney_RefreshButton()
end)
