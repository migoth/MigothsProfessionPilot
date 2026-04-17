-- MinimapButton.lua
-- Minimap button for MigothsProfessionPilot using LibDataBroker and LibDBIcon.

local ADDON_NAME, PP = ...

PP.MinimapButton = {}

--- Initializes the minimap button.
function PP.MinimapButton:Init()
    local ldb = LibStub and LibStub("LibDataBroker-1.1", true)
    local icon = LibStub and LibStub("LibDBIcon-1.0", true)
    if not ldb then return end

    local dataObj = ldb:NewDataObject("MigothsProfessionPilot", {
        type = "launcher",
        text = "MigothsProfessionPilot",
        icon = "Interface\\Icons\\INV_Misc_Book_09",
        OnClick = function(self, button)
            if button == "LeftButton" then
                PP.MainFrame:Toggle()
            elseif button == "RightButton" then
                if PP.Utils.IsAuctionHouseOpen() then
                    PP.PriceSource:StartScan()
                else
                    PP.Utils.Print(PP.L["AH_NOT_OPEN"])
                end
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine(PP.COLORS.HEADER .. "MigothsProfessionPilot|r")
            tooltip:AddLine(" ")

            -- Show incomplete professions count
            local professions = PP.ProfessionScanner:GetAllProfessions()
            local incomplete = 0
            for _, prof in pairs(professions) do
                for _, tier in pairs(prof.tiers or {}) do
                    if tier.skillLevel < tier.maxSkill then
                        incomplete = incomplete + 1
                    end
                end
            end
            if incomplete > 0 then
                tooltip:AddDoubleLine("Incomplete Tiers:", tostring(incomplete), 1, 1, 1, 1, 0.5, 0)
            end

            local lastScan = PP.charDb.lastScanTime
            if lastScan and lastScan > 0 then
                tooltip:AddDoubleLine("Last Scan:", PP.Utils.FormatTimeAgo(lastScan), 1, 1, 1, 0.8, 0.8, 0.8)
            end

            tooltip:AddLine(" ")
            tooltip:AddLine("|cFF808080Left-Click:|r Toggle window")
            tooltip:AddLine("|cFF808080Right-Click:|r Quick scan")
        end,
    })

    if icon then
        icon:Register("MigothsProfessionPilot", dataObj, PP.Database:GetSettings().minimapButton)
    end
end
