-- AuctionHouseTab.lua
-- Adds a small shortcut button to the Auction House frame that opens
-- MigothsProfessionPilot in a modern floating panel beside the AH.
-- Uses PP.Theme for all styling – no Blizzard standard templates.

local ADDON_NAME, PP = ...

PP.AuctionHouseTab = {}

local ahButton = nil        -- Small icon button on the AH frame
local ahPanel  = nil        -- The floating panel
local isShown  = false       -- Whether our panel is currently visible

------------------------------------------------------------------------
-- Init
------------------------------------------------------------------------

--- Initializes the AH integration. Called once from Init.lua.
function PP.AuctionHouseTab:Init()
    -- Nothing to do here; OnAuctionHouseShow/OnAuctionHouseClosed are called
    -- from the central event handlers in Init.lua.
end

------------------------------------------------------------------------
-- AH lifecycle
------------------------------------------------------------------------

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
    UpdateTabVisual()
end

------------------------------------------------------------------------
-- Vertical side-tab (right edge of AH frame)
------------------------------------------------------------------------

--- Creates a vertical side-tab on the right edge of the AH frame.
function PP.AuctionHouseTab:CreateButton()
    local L = PP.L
    local T = PP.Theme
    local C = T.C

    local TAB_WIDTH  = 28
    local TAB_HEIGHT = 90
    local TAB_YOFF   = -135  -- below MCP tab if both addons loaded

    ahButton = CreateFrame("Button", "MigothsProfessionPilotAHButton", AuctionHouseFrame)
    ahButton:SetSize(TAB_WIDTH, TAB_HEIGHT)
    ahButton:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPRIGHT", -1, TAB_YOFF)
    ahButton:SetFrameStrata("HIGH")

    -- Background
    local bg = ahButton:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(C(T.palette.surface))
    ahButton.bg = bg

    -- Left border (connecting to AH frame)
    local leftBorder = ahButton:CreateTexture(nil, "BORDER")
    leftBorder:SetSize(1, TAB_HEIGHT)
    leftBorder:SetPoint("TOPLEFT", 0, 0)
    leftBorder:SetColorTexture(C(T.palette.border))

    -- Right/top/bottom borders
    local rightBorder = ahButton:CreateTexture(nil, "BORDER")
    rightBorder:SetSize(1, TAB_HEIGHT)
    rightBorder:SetPoint("TOPRIGHT", 0, 0)
    rightBorder:SetColorTexture(C(T.palette.border))

    local topBorder = ahButton:CreateTexture(nil, "BORDER")
    topBorder:SetSize(TAB_WIDTH, 1)
    topBorder:SetPoint("TOPLEFT", 0, 0)
    topBorder:SetColorTexture(C(T.palette.border))

    local bottomBorder = ahButton:CreateTexture(nil, "BORDER")
    bottomBorder:SetSize(TAB_WIDTH, 1)
    bottomBorder:SetPoint("BOTTOMLEFT", 0, 0)
    bottomBorder:SetColorTexture(C(T.palette.border))

    -- Accent stripe (thin cyan line at the very right edge)
    local accent = ahButton:CreateTexture(nil, "ARTWORK")
    accent:SetSize(2, TAB_HEIGHT - 2)
    accent:SetPoint("RIGHT", -1, 0)
    accent:SetColorTexture(C(T.palette.accentDim))
    ahButton.accent = accent

    -- Icon (centered upper area)
    local icon = ahButton:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("TOP", 0, -10)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    ahButton.icon = icon

    -- Vertical label "MPP"
    local letters = { "M", "P", "P" }
    for i, ch in ipairs(letters) do
        local lbl = ahButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOP", 0, -34 - (i - 1) * 14)
        lbl:SetText(ch)
        lbl:SetTextColor(C(T.palette.textSecondary))
    end

    -- Hover / active states
    ahButton:SetScript("OnEnter", function(self)
        if not isShown then
            self.bg:SetColorTexture(C(T.palette.hover))
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["AH_TAB_TITLE"])
        GameTooltip:AddLine(L["AH_BTN_TOOLTIP"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    ahButton:SetScript("OnLeave", function(self)
        if not isShown then
            self.bg:SetColorTexture(C(T.palette.surface))
        end
        GameTooltip:Hide()
    end)

    ahButton:SetScript("OnClick", function()
        PP.AuctionHouseTab:TogglePanel()
    end)
end

--- Updates the side-tab appearance based on panel visibility.
local function UpdateTabVisual()
    if not ahButton then return end
    local T = PP.Theme
    local C = T.C
    if isShown then
        ahButton.bg:SetColorTexture(C(T.palette.tabActive))
        ahButton.accent:SetColorTexture(C(T.palette.accent))
    else
        ahButton.bg:SetColorTexture(C(T.palette.surface))
        ahButton.accent:SetColorTexture(C(T.palette.accentDim))
    end
end

------------------------------------------------------------------------
-- Floating panel (720x500, Theme-styled)
------------------------------------------------------------------------

--- Creates the floating panel that appears beside the AH.
function PP.AuctionHouseTab:CreatePanel()
    local L = PP.L
    local T = PP.Theme
    local C = T.C

    local PANEL_WIDTH  = 720
    local PANEL_HEIGHT = 500

    -- Main window via Theme helper
    ahPanel = T:CreateWindow("MigothsProfessionPilotAHPanel", PANEL_WIDTH, PANEL_HEIGHT)
    ahPanel:ClearAllPoints()
    ahPanel:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPRIGHT", 4, 0)
    ahPanel:Hide()

    ----------------------------------------------------------------
    -- Title bar
    ----------------------------------------------------------------
    local titleBar, titleText = T:CreateTitleBar(ahPanel, L["MAIN_TITLE"])

    -- Close button (right edge of title bar)
    local closeBtn = T:CreateCloseButton(titleBar, function()
        ahPanel:Hide()
        isShown = false
        UpdateTabVisual()
    end)
    closeBtn:SetPoint("RIGHT", -4, 0)

    -- Scan info text (left of close button)
    ahPanel.scanInfo = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ahPanel.scanInfo:SetPoint("RIGHT", closeBtn, "LEFT", -12, 0)
    ahPanel.scanInfo:SetTextColor(C(T.palette.textMuted))

    -- Scan button (left of scan info)
    local scanBtn = T:CreateButton(titleBar, L["BTN_SCAN"], 70, 22, true)
    scanBtn:SetPoint("RIGHT", ahPanel.scanInfo, "LEFT", -8, 0)
    scanBtn:SetScript("OnClick", function()
        PP.PriceSource:StartScan()
    end)

    ----------------------------------------------------------------
    -- Tab bar
    ----------------------------------------------------------------
    local tabs = {
        { id = "professions", label = L["TAB_PROFESSIONS"] },
        { id = "path",        label = L["TAB_PATH"] },
        { id = "shopping",    label = L["TAB_SHOPPING"] },
        { id = "settings",    label = L["TAB_SETTINGS"] },
    }

    local tabBar, tabBtns = T:CreateTabBar(ahPanel, tabs, function(tabID)
        PP.AuctionHouseTab:SetEmbeddedTab(tabID)
    end)
    tabBar:SetPoint("TOPLEFT", 1, -37)
    tabBar:SetPoint("TOPRIGHT", -1, -37)

    ahPanel.tabButtons = tabBtns
    ahPanel.activeTab  = "professions"

    ----------------------------------------------------------------
    -- Content area (below tab bar)
    ----------------------------------------------------------------
    local content = CreateFrame("Frame", nil, ahPanel)
    content:SetPoint("TOPLEFT", 1, -68)
    content:SetPoint("BOTTOMRIGHT", -1, 1)
    ahPanel.content = content

    ----------------------------------------------------------------
    -- Sub-panels
    ----------------------------------------------------------------
    ahPanel.panels = {}
    ahPanel.panels["professions"] = PP.ProfessionListUI:Create(content)
    ahPanel.panels["path"]        = PP.LevelingPathUI:Create(content)
    ahPanel.panels["shopping"]    = PP.ShoppingListUI:Create(content)
    ahPanel.panels["settings"]    = self:CreateEmbeddedSettingsPanel(content)

    -- Activate the default tab
    self:SetEmbeddedTab("professions")
end

------------------------------------------------------------------------
-- Embedded settings panel (Theme checkboxes, no Blizzard templates)
------------------------------------------------------------------------

--- Creates a settings panel for the embedded view.
-- @param parent Frame Content area
-- @return Frame
function PP.AuctionHouseTab:CreateEmbeddedSettingsPanel(parent)
    local L = PP.L
    local T = PP.Theme
    local C = T.C

    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()

    -- Section title
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(L["SETTINGS_TITLE"])
    title:SetTextColor(C(T.palette.textPrimary))

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

------------------------------------------------------------------------
-- Tab switching
------------------------------------------------------------------------

--- Switches the sub-tab inside the panel.
-- @param tabID string
function PP.AuctionHouseTab:SetEmbeddedTab(tabID)
    if not ahPanel then return end

    local T = PP.Theme
    ahPanel.activeTab = tabID

    -- Update tab button visuals via Theme helper
    T:SetActiveTab(ahPanel.tabButtons, tabID)

    -- Show/hide content panels
    for id, panel in pairs(ahPanel.panels) do
        if id == tabID then
            panel:Show()
            if panel.Refresh then panel:Refresh() end
        else
            panel:Hide()
        end
    end
end

------------------------------------------------------------------------
-- Toggle / visibility
------------------------------------------------------------------------

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
    UpdateTabVisual()
end

--- Returns true when the floating panel is currently shown.
function PP.AuctionHouseTab:IsEmbeddedVisible()
    return ahPanel and ahPanel:IsShown()
end

------------------------------------------------------------------------
-- Scan info
------------------------------------------------------------------------

--- Refreshes the active embedded panel (called when profession data changes).
function PP.AuctionHouseTab:Refresh()
    if not ahPanel or not ahPanel:IsShown() then return end
    self:UpdateScanInfo()
    local tab = ahPanel.activeTab or "professions"
    local panel = ahPanel.panels and ahPanel.panels[tab]
    if panel and panel.Refresh then panel:Refresh() end
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
