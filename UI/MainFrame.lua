-- MainFrame.lua
-- Primary UI window for MigothsProfessionPilot with modern tab navigation.

local ADDON_NAME, PP = ...

PP.MainFrame = {}

local mainFrame = nil
local tabButtons = {}
local contentPanels = {}
local activeTab = "professions"

local FRAME_WIDTH = 720
local FRAME_HEIGHT = 540

--- Initializes the main frame (lazy creation).
function PP.MainFrame:Init() end

--- Creates the main frame.
local function CreateMainFrame()
    if mainFrame then return end
    local L = PP.L
    local T = PP.Theme

    mainFrame = T:CreateWindow("MigothsProfessionPilotMainFrame", FRAME_WIDTH, FRAME_HEIGHT)
    mainFrame:SetPoint("CENTER")
    mainFrame:Hide()

    -- Title bar
    local titleBar, titleText = T:CreateTitleBar(mainFrame, L["MAIN_TITLE"])

    -- Close button
    local closeBtn = T:CreateCloseButton(titleBar, function()
        mainFrame:Hide()
    end)
    closeBtn:SetPoint("RIGHT", -4, 0)

    -- Scan info text (in title bar)
    mainFrame.scanInfo = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mainFrame.scanInfo:SetPoint("RIGHT", closeBtn, "LEFT", -12, 0)
    mainFrame.scanInfo:SetTextColor(PP.Theme.C(T.palette.textMuted))

    -- Scan button (in title bar)
    mainFrame.scanButton = T:CreateButton(titleBar, L["BTN_SCAN"], 70, 22, true)
    mainFrame.scanButton:SetPoint("RIGHT", mainFrame.scanInfo, "LEFT", -8, 0)
    mainFrame.scanButton:SetScript("OnClick", function()
        if PP.Utils.IsAuctionHouseOpen() then
            PP.PriceSource:StartScan()
        else
            PP.Utils.Print(L["AH_NOT_OPEN"])
        end
    end)

    -- Tab bar
    local tabs = {
        { id = "professions", label = L["TAB_PROFESSIONS"] },
        { id = "path",        label = L["TAB_PATH"] },
        { id = "shopping",    label = L["TAB_SHOPPING"] },
        { id = "settings",    label = L["TAB_SETTINGS"] },
    }

    local tabBar
    tabBar, tabButtons = T:CreateTabBar(mainFrame, tabs, function(tabID)
        PP.MainFrame:SetActiveTab(tabID)
    end)
    tabBar:SetPoint("TOPLEFT", 1, -37)
    tabBar:SetPoint("TOPRIGHT", -1, -37)

    -- Content area
    local contentArea = CreateFrame("Frame", nil, mainFrame)
    contentArea:SetPoint("TOPLEFT", 1, -68)
    contentArea:SetPoint("BOTTOMRIGHT", -1, 1)
    mainFrame.contentArea = contentArea

    -- Create panels
    contentPanels["professions"] = PP.ProfessionListUI:Create(contentArea)
    contentPanels["path"] = PP.LevelingPathUI:Create(contentArea)
    contentPanels["shopping"] = PP.ShoppingListUI:Create(contentArea)
    contentPanels["settings"] = PP.MainFrame:CreateSettingsPanel(contentArea)

    tinsert(UISpecialFrames, "MigothsProfessionPilotMainFrame")
    PP.MainFrame:SetActiveTab("professions")
end

--- Creates the settings panel.
-- @param parent Frame The content area
-- @return Frame
function PP.MainFrame:CreateSettingsPanel(parent)
    local L = PP.L
    local T = PP.Theme

    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()

    -- Settings header
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(L["SETTINGS_TITLE"])
    title:SetTextColor(PP.Theme.C(T.palette.textPrimary))

    local yOffset = 48

    -- Include Sellback
    yOffset = T:CreateCheckbox(panel, L["SETTINGS_INCLUDE_SELLBACK"],
        L["SETTINGS_INCLUDE_SELLBACK_DESC"],
        PP.Database:GetSettings().includeSellback,
        function(checked) PP.Database:GetSettings().includeSellback = checked end,
        yOffset)

    -- Use Inventory
    yOffset = T:CreateCheckbox(panel, L["SETTINGS_USE_INVENTORY"],
        L["SETTINGS_USE_INVENTORY_DESC"],
        PP.Database:GetSettings().useInventory,
        function(checked) PP.Database:GetSettings().useInventory = checked end,
        yOffset)

    panel.Refresh = function() end
    return panel
end

--- Sets the active tab.
-- @param tabID string
function PP.MainFrame:SetActiveTab(tabID)
    activeTab = tabID
    PP.Theme:SetActiveTab(tabButtons, tabID)

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
