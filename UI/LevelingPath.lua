-- LevelingPath.lua
-- Displays the calculated leveling path step by step.
-- Shows recipe name, craft count, cost, and skill gain for each step.

local ADDON_NAME, PP = ...

PP.LevelingPathUI = {}

--- Creates the leveling path panel.
-- @param parent Frame The content area
-- @return Frame
function PP.LevelingPathUI:Create(parent)
    local L = PP.L
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()

    -- Header area
    panel.headerText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    panel.headerText:SetPoint("TOPLEFT", 8, -8)
    panel.headerText:SetText(L["PATH_TITLE"])

    panel.totalCostText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.totalCostText:SetPoint("TOPRIGHT", -8, -12)

    panel.skillRangeText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.skillRangeText:SetPoint("TOPLEFT", 8, -28)
    panel.skillRangeText:SetTextColor(0.7, 0.7, 0.7)

    -- Scroll frame for path steps
    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -50)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth())
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)
    panel.scrollChild = scrollChild

    panel.Refresh = function()
        PP.LevelingPathUI:RefreshPanel(panel)
    end

    return panel
end

--- Refreshes the leveling path display with the last calculated path.
-- @param panel Frame
function PP.LevelingPathUI:RefreshPanel(panel)
    local L = PP.L
    local scrollChild = panel.scrollChild
    if not scrollChild then return end

    -- Clear existing content
    for _, child in pairs({scrollChild:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end

    local pathData = PP.charDb.lastPath
    if not pathData or not pathData.path or #pathData.path == 0 then
        panel.headerText:SetText(L["PATH_TITLE"])
        panel.totalCostText:SetText("")
        panel.skillRangeText:SetText("")

        local empty = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        empty:SetPoint("CENTER", 0, 10)
        empty:SetTextColor(0.5, 0.5, 0.5)

        local hint = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hint:SetPoint("TOP", empty, "BOTTOM", 0, -6)
        hint:SetTextColor(0.4, 0.4, 0.4)

        if pathData and pathData.noRecipesAvailable then
            -- Path was calculated but no skillable recipes found
            local tierName = pathData.tierName or ""
            panel.headerText:SetText(L["PATH_TITLE"] .. " - " .. tierName)
            empty:SetText(L["PATH_NO_RECIPES"])
            hint:SetText(L["PATH_NO_RECIPES_HINT"])
        else
            -- No path calculated at all
            empty:SetText(L["PATH_EMPTY"])
            hint:SetText("")
        end

        scrollChild:SetHeight(100)
        return
    end

    -- Update header
    local tierName = pathData.tierName or ""
    panel.headerText:SetText(L["PATH_TITLE"] .. " - " .. tierName)
    panel.totalCostText:SetText(string.format(L["PATH_TOTAL_COST"], PP.Utils.FormatMoney(pathData.totalCost)))
    panel.skillRangeText:SetText(string.format(L["PATH_SKILL_RANGE"], pathData.skillFrom, pathData.skillTo))

    -- Render each step
    local yOffset = 0
    for i, step in ipairs(pathData.path) do
        yOffset = self:CreateStepRow(scrollChild, yOffset, step, i)
    end

    scrollChild:SetHeight(yOffset)
end

--- Creates a single step row in the leveling path.
-- @param parent Frame Scroll child
-- @param yOffset number Vertical position
-- @param step table Path step data
-- @param index number Step number
-- @return number Updated yOffset
function PP.LevelingPathUI:CreateStepRow(parent, yOffset, step, index)
    local L = PP.L
    local ROW_HEIGHT = 70

    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(parent:GetWidth(), ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -yOffset)

    -- Background
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    if index % 2 == 0 then
        row.bg:SetColorTexture(0.12, 0.12, 0.12, 0.5)
    else
        row.bg:SetColorTexture(0.08, 0.08, 0.08, 0.3)
    end

    -- Step number badge
    local stepBadge = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    stepBadge:SetPoint("TOPLEFT", 8, -6)
    stepBadge:SetText(PP.COLORS.HEADER .. string.format(L["PATH_STEP"], index) .. "|r")

    -- Skill range
    local skillRange = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    skillRange:SetPoint("TOPLEFT", 8, -24)
    skillRange:SetText(string.format(L["PATH_SKILL_RANGE"], step.skillFrom, step.skillTo))
    skillRange:SetTextColor(0.6, 0.6, 0.6)

    -- Difficulty indicator
    local diffColor = PP.Utils.GetDifficultyColor(step.difficulty)
    local diffText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    diffText:SetPoint("TOPLEFT", 120, -24)
    if step.skillUpChance >= 1.0 then
        diffText:SetText(diffColor .. L["PATH_GUARANTEED"] .. "|r")
    else
        diffText:SetText(diffColor .. string.format(L["PATH_CHANCE"], step.skillUpChance * 100) .. "|r")
    end

    -- Recipe icon
    if step.icon then
        local iconTex = row:CreateTexture(nil, "ARTWORK")
        iconTex:SetSize(32, 32)
        iconTex:SetPoint("TOPLEFT", 8, -34)
        iconTex:SetTexture(step.icon)
        iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end

    -- Craft instruction
    local craftText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    craftText:SetPoint("TOPLEFT", 46, -38)
    craftText:SetText(string.format(L["PATH_CRAFT"], step.craftCount, step.name or "?"))

    -- Cost breakdown on the right side
    local costLine1 = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    costLine1:SetPoint("TOPRIGHT", -8, -8)
    costLine1:SetText(string.format(L["PATH_COST"], PP.Utils.FormatMoney(step.materialCost)))

    if step.sellback > 0 then
        local costLine2 = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        costLine2:SetPoint("TOPRIGHT", -8, -22)
        costLine2:SetText(string.format(L["PATH_SELLBACK"], PP.COLORS.PROFIT .. PP.Utils.FormatMoneyShort(step.sellback) .. "|r"))
    end

    local netColor = step.netCost > 0 and PP.COLORS.LOSS or PP.COLORS.PROFIT
    local costLine3 = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    costLine3:SetPoint("TOPRIGHT", -8, -36)
    costLine3:SetText(string.format(L["PATH_NET_COST"], netColor .. PP.Utils.FormatMoney(step.netCost) .. "|r"))

    local costLine4 = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    costLine4:SetPoint("TOPRIGHT", -8, -50)
    costLine4:SetText(string.format(L["PATH_COST_PER_POINT"], PP.Utils.FormatMoney(step.costPerPoint)))
    costLine4:SetTextColor(0.7, 0.7, 0.7)

    -- Tooltip on hover showing material breakdown
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(0.2, 0.2, 0.3, 0.6)
        PP.LevelingPathUI:ShowStepTooltip(self, step)
    end)
    row:SetScript("OnLeave", function(self)
        if index % 2 == 0 then
            self.bg:SetColorTexture(0.12, 0.12, 0.12, 0.5)
        else
            self.bg:SetColorTexture(0.08, 0.08, 0.08, 0.3)
        end
        GameTooltip:Hide()
    end)

    return yOffset + ROW_HEIGHT + 2
end

--- Shows a tooltip with material breakdown for a path step.
-- @param anchor Frame
-- @param step table Path step data
function PP.LevelingPathUI:ShowStepTooltip(anchor, step)
    local L = PP.L
    GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")
    GameTooltip:AddLine(step.name or "?", 1, 1, 1)
    GameTooltip:AddLine(string.format("Craft %dx", step.craftCount))
    GameTooltip:AddLine(" ")

    -- Material list
    GameTooltip:AddLine("Materials per craft:", 0, 0.8, 1)
    if step.reagents then
        for _, reagent in ipairs(step.reagents) do
            if not reagent.isOptional then
                local itemName = PP.Utils.GetItemName(reagent.itemID) or ("Item:" .. reagent.itemID)
                local owned = PP.InventoryScanner:GetItemCount(reagent.itemID)
                local totalNeeded = reagent.quantity * step.craftCount
                local toBuy = math.max(0, totalNeeded - owned)

                local statusColor = toBuy == 0 and PP.COLORS.PROFIT or PP.COLORS.LOSS
                local status = toBuy == 0 and L["PATH_HAVE_MATERIALS"]
                    or string.format(L["INV_NEED_TO_BUY"], toBuy)

                GameTooltip:AddDoubleLine(
                    string.format("  %dx %s", reagent.quantity, itemName),
                    statusColor .. status .. "|r",
                    1, 1, 1)
            end
        end
    end

    GameTooltip:Show()
end
