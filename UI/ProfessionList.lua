-- ProfessionList.lua
-- Profession overview panel showing all professions and their expansion tiers.
-- Modern UI redesign using PP.Theme helpers exclusively.
-- Displays current vs max skill with progress bars and highlights incomplete tiers.

local ADDON_NAME, PP = ...

PP.ProfessionListUI = {}

--- Creates the profession list panel.
-- @param parent Frame The content area
-- @return Frame panel with .Refresh function
function PP.ProfessionListUI:Create(parent)
    local L = PP.L
    local T = PP.Theme

    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()

    -- Title at TOPLEFT
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 8, -8)
    title:SetText(L["TAB_PROFESSIONS"])
    title:SetTextColor(T.C(T.palette.textPrimary))

    -- Filter toggle at TOPRIGHT: a small clickable frame with text
    local filterBtn = CreateFrame("Button", nil, panel)
    filterBtn:SetSize(120, 22)
    filterBtn:SetPoint("TOPRIGHT", -8, -9)

    filterBtn.bg = filterBtn:CreateTexture(nil, "BACKGROUND")
    filterBtn.bg:SetAllPoints()
    filterBtn.bg:SetColorTexture(T.C(T.palette.btnNormal))

    -- Indicator square (acts as checkbox visual)
    filterBtn.indicator = filterBtn:CreateTexture(nil, "ARTWORK")
    filterBtn.indicator:SetSize(12, 12)
    filterBtn.indicator:SetPoint("LEFT", 6, 0)
    filterBtn.indicator:SetColorTexture(T.C(T.palette.borderLight))

    filterBtn.label = filterBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    filterBtn.label:SetPoint("LEFT", filterBtn.indicator, "RIGHT", 5, 0)
    filterBtn.label:SetText(L["FILTER_INCOMPLETE"])
    filterBtn.label:SetTextColor(T.C(T.palette.textSecondary))

    panel.filterIncomplete = false

    local function UpdateFilterVisual()
        if panel.filterIncomplete then
            filterBtn.indicator:SetColorTexture(T.C(T.palette.accent))
            filterBtn.label:SetTextColor(T.C(T.palette.textPrimary))
            filterBtn.bg:SetColorTexture(T.C(T.palette.tabActive))
        else
            filterBtn.indicator:SetColorTexture(T.C(T.palette.borderLight))
            filterBtn.label:SetTextColor(T.C(T.palette.textSecondary))
            filterBtn.bg:SetColorTexture(T.C(T.palette.btnNormal))
        end
    end

    filterBtn:SetScript("OnClick", function()
        panel.filterIncomplete = not panel.filterIncomplete
        UpdateFilterVisual()
        PP.ProfessionListUI:RefreshPanel(panel)
    end)

    filterBtn:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(T.C(T.palette.btnHover))
    end)

    filterBtn:SetScript("OnLeave", function(self)
        if panel.filterIncomplete then
            self.bg:SetColorTexture(T.C(T.palette.tabActive))
        else
            self.bg:SetColorTexture(T.C(T.palette.btnNormal))
        end
    end)

    UpdateFilterVisual()

    -- Scroll area below title/filter bar
    local scrollContainer = CreateFrame("Frame", nil, panel)
    scrollContainer:SetPoint("TOPLEFT", 0, -36)
    scrollContainer:SetPoint("BOTTOMRIGHT", 0, 0)

    local scrollFrame, scrollChild = T:CreateScrollArea(scrollContainer)
    panel.scrollChild = scrollChild
    panel.scrollFrame = scrollFrame

    panel.Refresh = function()
        PP.ProfessionListUI:RefreshPanel(panel)
    end

    return panel
end

--- Refreshes the profession list.
-- @param panel Frame
function PP.ProfessionListUI:RefreshPanel(panel)
    local L = PP.L
    local T = PP.Theme
    local scrollChild = panel.scrollChild
    if not scrollChild then return end

    -- Clear existing content
    T:ClearScrollChild(scrollChild)

    local professions = PP.ProfessionScanner:GetAllProfessions()
    local yOffset = 0

    -- Check if we have any data
    local hasData = false
    for _ in pairs(professions) do
        hasData = true
        break
    end

    if not hasData then
        T:ShowEmptyState(scrollChild, L["PROF_EMPTY"], L["PROF_HINT_RECIPES"])
        return
    end

    -- Display each profession and its tiers (skip gathering professions)
    for profID, profData in pairs(professions) do
        if not PP.GATHERING_PROFESSION_IDS[profID] then
            -- Profession section header via Theme
            local profName = profData.name or "Unknown"
            yOffset = T:CreateSectionHeader(scrollChild, yOffset, profName)

            -- Check if recipes are cached for this profession
            local hasRecipes = profData.recipes and next(profData.recipes)
            if not hasRecipes then
                local recipeHint = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                recipeHint:SetPoint("TOPLEFT", 16, -yOffset)
                recipeHint:SetText(PP.COLORS.NEUTRAL .. L["PROF_HINT_RECIPES"] .. "|r")
                yOffset = yOffset + 18
            end

            -- Check if we only have the fallback single tier (no real expansion data)
            local tierCount = 0
            local onlyFallback = false
            for _ in pairs(profData.tiers or {}) do
                tierCount = tierCount + 1
            end
            if tierCount == 1 then
                for id, _ in pairs(profData.tiers) do
                    if id == profID then
                        onlyFallback = true
                    end
                end
            end

            if onlyFallback then
                local hint = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                hint:SetPoint("TOPLEFT", 16, -yOffset)
                hint:SetText(PP.COLORS.GRAY .. L["PROF_HINT_OPEN_TIERS"] .. "|r")
                yOffset = yOffset + 18
            end

            -- Expansion tiers
            local displayedTiers = 0
            for categoryID, tier in pairs(profData.tiers or {}) do
                local isMaxed = tier.skillLevel >= tier.maxSkill
                if not panel.filterIncomplete or not isMaxed then
                    displayedTiers = displayedTiers + 1
                    yOffset = self:CreateTierRow(scrollChild, yOffset, profID, categoryID, tier, displayedTiers, hasRecipes)
                end
            end

            -- If all tiers maxed and filtering is on
            if displayedTiers == 0 and panel.filterIncomplete then
                local allMaxed = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                allMaxed:SetPoint("TOPLEFT", 16, -yOffset)
                allMaxed:SetText(PP.COLORS.MAXED .. L["SKILL_MAXED"] .. "|r")
                yOffset = yOffset + 20
            end

            yOffset = yOffset + 8 -- Spacing between professions
        end
    end

    scrollChild:SetHeight(yOffset)
end

--- Creates a single tier row showing skill progress and a "Calculate" button.
-- @param parent Frame Scroll child
-- @param yOffset number Vertical position
-- @param profID number Profession ID
-- @param categoryID number Category/tier ID
-- @param tier table Tier data {name, skillLevel, maxSkill}
-- @param index number Row index for alternating colors
-- @param hasRecipes boolean Whether recipes have been scanned for this profession
-- @return number Updated yOffset
function PP.ProfessionListUI:CreateTierRow(parent, yOffset, profID, categoryID, tier, index, hasRecipes)
    local L = PP.L
    local T = PP.Theme
    local ROW_HEIGHT = 36

    -- Alternating row via Theme
    local row = T:CreateRow(parent, yOffset, ROW_HEIGHT, index)

    -- Tier name (indented 16px)
    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("LEFT", 16, 0)
    nameText:SetWidth(180)
    nameText:SetJustifyH("LEFT")
    nameText:SetText(tier.name or "Unknown")
    nameText:SetTextColor(T.C(T.palette.textPrimary))

    local isMaxed = tier.skillLevel >= tier.maxSkill

    -- Modern progress bar (180px wide, 10px tall) in center area
    local bar = T:CreateProgressBar(row, 180, 10)
    bar:SetPoint("LEFT", 210, 0)
    bar:SetProgress(tier.skillLevel, tier.maxSkill)

    if isMaxed then
        bar:SetBarColor(T.C(T.palette.barMaxed))
        bar.text:SetText(PP.COLORS.MAXED .. L["SKILL_MAXED"] .. "|r")
    else
        bar:SetBarColor(T.C(T.palette.barIncomplete))
        bar.text:SetText(string.format(L["SKILL_CURRENT"], tier.skillLevel, tier.maxSkill))
    end

    -- For incomplete tiers: remaining points text + Calculate button on right
    if not isMaxed then
        -- Calculate button via Theme
        local calcBtn = T:CreateButton(row, L["BTN_CALCULATE"], 90, 24, true)
        calcBtn:SetPoint("RIGHT", -8, 0)

        if not hasRecipes then
            -- Disable the button and show a tooltip explaining why
            calcBtn:SetEnabled(false)
            calcBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(L["PATH_NEED_RECIPES"], 1, 0.5, 0)
                GameTooltip:AddLine(L["PROF_HINT_RECIPES"], 1, 1, 1, true)
                GameTooltip:Show()
            end)
            calcBtn:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        else
            calcBtn:SetScript("OnClick", function()
                local path, totalCost = PP.PathOptimizer:CalculatePath(
                    profID, categoryID, tier.skillLevel, tier.maxSkill)

                if #path == 0 then
                    PP.charDb.lastPath = {
                        profID = profID,
                        categoryID = categoryID,
                        tierName = tier.name,
                        skillFrom = tier.skillLevel,
                        skillTo = tier.maxSkill,
                        path = {},
                        totalCost = 0,
                        noRecipesAvailable = true,
                    }
                else
                    PP.charDb.lastPath = {
                        profID = profID,
                        categoryID = categoryID,
                        tierName = tier.name,
                        skillFrom = tier.skillLevel,
                        skillTo = tier.maxSkill,
                        path = path,
                        totalCost = totalCost,
                    }
                end

                if PP.AuctionHouseTab and PP.AuctionHouseTab:IsEmbeddedVisible() then
                    PP.AuctionHouseTab:SetEmbeddedTab("path")
                else
                    PP.MainFrame:SetActiveTab("path")
                end
            end)
        end

        -- Remaining points text between bar and button
        local remaining = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        remaining:SetPoint("RIGHT", calcBtn, "LEFT", -8, 0)
        remaining:SetText(PP.COLORS.INCOMPLETE ..
            string.format(L["SKILL_REMAINING"], tier.maxSkill - tier.skillLevel) .. "|r")
    end

    return yOffset + ROW_HEIGHT + 2
end
