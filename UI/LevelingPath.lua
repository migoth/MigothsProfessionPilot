-- LevelingPath.lua
-- Displays the calculated leveling path step by step.
-- Modern UI redesign using PP.Theme for consistent styling.
-- Compact layout: difficulty bar + icon + recipe name + craft count + net cost.
-- Hover tooltip shows full cost breakdown and material list.

local ADDON_NAME, PP = ...

PP.LevelingPathUI = {}

local T = PP.Theme
local C = T.C

--- Difficulty index to palette color mapping.
local DIFF_COLORS = {
    [0] = "diffOrange",
    [1] = "diffYellow",
    [2] = "diffGreen",
    [3] = "diffGray",
}

--- Formats a total cost line, showing "Profit" for negative values.
-- @param totalCost number Total net cost in copper
-- @param L table Locale table
-- @return string Formatted cost/profit string
local function FormatTotalCostLine(totalCost, L)
    if totalCost < 0 then
        return string.format(L["PATH_TOTAL_PROFIT"],
            PP.COLORS.PROFIT .. PP.Utils.FormatMoney(math.abs(totalCost)) .. "|r")
    else
        return string.format(L["PATH_TOTAL_COST"], PP.Utils.FormatMoney(totalCost))
    end
end

--- Creates the leveling path panel.
-- @param parent Frame The content area
-- @return Frame
function PP.LevelingPathUI:Create(parent)
    local L = PP.L
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()

    -- Header text (top-left)
    panel.headerText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    panel.headerText:SetPoint("TOPLEFT", 8, -8)
    panel.headerText:SetText(L["PATH_TITLE"])
    panel.headerText:SetTextColor(C(T.palette.textPrimary))

    -- Total cost/profit (top-right)
    panel.totalCostText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.totalCostText:SetPoint("TOPRIGHT", -8, -12)

    -- Skill range line below header
    panel.skillRangeText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    panel.skillRangeText:SetPoint("TOPLEFT", 8, -28)
    panel.skillRangeText:SetTextColor(C(T.palette.textSecondary))

    -- Separator below header area
    panel.headerSep = panel:CreateTexture(nil, "ARTWORK")
    panel.headerSep:SetHeight(1)
    panel.headerSep:SetPoint("TOPLEFT", 0, -46)
    panel.headerSep:SetPoint("TOPRIGHT", 0, -46)
    panel.headerSep:SetColorTexture(C(T.palette.border))

    -- Scroll area container (positioned below header)
    local scrollContainer = CreateFrame("Frame", nil, panel)
    scrollContainer:SetPoint("TOPLEFT", 0, -48)
    scrollContainer:SetPoint("BOTTOMRIGHT", 0, 0)

    local scrollFrame, scrollChild = T:CreateScrollArea(scrollContainer)
    panel.scrollFrame = scrollFrame
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
    T:ClearScrollChild(scrollChild)

    local pathData = PP.charDb.lastPath
    if not pathData or not pathData.path or #pathData.path == 0 then
        panel.headerText:SetText(L["PATH_TITLE"])
        panel.totalCostText:SetText("")
        panel.skillRangeText:SetText("")

        if pathData and pathData.noRecipesAvailable then
            local tierName = pathData.tierName or ""
            panel.headerText:SetText(L["PATH_TITLE"] .. " - " .. tierName)
            T:ShowEmptyState(scrollChild, L["PATH_NO_RECIPES"], L["PATH_NO_RECIPES_HINT"])
        else
            T:ShowEmptyState(scrollChild, L["PATH_EMPTY"])
        end
        return
    end

    -- Update header
    local tierName = pathData.tierName or ""
    panel.headerText:SetText(L["PATH_TITLE"] .. " - " .. tierName)
    panel.totalCostText:SetText(FormatTotalCostLine(pathData.totalCost, L))
    panel.skillRangeText:SetText(string.format(L["PATH_SKILL_RANGE"], pathData.skillFrom, pathData.skillTo))

    -- Render each step
    local yOffset = 0
    for i, step in ipairs(pathData.path) do
        yOffset = self:CreateStepRow(scrollChild, yOffset, step, i)
    end

    scrollChild:SetHeight(yOffset)
end

--- Creates a single compact step row in the leveling path.
-- Layout: [DiffBar][Icon] Step N: Craft Xd RecipeName    Skill A->B    Net Cost
-- @param parent Frame Scroll child
-- @param yOffset number Vertical position
-- @param step table Path step data
-- @param index number Step number
-- @return number Updated yOffset
function PP.LevelingPathUI:CreateStepRow(parent, yOffset, step, index)
    local L = PP.L
    local ROW_HEIGHT = 42

    -- Use Theme row (alternating colors + hover highlight)
    local row = T:CreateRow(parent, yOffset, ROW_HEIGHT, index)

    -- Difficulty color bar on the left edge (3px wide)
    local diffKey = DIFF_COLORS[step.difficulty] or "diffGray"
    local diffBar = row:CreateTexture(nil, "ARTWORK")
    diffBar:SetSize(3, ROW_HEIGHT)
    diffBar:SetPoint("LEFT", 0, 0)
    diffBar:SetColorTexture(C(T.palette[diffKey]))

    -- Recipe icon (28x28)
    local contentLeft = 8
    if step.icon then
        local iconTex = row:CreateTexture(nil, "ARTWORK")
        iconTex:SetSize(28, 28)
        iconTex:SetPoint("LEFT", 8, 0)
        iconTex:SetTexture(step.icon)
        iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        contentLeft = 42
    end

    -- Main text: "Step N: Craft Xd RecipeName"
    local craftText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    craftText:SetPoint("LEFT", contentLeft, 6)
    craftText:SetWidth(parent:GetWidth() - contentLeft - 140)
    craftText:SetJustifyH("LEFT")
    craftText:SetWordWrap(false)

    local stepLabel = string.format(L["PATH_STEP"], index)
    local craftLabel = string.format(L["PATH_CRAFT"], step.craftCount, step.name or "?")
    craftText:SetText(PP.COLORS.HEADER .. stepLabel .. ":|r " .. craftLabel)

    -- Sub-text: skill range "Skill A -> B"
    local skillText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    skillText:SetPoint("TOPLEFT", craftText, "BOTTOMLEFT", 0, -2)
    skillText:SetText(string.format(L["PATH_SKILL_RANGE"], step.skillFrom, step.skillTo))
    skillText:SetTextColor(C(T.palette.textSecondary))

    -- Net cost on the right side
    local costText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    costText:SetPoint("RIGHT", -8, 0)
    if step.netCost < 0 then
        costText:SetText(PP.COLORS.PROFIT .. "+" .. PP.Utils.FormatMoney(math.abs(step.netCost)) .. "|r")
    else
        costText:SetText(PP.Utils.FormatMoney(step.netCost))
    end

    -- Tooltip on hover - override the Theme row's default OnEnter/OnLeave
    -- to add tooltip while preserving hover highlight behavior.
    local baseColor = row._baseColor
    row:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(C(T.palette.rowHover))
        PP.LevelingPathUI:ShowStepTooltip(self, step)
    end)
    row:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(C(baseColor))
        GameTooltip:Hide()
    end)

    -- Click: open crafting window for this recipe
    -- Shift-click: insert crafted item link into AH search / chat
    row:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            if IsShiftKeyDown() and step.outputItemID then
                local _, itemLink = GetItemInfo(step.outputItemID)
                if itemLink then HandleModifiedItemClick(itemLink) end
            elseif step.recipeID and C_TradeSkillUI.OpenRecipe then
                C_TradeSkillUI.OpenRecipe(step.recipeID)
            end
        end
    end)

    return yOffset + ROW_HEIGHT + 1
end

--- Shows a tooltip with cost breakdown and material list for a path step.
-- @param anchor Frame
-- @param step table Path step data
function PP.LevelingPathUI:ShowStepTooltip(anchor, step)
    local L = PP.L
    GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")
    GameTooltip:AddLine(step.name or "?", 1, 1, 1)

    -- Difficulty + skill-up chance
    local diffColor = PP.Utils.GetDifficultyColor(step.difficulty)
    local endDiff = step.endDifficulty or step.difficulty
    if endDiff == step.difficulty then
        -- Single difficulty for the whole step
        if step.skillUpChance >= 1.0 then
            GameTooltip:AddLine(diffColor .. L["PATH_GUARANTEED"] .. "|r")
        else
            GameTooltip:AddLine(diffColor .. string.format(L["PATH_CHANCE"], step.skillUpChance * 100) .. "|r")
        end
    else
        -- Difficulty changes during this step (e.g. orange -> yellow)
        local startChance = step.skillUpChance
        local endChance = PP.Utils.GetSkillUpChance(endDiff)
        local endColor = PP.Utils.GetDifficultyColor(endDiff)
        GameTooltip:AddLine(string.format(
            L["PATH_CHANCE_RANGE"],
            diffColor, startChance * 100, endColor, endChance * 100))
    end

    GameTooltip:AddLine(" ")

    -- Cost breakdown (using string.format so %s placeholders are filled)
    GameTooltip:AddLine(string.format(L["PATH_COST"],
        PP.Utils.FormatMoney(step.materialCost)), 1, 1, 1)
    if step.sellback and step.sellback > 0 then
        GameTooltip:AddLine(string.format(L["PATH_SELLBACK"],
            PP.COLORS.PROFIT .. PP.Utils.FormatMoney(step.sellback) .. "|r"), 1, 1, 1)
        if step.netCost < 0 then
            GameTooltip:AddLine(string.format(L["PATH_NET_COST"],
                PP.COLORS.PROFIT .. "+" .. PP.Utils.FormatMoney(math.abs(step.netCost)) .. "|r"), 1, 1, 1)
        else
            GameTooltip:AddLine(string.format(L["PATH_NET_COST"],
                PP.Utils.FormatMoney(step.netCost)), 1, 1, 1)
        end
    end
    GameTooltip:AddLine(string.format(L["PATH_COST_PER_POINT"],
        PP.Utils.FormatMoney(math.abs(step.costPerPoint))), 0.7, 0.7, 0.7)

    GameTooltip:AddLine(" ")

    -- Material list
    GameTooltip:AddLine(string.format("Materials (x%d crafts):", step.craftCount),
        C(T.palette.accent))
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
                    string.format("  %dx %s", totalNeeded, itemName),
                    statusColor .. status .. "|r",
                    1, 1, 1)
            end
        end
    end

    -- Crafted item info
    if step.outputItemID then
        GameTooltip:AddLine(" ")
        local outputName = PP.Utils.GetItemName(step.outputItemID) or ("Item:" .. step.outputItemID)
        GameTooltip:AddLine("Produces: " .. outputName, C(T.palette.accentDim))
    end

    GameTooltip:Show()
end
