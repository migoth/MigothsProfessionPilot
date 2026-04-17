-- AuctionHouseTab.lua
-- Adds a "MigothsProfessionPilot" tab to the Auction House frame so the addon
-- can be used without opening a separate window.

local ADDON_NAME, PP = ...

PP.AuctionHouseTab = {}

local ahTab = nil          -- The tab button on the AH frame
local ahPanel = nil         -- The embedded content panel
local ahTabIndex = nil      -- Our tab index
local isTabActive = false   -- Whether our tab is currently shown

--- Initializes the AH tab. Called once from Init.lua.
-- The actual event hooks are wired up in Init.lua alongside existing handlers.
function PP.AuctionHouseTab:Init()
    -- Nothing to do here; OnAuctionHouseShow/OnAuctionHouseClosed are called
    -- from the central event handlers in Init.lua.
end

--- Called when the AH window opens. Creates the tab if needed and shows it.
function PP.AuctionHouseTab:OnAuctionHouseShow()
    if not AuctionHouseFrame then return end

    if not ahTab then
        self:CreateTab()
        self:CreatePanel()
    end

    -- Ensure our tab is visible and properly styled as deselected
    ahTab:Show()
    PanelTemplates_DeselectTab(ahTab)
end

--- Called when the AH window closes. Deactivates our tab.
function PP.AuctionHouseTab:OnAuctionHouseClosed()
    if isTabActive then
        self:Deactivate()
    end
end

--- Creates the tab button on the AH frame.
function PP.AuctionHouseTab:CreateTab()
    local L = PP.L

    -- Count existing tabs — prefer AuctionHouseFrame.numTabs, fall back to globals
    local numTabs = AuctionHouseFrame.numTabs or 0
    if numTabs == 0 then
        while _G["AuctionHouseFrameTab" .. (numTabs + 1)] do
            numTabs = numTabs + 1
        end
    end

    ahTabIndex = numTabs + 1
    local tabName = "AuctionHouseFrameTab" .. ahTabIndex

    -- Create the tab using the standard panel tab template
    ahTab = CreateFrame("Button", tabName, AuctionHouseFrame, "PanelTabButtonTemplate")
    ahTab:SetID(ahTabIndex)
    ahTab:SetText(L["AH_TAB_TITLE"])
    ahTab:SetScript("OnClick", function()
        PP.AuctionHouseTab:OnTabClick()
    end)

    -- Position to the right of the last existing tab
    local lastTab = _G["AuctionHouseFrameTab" .. numTabs]
    if lastTab then
        ahTab:SetPoint("LEFT", lastTab, "RIGHT", -15, 0)
    else
        ahTab:SetPoint("BOTTOMLEFT", AuctionHouseFrame, "BOTTOMLEFT", 0, -30)
    end

    -- Register with PanelTemplates for proper tab management and z-ordering
    PanelTemplates_SetNumTabs(AuctionHouseFrame, ahTabIndex)
    if PanelTemplates_EnableTab then
        PanelTemplates_EnableTab(AuctionHouseFrame, ahTabIndex)
    end
    PanelTemplates_TabResize(ahTab, 0)
    PanelTemplates_DeselectTab(ahTab)

    -- Hook each existing AH tab to deactivate ours when clicked.
    -- The modern AH may use custom OnClick handlers that bypass PanelTemplates_SetTab,
    -- so direct hooks are required.
    for i = 1, numTabs do
        local existingTab = _G["AuctionHouseFrameTab" .. i]
        if existingTab then
            existingTab:HookScript("OnClick", function()
                if isTabActive then
                    PP.AuctionHouseTab:Deactivate()
                end
            end)
        end
    end

    -- Also hook PanelTemplates_SetTab as a safety net for programmatic tab changes
    if not self._tabHooked then
        hooksecurefunc("PanelTemplates_SetTab", function(frame, id)
            if frame == AuctionHouseFrame and id ~= ahTabIndex and isTabActive then
                PP.AuctionHouseTab:Deactivate()
            end
        end)
        self._tabHooked = true
    end
end

--- Creates the embedded panel that replaces the AH content area.
function PP.AuctionHouseTab:CreatePanel()
    local L = PP.L

    ahPanel = CreateFrame("Frame", "MigothsProfessionPilotAHPanel", AuctionHouseFrame)
    ahPanel:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPLEFT", 0, -58)
    ahPanel:SetPoint("BOTTOMRIGHT", AuctionHouseFrame, "BOTTOMRIGHT", 0, 0)
    ahPanel:SetFrameStrata("HIGH")
    ahPanel:SetFrameLevel(AuctionHouseFrame:GetFrameLevel() + 100)
    ahPanel:EnableMouse(true)
    ahPanel:Hide()

    -- Background
    ahPanel.bg = ahPanel:CreateTexture(nil, "BACKGROUND")
    ahPanel.bg:SetAllPoints()
    ahPanel.bg:SetColorTexture(0.05, 0.05, 0.05, 0.95)

    -- Header bar
    local header = CreateFrame("Frame", nil, ahPanel)
    header:SetPoint("TOPLEFT", 8, -4)
    header:SetPoint("TOPRIGHT", -8, -4)
    header:SetHeight(36)

    header.bg = header:CreateTexture(nil, "BACKGROUND")
    header.bg:SetAllPoints()
    header.bg:SetColorTexture(0.12, 0.12, 0.18, 0.9)

    -- Title
    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", 8, 0)
    title:SetText(PP.COLORS.HEADER .. L["MAIN_TITLE"] .. "|r")

    -- Last scan info
    ahPanel.scanInfo = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ahPanel.scanInfo:SetPoint("RIGHT", -100, 0)
    ahPanel.scanInfo:SetTextColor(0.6, 0.6, 0.6)

    -- Scan button
    local scanBtn = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
    scanBtn:SetSize(80, 22)
    scanBtn:SetPoint("RIGHT", -8, 0)
    scanBtn:SetText(L["BTN_SCAN"])
    scanBtn:SetScript("OnClick", function()
        PP.PriceSource:StartScan()
    end)

    -- Tab bar inside the panel
    local tabBar = CreateFrame("Frame", nil, ahPanel)
    tabBar:SetPoint("TOPLEFT", 8, -42)
    tabBar:SetPoint("TOPRIGHT", -8, -42)
    tabBar:SetHeight(26)

    local tabs = {
        {id = "professions", label = L["TAB_PROFESSIONS"]},
        {id = "path",        label = L["TAB_PATH"]},
        {id = "shopping",    label = L["TAB_SHOPPING"]},
        {id = "settings",    label = L["TAB_SETTINGS"]},
    }

    ahPanel.tabButtons = {}
    ahPanel.panels = {}
    ahPanel.activeTab = "professions"

    local tabWidth = math.floor((AuctionHouseFrame:GetWidth() - 16) / #tabs)

    for i, tabDef in ipairs(tabs) do
        local btn = CreateFrame("Button", nil, tabBar)
        btn:SetSize(tabWidth, 26)
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

    -- Content area for sub-panels
    local content = CreateFrame("Frame", nil, ahPanel)
    content:SetPoint("TOPLEFT", 8, -72)
    content:SetPoint("BOTTOMRIGHT", -8, 8)
    ahPanel.content = content

    -- Create sub-panels (reusing the same panel modules)
    ahPanel.panels["professions"] = PP.ProfessionListUI:Create(content)
    ahPanel.panels["path"] = PP.LevelingPathUI:Create(content)
    ahPanel.panels["shopping"] = PP.ShoppingListUI:Create(content)
    ahPanel.panels["settings"] = self:CreateEmbeddedSettingsPanel(content)

    self:SetEmbeddedTab("professions")
end

--- Creates a settings panel for the embedded AH view.
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

--- Switches the sub-tab inside the embedded AH panel.
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

--- Handles click on our AH tab.
function PP.AuctionHouseTab:OnTabClick()
    if isTabActive then return end
    self:Activate()
end

--- Activates the MigothsProfessionPilot tab: shows our panel overlaying the AH content.
function PP.AuctionHouseTab:Activate()
    if not AuctionHouseFrame or not ahPanel then return end
    isTabActive = true

    -- Select our tab visually
    PanelTemplates_SetTab(AuctionHouseFrame, ahTabIndex)

    -- Show our overlay panel (blocks input to AH content behind it)
    self:UpdateScanInfo()
    ahPanel:Show()
    self:SetEmbeddedTab(ahPanel.activeTab or "professions")
end

--- Deactivates our tab: hides our panel to reveal default AH content.
function PP.AuctionHouseTab:Deactivate()
    isTabActive = false

    if ahPanel then
        ahPanel:Hide()
    end
end

--- Updates the scan timestamp in the embedded header.
function PP.AuctionHouseTab:UpdateScanInfo()
    if not ahPanel or not ahPanel.scanInfo then return end
    local lastScan = PP.charDb.lastScanTime
    if lastScan and lastScan > 0 then
        ahPanel.scanInfo:SetText("Last scan: " .. PP.Utils.FormatTimeAgo(lastScan))
    else
        ahPanel.scanInfo:SetText("No scan data")
    end
end
