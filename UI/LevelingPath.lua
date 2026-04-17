-- LevelingPath.lua
-- Displays the calculated leveling path step by step.
-- Compact layout: icon + recipe name + craft count + net cost.
-- Hover tooltip shows full cost breakdown and material list.

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
-- Layout: [Icon] Step N: Craft Xd RecipeName    Skill A->B    Net Cost
-- @param parent Frame Scroll child
-- @param yOffset number Vertical position
-- @param step table Path step data
-- @param index number Step number
-- @return number Updated yOffset
function PP.LevelingPathUI:CreateStepRow(parent, yOffset, step, index)
    local L = PP.L
    local ROW_HEIGHT = 36

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

    -- Difficulty color bar on the left edge
    local diffColor = PP.Utils.GetDifficultyColor(step.difficulty)
    local diffBar = row:CreateTexture(nil, "ARTWORK")
    diffBar:SetSize(3, ROW_HEIGHT)
    diffBar:SetPoint("LEFT", 0, 0)
    if step.difficulty == 0 then
        diffBar:SetColorTexture(1, 0.5, 0.25, 1)     -- Orange
    elseif step.difficulty == 1 then
        diffBar:SetColorTexture(1, 1, 0, 1)           -- Yellow
    elseif step.difficulty == 2 then
        diffBar:SetColorTexture(0.25, 0.75, 0.25, 1)  -- Green
    else
        diffBar:SetColorTexture(0.5, 0.5, 0.5, 1)     -- Gray
    end

    -- Recipe icon
    local iconOffset = 8
    if step.icon then
        local iconTex = row:CreateTexture(nil, "ARTWORK")
        iconTex:SetSize(24, 24)
        iconTex:SetPoint("LEFT", 8, 0)
        iconTex:SetTexture(step.icon)
        iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        iconOffset = 38
    end

    -- Craft instruction: "Step 1: Craft 15x Bronze Shortsword"
    local craftText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    craftText:SetPoint("LEFT", iconOffset, 4)
    craftText:SetWidth(parent:GetWidth() - iconOffset - 180)
    craftText:SetJustifyH("LEFT")
    craftText:SetWordWrap(false)
    craftText:SetText(PP.COLORS.HEADER .. string.format(L["PATH_STEP"], index) .. ":|r "
        .. string.format(L["PATH_CRAFT"], step.craftCount, step.name or "?"))

    -- Skill range below the craft text
    local skillText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    skillText:SetPoint("TOPLEFT", craftText, "BOTTOMLEFT", 0, -1)
    skillText:SetText(string.format(L["PATH_SKILL_RANGE"], step.skillFrom, step.skillTo))
    skillText:SetTextColor(0.6, 0.6, 0.6)

    -- Net cost on the right side
    local costText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    costText:SetPoint("RIGHT", -8, 0)
    if step.netCost < 0 then
        costText:SetText(PP.COLORS.PROFIT .. "+" .. PP.Utils.FormatMoney(math.abs(step.netCost)) .. "|r")
    else
        costText:SetText(PP.Utils.FormatMoney(step.netCost))
    end

    -- Tooltip on hover showing full breakdown + materials
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
    if step.skillUpChance >= 1.0 then
        GameTooltip:AddLine(diffColor .. L["PATH_GUARANTEED"] .. "|r")
    else
        GameTooltip:AddLine(diffColor .. string.format(L["PATH_CHANCE"], step.skillUpChance * 100) .. "|r")
    end

    GameTooltip:AddLine(" ")

    -- Cost breakdown
    GameTooltip:AddDoubleLine(L["PATH_COST"], PP.Utils.FormatMoney(step.materialCost), 1, 1, 1)
    if step.sellback > 0 then
        GameTooltip:AddDoubleLine(L["PATH_SELLBACK"],
            PP.COLORS.PROFIT .. PP.Utils.FormatMoney(step.sellback) .. "|r", 1, 1, 1)
    end
    if step.netCost < 0 then
        GameTooltip:AddDoubleLine(L["PATH_NET_COST"],
            PP.COLORS.PROFIT .. "+" .. PP.Utils.FormatMoney(math.abs(step.netCost)) .. "|r", 1, 1, 1)
    else
        GameTooltip:AddDoubleLine(L["PATH_NET_COST"], PP.Utils.FormatMoney(step.netCost), 1, 1, 1)
    end
    GameTooltip:AddDoubleLine(L["PATH_COST_PER_POINT"], PP.Utils.FormatMoney(math.abs(step.costPerPoint)), 0.7, 0.7, 0.7)

    GameTooltip:AddLine(" ")

    -- Material list
    GameTooltip:AddLine(string.format("Materials (x%d crafts):", step.craftCount), 0, 0.8, 1)
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
                    string.format("  %dx %s", reagent.quantity * step.craftCount, itemName),
                    statusColor .. status .. "|r",
                    1, 1, 1)
            end
        end
    end

    -- Crafted item info
    if step.outputItemID then
        GameTooltip:AddLine(" ")
        local outputName = PP.Utils.GetItemName(step.outputItemID) or ("Item:" .. step.outputItemID)
        GameTooltip:AddLine("Produces: " .. outputName, 0.7, 0.8, 1)
    end

    GameTooltip:Show()
end
