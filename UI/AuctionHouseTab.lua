-- AuctionHouseTab.lua
-- Adds a small shortcut button to the Auction House frame that opens
-- MigothsProfessionPilot in a standalone floating panel beside the AH.

local ADDON_NAME, PP = ...

PP.AuctionHouseTab = {}

local ahButton = nil        -- Small icon button on the AH frame
local ahPanel = nil          -- The floating panel
local isShown = false        -- Whether our panel is currently visible

--- Initializes the AH integration. Called once from Init.lua.
function PP.AuctionHouseTab:Init()
    -- Nothing to do here; OnAuctionHouseShow/OnAuctionHouseClosed are called
    -- from the central event handlers in Init.lua.
end

--- Called when the AH window opens. Creates the button if needed.
function PP.AuctionHouseTab:OnAuctionHouseShow()
    if not AuctionHouseFrame then return end

    if not ahButton then
        self:CreateButton()
        self:CreatePanel()
    end

    ahButton:Show()
end

--- Called when the AH window closes. Hides our panel.
function PP.AuctionHouseTab:OnAuctionHouseClosed()
    if ahPanel then
        ahPanel:Hide()
    end
    isShown = false
end

--- Creates a small shortcut button on the AH title bar.
function PP.AuctionHouseTab:CreateButton()
    local L = PP.L

    ahButton = CreateFrame("Button", "MigothsProfessionPilotAHButton", AuctionHouseFrame)
    ahButton:SetSize(24, 24)
    -- Position in the top-right of the AH frame, left of CraftProfit's button
    ahButton:SetPoint("TOPRIGHT", AuctionHouseFrame, "TOPRIGHT", -56, -4)
    ahButton:SetFrameStrata("HIGH")

    -- Icon
    local icon = ahButton:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    ahButton.icon = icon

    -- Border highlight
    local highlight = ahButton:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.15)

    -- Tooltip
    ahButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(L["AH_TAB_TITLE"])
        GameTooltip:AddLine(L["AH_BTN_TOOLTIP"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    ahButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    ahButton:SetScript("OnClick", function()
        PP.AuctionHouseTab:TogglePanel()
    end)
end

--- Creates the floating panel that appears beside the AH.
function PP.AuctionHouseTab:CreatePanel()
    local L = PP.L
    local PANEL_WIDTH = 700
    local PANEL_HEIGHT = 480

    ahPanel = CreateFrame("Frame", "MigothsProfessionPilotAHPanel", UIParent, "BackdropTemplate")
    ahPanel:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    ahPanel:SetFrameStrata("HIGH")
    ahPanel:SetFrameLevel(100)
    ahPanel:EnableMouse(true)
    ahPanel:SetMovable(true)
    ahPanel:SetClampedToScreen(true)
    ahPanel:Hide()

    -- Position to the right of the AH window
    ahPanel:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPRIGHT", 4, 0)

    -- Make it draggable
    ahPanel:RegisterForDrag("LeftButton")
    ahPanel:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    ahPanel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    -- Backdrop
    ahPanel:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4},
    })
    ahPanel:SetBackdropColor(0.05, 0.05, 0.08, 0.95)
    ahPanel:SetBackdropBorderColor(0.3, 0.3, 0.4, 0.8)

    -- Header bar
    local header = CreateFrame("Frame", nil, ahPanel)
    header:SetPoint("TOPLEFT", 6, -6)
    header:SetPoint("TOPRIGHT", -6, -6)
    header:SetHeight(28)

    header.bg = header:CreateTexture(nil, "BACKGROUND")
    header.bg:SetAllPoints()
    header.bg:SetColorTexture(0.12, 0.12, 0.18, 0.9)

    -- Title
    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", 8, 0)
    title:SetText(PP.COLORS.HEADER .. L["MAIN_TITLE"] .. "|r")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, header, "UIPanelCloseButton")
    closeBtn:SetSize(20, 20)
    closeBtn:SetPoint("RIGHT", -2, 0)
    closeBtn:SetScript("OnClick", function()
        ahPanel:Hide()
        isShown = false
    end)

    -- Last scan info
    ahPanel.scanInfo = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ahPanel.scanInfo:SetPoint("RIGHT", closeBtn, "LEFT", -8, 0)
    ahPanel.scanInfo:SetTextColor(0.6, 0.6, 0.6)

    -- Scan button
    local scanBtn = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
    scanBtn:SetSize(70, 20)
    scanBtn:SetPoint("RIGHT", ahPanel.scanInfo, "LEFT", -8, 0)
    scanBtn:SetText(L["BTN_SCAN"])
    scanBtn:SetScript("OnClick", function()
        PP.PriceSource:StartScan()
    end)

    -- Tab bar
    local tabBar = CreateFrame("Frame", nil, ahPanel)
    tabBar:SetPoint("TOPLEFT", 6, -38)
    tabBar:SetPoint("TOPRIGHT", -6, -38)
    tabBar:SetHeight(24)

    local tabs = {
        {id = "professions", label = L["TAB_PROFESSIONS"]},
        {id = "path",        label = L["TAB_PATH"]},
        {id = "shopping",    label = L["TAB_SHOPPING"]},
        {id = "settings",    label = L["TAB_SETTINGS"]},
    }

    ahPanel.tabButtons = {}
    ahPanel.panels = {}
    ahPanel.activeTab = "professions"

    local tabWidth = math.floor((PANEL_WIDTH - 12) / #tabs)

    for i, tabDef in ipairs(tabs) do
        local btn = CreateFrame("Button", nil, tabBar)
        btn:SetSize(tabWidth, 24)
        btn:SetPoint("LEFT", (i - 1) * tabWidth, 0)

        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.bg:SetColorTexture(0.15, 0.15, 0.15, 0.8)

        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btn.text:SetPoint("CENTER")
        btn.text:SetText(tabDef.label)

        btn.activeLine = btn:CreateTexture(nil, "OVERLAY")
        btn.activeLine:SetHeight(2)
        btn.activeLine:SetPoint("BOTTOMLEFT")
        btn.activeLine:SetPoint("BOTTOMRIGHT")
        btn.activeLine:SetColorTexture(0, 0.8, 1, 1)
        btn.activeLine:Hide()

        btn:SetScript("OnClick", function()
            PP.AuctionHouseTab:SetEmbeddedTab(tabDef.id)
        end)
        btn:SetScript("OnEnter", function(self)
            if ahPanel.activeTab ~= tabDef.id then
                self.bg:SetColorTexture(0.25, 0.25, 0.25, 0.8)
            end
        end)
        btn:SetScript("OnLeave", function(self)
            if ahPanel.activeTab ~= tabDef.id then
                self.bg:SetColorTexture(0.15, 0.15, 0.15, 0.8)
            end
        end)

        ahPanel.tabButtons[tabDef.id] = btn
    end

    -- Content area
    local content = CreateFrame("Frame", nil, ahPanel)
    content:SetPoint("TOPLEFT", 6, -66)
    content:SetPoint("BOTTOMRIGHT", -6, 6)
    ahPanel.content = content

    -- Create sub-panels
    ahPanel.panels["professions"] = PP.ProfessionListUI:Create(content)
    ahPanel.panels["path"] = PP.LevelingPathUI:Create(content)
    ahPanel.panels["shopping"] = PP.ShoppingListUI:Create(content)
    ahPanel.panels["settings"] = self:CreateEmbeddedSettingsPanel(content)

    self:SetEmbeddedTab("professions")
end

--- Creates a settings panel for the embedded view.
-- @param parent Frame Content area
-- @return Frame
function PP.AuctionHouseTab:CreateEmbeddedSettingsPanel(parent)
    local L = PP.L
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 8, -8)
    title:SetText(L["SETTINGS_TITLE"])

    local yOffset = 40

    -- Include Sellback
    local sellbackCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    sellbackCheck:SetSize(26, 26)
    sellbackCheck:SetPoint("TOPLEFT", 8, -yOffset)
    sellbackCheck:SetChecked(PP.Database:GetSettings().includeSellback)
    local sellbackLabel = sellbackCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sellbackLabel:SetPoint("LEFT", sellbackCheck, "RIGHT", 4, 0)
    sellbackLabel:SetText(L["SETTINGS_INCLUDE_SELLBACK"])
    local sellbackDesc = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sellbackDesc:SetPoint("TOPLEFT", 42, -(yOffset + 24))
    sellbackDesc:SetText(L["SETTINGS_INCLUDE_SELLBACK_DESC"])
    sellbackDesc:SetTextColor(0.5, 0.5, 0.5)
    sellbackCheck:SetScript("OnClick", function(self)
        PP.Database:GetSettings().includeSellback = self:GetChecked()
    end)
    yOffset = yOffset + 50

    -- Use Inventory
    local invCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    invCheck:SetSize(26, 26)
    invCheck:SetPoint("TOPLEFT", 8, -yOffset)
    invCheck:SetChecked(PP.Database:GetSettings().useInventory)
    local invLabel = invCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    invLabel:SetPoint("LEFT", invCheck, "RIGHT", 4, 0)
    invLabel:SetText(L["SETTINGS_USE_INVENTORY"])
    local invDesc = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    invDesc:SetPoint("TOPLEFT", 42, -(yOffset + 24))
    invDesc:SetText(L["SETTINGS_USE_INVENTORY_DESC"])
    invDesc:SetTextColor(0.5, 0.5, 0.5)
    invCheck:SetScript("OnClick", function(self)
        PP.Database:GetSettings().useInventory = self:GetChecked()
    end)
    yOffset = yOffset + 50

    -- Auto Scan
    local autoCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    autoCheck:SetSize(26, 26)
    autoCheck:SetPoint("TOPLEFT", 8, -yOffset)
    autoCheck:SetChecked(PP.Database:GetSettings().autoScan)
    local autoLabel = autoCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    autoLabel:SetPoint("LEFT", autoCheck, "RIGHT", 4, 0)
    autoLabel:SetText(L["SETTINGS_AUTO_SCAN"])
    local autoDesc = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    autoDesc:SetPoint("TOPLEFT", 42, -(yOffset + 24))
    autoDesc:SetText(L["SETTINGS_AUTO_SCAN_DESC"])
    autoDesc:SetTextColor(0.5, 0.5, 0.5)
    autoCheck:SetScript("OnClick", function(self)
        PP.Database:GetSettings().autoScan = self:GetChecked()
    end)

    panel.Refresh = function() end
    return panel
end

--- Switches the sub-tab inside the panel.
-- @param tabID string
function PP.AuctionHouseTab:SetEmbeddedTab(tabID)
    if not ahPanel then return end
    ahPanel.activeTab = tabID

    for id, btn in pairs(ahPanel.tabButtons) do
        if id == tabID then
            btn.bg:SetColorTexture(0.2, 0.2, 0.3, 0.9)
            btn.activeLine:Show()
            btn.text:SetTextColor(1, 1, 1)
        else
            btn.bg:SetColorTexture(0.15, 0.15, 0.15, 0.8)
            btn.activeLine:Hide()
            btn.text:SetTextColor(0.6, 0.6, 0.6)
        end
    end

    for id, panel in pairs(ahPanel.panels) do
        if id == tabID then
            panel:Show()
            if panel.Refresh then panel:Refresh() end
        else
            panel:Hide()
        end
    end
end

--- Toggles the floating panel.
function PP.AuctionHouseTab:TogglePanel()
    if not ahPanel then return end

    if ahPanel:IsShown() then
        ahPanel:Hide()
        isShown = false
    else
        self:UpdateScanInfo()
        ahPanel:Show()
        self:SetEmbeddedTab(ahPanel.activeTab or "professions")
        isShown = true
    end
end

--- Returns true when the floating panel is currently shown.
function PP.AuctionHouseTab:IsEmbeddedVisible()
    return ahPanel and ahPanel:IsShown()
end

--- Updates the scan timestamp in the header.
function PP.AuctionHouseTab:UpdateScanInfo()
    if not ahPanel or not ahPanel.scanInfo then return end
    local lastScan = PP.charDb.lastScanTime
    if lastScan and lastScan > 0 then
        ahPanel.scanInfo:SetText("Last scan: " .. PP.Utils.FormatTimeAgo(lastScan))
    else
        ahPanel.scanInfo:SetText("No scan data")
    end
end
