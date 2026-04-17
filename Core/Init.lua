-- Init.lua
-- Main initialization and event handling for MigothsProfessionPilot.

local ADDON_NAME, PP = ...

-- Event frame and registry
local eventFrame = CreateFrame("Frame")
local registeredEvents = {}

--- Registers an event handler.
-- @param event string The WoW event name
-- @param handler function The callback
function PP:RegisterEvent(event, handler)
    registeredEvents[event] = handler
    eventFrame:RegisterEvent(event)
end

--- Unregisters an event handler.
-- @param event string The WoW event name
function PP:UnregisterEvent(event)
    registeredEvents[event] = nil
    eventFrame:UnregisterEvent(event)
end

-- Dispatch events
eventFrame:SetScript("OnEvent", function(self, event, ...)
    local handler = registeredEvents[event]
    if handler then handler(PP, event, ...) end
end)

--- Called when the addon is loaded.
local function OnAddonLoaded(self, event, addonName)
    if addonName ~= ADDON_NAME then return end

    PP:InitLocalization()
    PP.Database:Init()

    -- Initialize modules
    PP.ProfessionScanner:Init()
    PP.InventoryScanner:Init()
    PP.PriceSource:Init()
    PP.PathOptimizer:Init()

    -- Initialize UI
    PP.MinimapButton:Init()
    PP.MainFrame:Init()
    PP.AuctionHouseTab:Init()

    -- Auto-scan AH prices when AH opens
    PP:RegisterEvent("AUCTION_HOUSE_SHOW", function(self)
        if PP.Database:GetSettings().autoScan then
            C_Timer.After(0.5, function()
                PP.PriceSource:StartScan()
            end)
        end
        -- Inject AH tab
        C_Timer.After(0, function()
            PP.AuctionHouseTab:OnAuctionHouseShow()
        end)
    end)

    PP:RegisterEvent("AUCTION_HOUSE_CLOSED", function(self)
        PP.PriceSource:OnAuctionHouseClosed()
        PP.AuctionHouseTab:OnAuctionHouseClosed()
    end)

    -- Rescan professions when trade skill window updates
    PP:RegisterEvent("TRADE_SKILL_LIST_UPDATE", function(self)
        PP.ProfessionScanner:ScanCurrentProfession()
    end)

    -- Re-detect professions when skill lines change (e.g. learning a new profession)
    PP:RegisterEvent("SKILL_LINES_CHANGED", function(self)
        PP.ProfessionScanner:ScanAllProfessions()
    end)

    -- Rescan inventory on bag changes
    PP:RegisterEvent("BAG_UPDATE", function(self)
        PP.InventoryScanner:ScanBags()
    end)

    PP.Utils.Print(string.format(PP.L["ADDON_LOADED"], PP.VERSION))
    PP:UnregisterEvent("ADDON_LOADED")
end

PP:RegisterEvent("ADDON_LOADED", OnAddonLoaded)

-- Slash commands
SLASH_MIGOTHSPROFESSIONPILOT1 = "/pp"
SLASH_MIGOTHSPROFESSIONPILOT2 = "/migothsprofessionpilot"

SlashCmdList["MIGOTHSPROFESSIONPILOT"] = function(msg)
    local L = PP.L
    msg = strtrim(msg):lower()

    if msg == "" then
        PP.MainFrame:Toggle()
    elseif msg == "scan" then
        if PP.Utils.IsAuctionHouseOpen() then
            PP.PriceSource:StartScan()
        else
            PP.Utils.Print(L["AH_NOT_OPEN"])
        end
    elseif msg == "list" then
        PP.MainFrame:Show()
        PP.MainFrame:SetActiveTab("shopping")
    elseif msg == "reset confirm" then
        PP.Database:Reset()
        PP.Utils.Print(L["RESET_CONFIRM"])
    elseif msg == "reset" then
        PP.Utils.Print(L["RESET_PROMPT"])
    elseif msg == "help" then
        PP.Utils.Print(L["SLASH_HELP"])
        PP.Utils.Print(L["SLASH_HELP_TOGGLE"])
        PP.Utils.Print(L["SLASH_HELP_SCAN"])
        PP.Utils.Print(L["SLASH_HELP_LIST"])
        PP.Utils.Print(L["SLASH_HELP_RESET"])
        PP.Utils.Print(L["SLASH_HELP_HELP"])
    else
        PP.Utils.Print(L["SLASH_HELP"])
    end
end
