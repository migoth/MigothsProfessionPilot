-- MainFrame.lua
-- Primary UI window for MigothsProfessionPilot with tab navigation.

local ADDON_NAME, PP = ...

PP.MainFrame = {}

local mainFrame = nil
local tabButtons = {}
local contentPanels = {}
local activeTab = "professions"

local FRAME_WIDTH = 700
local FRAME_HEIGHT = 520
local TAB_HEIGHT = 28
local HEADER_HEIGHT = 50

--- Initializes the main frame (lazy creation).
function PP.MainFrame:Init() end

--- Creates the main frame.
local function CreateMainFrame()
    if mainFrame then return end
    local L = PP.L

    mainFrame = CreateFrame("Frame", "MigothsProfessionPilotMainFrame", UIParent, "BasicFrameTemplateWithInset")
    mainFrame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    mainFrame:SetPoint("CENTER")
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
    mainFrame:SetFrameStrata("HIGH")
    mainFrame:SetClampedToScreen(true)

    -- Title
    mainFrame.TitleBg:SetHeight(HEADER_HEIGHT)
    mainFrame.title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    mainFrame.title:SetPoint("TOPLEFT", 12, -8)
    mainFrame.title:SetText(L["MAIN_TITLE"])

    -- Scan info
    mainFrame.scanInfo = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mainFrame.scanInfo:SetPoint("TOPRIGHT", -30, -12)
    mainFrame.scanInfo:SetTextColor(0.6, 0.6, 0.6)

    -- Scan button
    mainFrame.scanButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    mainFrame.scanButton:SetSize(80, 22)
    mainFrame.scanButton:SetPoint("TOPRIGHT", -30, -28)
    mainFrame.scanButton:SetText(L["BTN_SCAN"])
    mainFrame.scanButton:SetScript("OnClick", function()
        if PP.Utils.IsAuctionHouseOpen() then
            PP.PriceSource:StartScan()
        else
            PP.Utils.Print(L["AH_NOT_OPEN"])
        end
    end)

    -- Tab bar
    local tabContainer = CreateFrame("Frame", nil, mainFrame)
    tabContainer:SetPoint("TOPLEFT", 8, -HEADER_HEIGHT)
    tabContainer:SetPoint("TOPRIGHT", -8, -HEADER_HEIGHT)
    tabContainer:SetHeight(TAB_HEIGHT)

    local tabs = {
        {id = "professions", label = L["TAB_PROFESSIONS"]},
        {id = "path",        label = L["TAB_PATH"]},
        {id = "shopping",    label = L["TAB_SHOPPING"]},
        {id = "settings",    label = L["TAB_SETTINGS"]},
    }

    local tabWidth = (FRAME_WIDTH - 16) / #tabs
    for i, tabDef in ipairs(tabs) do
        local btn = CreateFrame("Button", nil, tabContainer)
        btn:SetSize(tabWidth, TAB_HEIGHT)
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
            PP.MainFrame:SetActiveTab(tabDef.id)
        end)
        btn:SetScript("OnEnter", function(self)
            if activeTab ~= tabDef.id then self.bg:SetColorTexture(0.25, 0.25, 0.25, 0.8) end
        end)
        btn:SetScript("OnLeave", function(self)
            if activeTab ~= tabDef.id then self.bg:SetColorTexture(0.15, 0.15, 0.15, 0.8) end
        end)

        tabButtons[tabDef.id] = btn
    end

    -- Content area
    local contentArea = CreateFrame("Frame", nil, mainFrame)
    contentArea:SetPoint("TOPLEFT", 8, -(HEADER_HEIGHT + TAB_HEIGHT + 4))
    contentArea:SetPoint("BOTTOMRIGHT", -8, 8)
    mainFrame.contentArea = contentArea

    -- Create panels
    contentPanels["professions"] = PP.ProfessionListUI:Create(contentArea)
    contentPanels["path"] = PP.LevelingPathUI:Create(contentArea)
    contentPanels["shopping"] = PP.ShoppingListUI:Create(contentArea)
    contentPanels["settings"] = PP.MainFrame:CreateSettingsPanel(contentArea)

    tinsert(UISpecialFrames, "MigothsProfessionPilotMainFrame")
    PP.MainFrame:SetActiveTab("professions")
    mainFrame:Hide()
end

--- Creates the settings panel.
-- @param parent Frame The content area
-- @return Frame
function PP.MainFrame:CreateSettingsPanel(parent)
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

--- Sets the active tab.
-- @param tabID string
function PP.MainFrame:SetActiveTab(tabID)
    activeTab = tabID
    for id, btn in pairs(tabButtons) do
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
    for id, panel in pairs(contentPanels) do
        if id == tabID then
            panel:Show()
            if panel.Refresh then panel:Refresh() end
        else
            panel:Hide()
        end
    end
end

function PP.MainFrame:Toggle()
    CreateMainFrame()
    if mainFrame:IsShown() then mainFrame:Hide() else self:Show() end
end

function PP.MainFrame:Show()
    CreateMainFrame()
    mainFrame:Show()
    self:UpdateScanInfo()
    local panel = contentPanels[activeTab]
    if panel and panel.Refresh then panel:Refresh() end
end

function PP.MainFrame:IsVisible()
    return mainFrame and mainFrame:IsShown()
end

function PP.MainFrame:Refresh()
    if not mainFrame or not mainFrame:IsShown() then return end
    self:UpdateScanInfo()
    local panel = contentPanels[activeTab]
    if panel and panel.Refresh then panel:Refresh() end
end

function PP.MainFrame:UpdateScanInfo()
    if not mainFrame then return end
    local lastScan = PP.charDb.lastScanTime
    if lastScan and lastScan > 0 then
        mainFrame.scanInfo:SetText("Last scan: " .. PP.Utils.FormatTimeAgo(lastScan))
    else
        mainFrame.scanInfo:SetText("No scan data")
    end
end
