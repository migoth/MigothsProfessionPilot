-- AuctionHouseTab.lua
-- Adds a Blizzard-style icon tab at the bottom of the Auction House frame
-- that opens MigothsProfessionPilot in a floating panel beside the AH.

local ADDON_NAME, PP = ...

PP.AuctionHouseTab = {}

local ahButton = nil        -- Blizzard-style tab at bottom of AH frame
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
-- Blizzard-style bottom tab (icon only, with tooltip)
------------------------------------------------------------------------

--- Creates a Blizzard-style tab at the bottom of the AH frame.
function PP.AuctionHouseTab:CreateButton()
    local L = PP.L

    -- Find last existing tab (Blizzard tabs, or MCP tab if both addons loaded)
    local lastTab
    for i = 20, 1, -1 do
        local tab = _G["AuctionHouseFrameTab" .. i]
        if tab then
            lastTab = tab
            break
        end
    end
    local mcpTab = _G["MigothsCraftingProfitAHTab"]
    if mcpTab then lastTab = mcpTab end

    -- Create Blizzard-style bottom tab (icon only, no text label)
    ahButton = CreateFrame("Button", "MigothsProfessionPilotAHTab",
                           AuctionHouseFrame, "PanelTabButtonTemplate")
    ahButton:SetText(" ")

    if lastTab then
        ahButton:SetPoint("LEFT", lastTab, "RIGHT", -16, 0)
    else
        ahButton:SetPoint("BOTTOMLEFT", AuctionHouseFrame, "BOTTOMLEFT", 60, -31)
    end

    -- Hide text, show icon only
    local textObj = ahButton.Text or _G[ahButton:GetName() .. "Text"]
    if textObj then textObj:SetAlpha(0) end

    local icon = ahButton:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("CENTER", 0, -3)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    ahButton.icon = icon

    PanelTemplates_TabResize(ahButton, 10, nil, 36, 36)
    PanelTemplates_DeselectTab(ahButton)

    -- Tooltip
    ahButton:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L["AH_TAB_TITLE"])
        GameTooltip:AddLine(L["AH_BTN_TOOLTIP"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    ahButton:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    ahButton:SetScript("OnClick", function()
        PP.AuctionHouseTab:TogglePanel()
    end)

    -- Deselect our tab when a Blizzard AH tab is clicked
    for i = 1, 20 do
        local tab = _G["AuctionHouseFrameTab" .. i]
        if tab then
            tab:HookScript("OnClick", function()
                if isShown then
                    if ahPanel then ahPanel:Hide() end
                    isShown = false
                    PanelTemplates_DeselectTab(ahButton)
                end
            end)
        end
    end
end

--- Updates the tab appearance based on panel visibility.
local function UpdateTabVisual()
    if not ahButton then return end
    if isShown then
        PanelTemplates_SelectTab(ahButton)
    else
        PanelTemplates_DeselectTab(ahButton)
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
