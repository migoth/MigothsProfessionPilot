-- ProfessionList.lua
-- Profession overview panel showing all professions and their expansion tiers.
-- Displays current vs max skill and highlights incomplete tiers.

local ADDON_NAME, PP = ...

PP.ProfessionListUI = {}

--- Creates the profession list panel.
-- @param parent Frame The content area
-- @return Frame
function PP.ProfessionListUI:Create(parent)
    local L = PP.L
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()

    -- Title
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 8, -8)
    title:SetText(L["TAB_PROFESSIONS"])

    -- Filter: incomplete only
    local filterCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    filterCheck:SetSize(22, 22)
    filterCheck:SetPoint("TOPRIGHT", -8, -8)
    filterCheck.text = filterCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    filterCheck.text:SetPoint("RIGHT", filterCheck, "LEFT", -4, 0)
    filterCheck.text:SetText(L["FILTER_INCOMPLETE"])
    panel.filterIncomplete = false
    filterCheck:SetScript("OnClick", function(self)
        panel.filterIncomplete = self:GetChecked()
        PP.ProfessionListUI:RefreshPanel(panel)
    end)

    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -36)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth())
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)
    panel.scrollChild = scrollChild

    panel.Refresh = function()
        PP.ProfessionListUI:RefreshPanel(panel)
    end

    return panel
end

--- Refreshes the profession list.
-- @param panel Frame
function PP.ProfessionListUI:RefreshPanel(panel)
    local L = PP.L
    local scrollChild = panel.scrollChild
    if not scrollChild then return end

    -- Clear existing rows
    for _, child in pairs({scrollChild:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end

    local professions = PP.ProfessionScanner:GetAllProfessions()
    local yOffset = 0

    -- Check if we have any data
    local hasData = false
    for _ in pairs(professions) do hasData = true; break end

    if not hasData then
        local hint = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        hint:SetPoint("CENTER")
        hint:SetText(L["PATH_EMPTY"])
        hint:SetTextColor(0.5, 0.5, 0.5)
        scrollChild:SetHeight(100)
        return
    end

    -- Display each profession and its tiers
    for profID, profData in pairs(professions) do
        -- Profession header
        local header = CreateFrame("Frame", nil, scrollChild)
        header:SetSize(scrollChild:GetWidth(), 28)
        header:SetPoint("TOPLEFT", 0, -yOffset)

        header.bg = header:CreateTexture(nil, "BACKGROUND")
        header.bg:SetAllPoints()
        header.bg:SetColorTexture(0.15, 0.15, 0.25, 0.8)

        local profName = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        profName:SetPoint("LEFT", 8, 0)
        profName:SetText(PP.COLORS.HEADER .. (profData.name or "Unknown") .. "|r")

        yOffset = yOffset + 30

        -- Expansion tiers
        local tierCount = 0
        for categoryID, tier in pairs(profData.tiers or {}) do
            local isMaxed = tier.skillLevel >= tier.maxSkill
            if not panel.filterIncomplete or not isMaxed then
                tierCount = tierCount + 1
                yOffset = self:CreateTierRow(scrollChild, yOffset, profID, categoryID, tier, tierCount)
            end
        end

        -- If no tiers shown for this profession (e.g. all maxed and filtering)
        if tierCount == 0 and panel.filterIncomplete then
            local allMaxed = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            allMaxed:SetPoint("TOPLEFT", 16, -yOffset)
            allMaxed:SetText(PP.COLORS.MAXED .. L["SKILL_MAXED"] .. "|r")
            yOffset = yOffset + 20
        end

        yOffset = yOffset + 8  -- Spacing between professions
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
-- @return number Updated yOffset
function PP.ProfessionListUI:CreateTierRow(parent, yOffset, profID, categoryID, tier, index)
    local L = PP.L
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(parent:GetWidth(), 32)
    row:SetPoint("TOPLEFT", 0, -yOffset)

    -- Alternating background
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(index % 2 == 0 and 0.1 or 0.07, index % 2 == 0 and 0.1 or 0.07, 0.12, 0.5)

    -- Tier name (expansion)
    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("LEFT", 16, 0)
    nameText:SetWidth(200)
    nameText:SetJustifyH("LEFT")
    nameText:SetText(tier.name or "Unknown")

    -- Skill progress bar
    local barBg = CreateFrame("Frame", nil, row)
    barBg:SetSize(200, 16)
    barBg:SetPoint("LEFT", 230, 0)
    barBg.bg = barBg:CreateTexture(nil, "BACKGROUND")
    barBg.bg:SetAllPoints()
    barBg.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)

    local barFill = barBg:CreateTexture(nil, "ARTWORK")
    barFill:SetPoint("LEFT")
    barFill:SetHeight(16)
    local progress = tier.maxSkill > 0 and (tier.skillLevel / tier.maxSkill) or 0
    barFill:SetWidth(math.max(1, 200 * progress))

    local isMaxed = tier.skillLevel >= tier.maxSkill
    if isMaxed then
        barFill:SetColorTexture(0, 0.7, 0, 0.8)
    else
        barFill:SetColorTexture(0.8, 0.5, 0, 0.8)
    end

    -- Skill text overlay
    local skillText = barBg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    skillText:SetPoint("CENTER")
    if isMaxed then
        skillText:SetText(PP.COLORS.MAXED .. L["SKILL_MAXED"] .. "|r")
    else
        skillText:SetText(string.format(L["SKILL_CURRENT"], tier.skillLevel, tier.maxSkill))
    end

    -- Calculate button (only for incomplete tiers)
    if not isMaxed then
        local calcBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        calcBtn:SetSize(90, 22)
        calcBtn:SetPoint("RIGHT", -8, 0)
        calcBtn:SetText(L["BTN_CALCULATE"])
        calcBtn:SetScript("OnClick", function()
            -- Calculate path and switch to path tab
            local path, totalCost = PP.PathOptimizer:CalculatePath(
                profID, categoryID, tier.skillLevel, tier.maxSkill)
            PP.charDb.lastPath = {
                profID = profID,
                categoryID = categoryID,
                tierName = tier.name,
                skillFrom = tier.skillLevel,
                skillTo = tier.maxSkill,
                path = path,
                totalCost = totalCost,
            }
            PP.MainFrame:SetActiveTab("path")
        end)

        -- Remaining points
        local remaining = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        remaining:SetPoint("RIGHT", calcBtn, "LEFT", -8, 0)
        remaining:SetText(PP.COLORS.INCOMPLETE ..
            string.format(L["SKILL_REMAINING"], tier.maxSkill - tier.skillLevel) .. "|r")
    end

    return yOffset + 34
end
