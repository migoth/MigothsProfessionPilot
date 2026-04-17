-- ShoppingList.lua
-- Shopping list panel showing all materials needed to follow the calculated
-- leveling path.  Combines reagent requirements, subtracts inventory, and
-- displays price + total.

local ADDON_NAME, PP = ...

PP.ShoppingListUI = {}

--- Creates the shopping list panel.
-- @param parent Frame The content area
-- @return Frame
function PP.ShoppingListUI:Create(parent)
    local L = PP.L
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()

    -- Header
    panel.headerText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    panel.headerText:SetPoint("TOPLEFT", 8, -8)
    panel.headerText:SetText(L["SHOP_TITLE"])

    -- Total cost
    panel.totalCostText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.totalCostText:SetPoint("TOPRIGHT", -8, -12)

    -- Column headers
    local colHeaderHeight = 30
    local colFrame = CreateFrame("Frame", nil, panel)
    colFrame:SetPoint("TOPLEFT", 8, -colHeaderHeight)
    colFrame:SetPoint("TOPRIGHT", -28, -colHeaderHeight)
    colFrame:SetHeight(20)
    colFrame.bg = colFrame:CreateTexture(nil, "BACKGROUND")
    colFrame.bg:SetAllPoints()
    colFrame.bg:SetColorTexture(0.15, 0.15, 0.2, 0.8)

    local colItem = colFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    colItem:SetPoint("LEFT", 8, 0)
    colItem:SetText(L["COL_MATERIAL"])
    colItem:SetTextColor(0.7, 0.8, 1)

    local colNeed = colFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    colNeed:SetPoint("LEFT", 250, 0)
    colNeed:SetText(L["COL_NEED"])
    colNeed:SetTextColor(0.7, 0.8, 1)

    local colHave = colFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    colHave:SetPoint("LEFT", 320, 0)
    colHave:SetText(L["COL_HAVE"])
    colHave:SetTextColor(0.7, 0.8, 1)

    local colBuy = colFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    colBuy:SetPoint("LEFT", 380, 0)
    colBuy:SetText(L["COL_BUY"])
    colBuy:SetTextColor(0.7, 0.8, 1)

    local colPrice = colFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    colPrice:SetPoint("LEFT", 440, 0)
    colPrice:SetText(L["COL_PRICE"])
    colPrice:SetTextColor(0.7, 0.8, 1)

    local colTotal = colFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    colTotal:SetPoint("RIGHT", -8, 0)
    colTotal:SetText(L["COL_TOTAL"])
    colTotal:SetTextColor(0.7, 0.8, 1)

    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -(colHeaderHeight + 22))
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth())
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)
    panel.scrollChild = scrollChild

    panel.Refresh = function()
        PP.ShoppingListUI:RefreshPanel(panel)
    end

    return panel
end

--- Refreshes the shopping list.
-- @param panel Frame
function PP.ShoppingListUI:RefreshPanel(panel)
    local L = PP.L
    local scrollChild = panel.scrollChild
    if not scrollChild then return end

    -- Clear rows
    for _, child in pairs({scrollChild:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end

    local pathData = PP.charDb.lastPath
    if not pathData or not pathData.path or #pathData.path == 0 then
        panel.totalCostText:SetText("")
        local empty = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        empty:SetPoint("CENTER")
        empty:SetText(L["PATH_EMPTY"])
        empty:SetTextColor(0.5, 0.5, 0.5)
        scrollChild:SetHeight(100)
        return
    end

    -- Aggregate materials from all path steps
    local materials = {}  -- itemID -> { totalNeeded, unitPrice, name }
    for _, step in ipairs(pathData.path) do
        if step.reagents then
            for _, reagent in ipairs(step.reagents) do
                if not reagent.isOptional then
                    local key = reagent.itemID
                    if not materials[key] then
                        materials[key] = {
                            itemID = key,
                            totalNeeded = 0,
                            unitPrice = PP.PriceSource:GetPrice(key) or 0,
                            name = PP.Utils.GetItemName(key) or ("Item:" .. key),
                        }
                    end
                    materials[key].totalNeeded = materials[key].totalNeeded + (reagent.quantity * step.craftCount)
                end
            end
        end
    end

    -- Sort by total cost descending (most expensive first)
    local sorted = {}
    for _, mat in pairs(materials) do
        local owned = PP.InventoryScanner:GetItemCount(mat.itemID)
        mat.owned = owned
        mat.toBuy = math.max(0, mat.totalNeeded - owned)
        mat.totalCost = mat.toBuy * mat.unitPrice
        table.insert(sorted, mat)
    end
    table.sort(sorted, function(a, b) return a.totalCost > b.totalCost end)

    -- Render rows
    local yOffset = 0
    local grandTotal = 0
    for i, mat in ipairs(sorted) do
        yOffset = self:CreateMaterialRow(scrollChild, yOffset, mat, i)
        grandTotal = grandTotal + mat.totalCost
    end

    panel.totalCostText:SetText(string.format(L["PATH_TOTAL_COST"], PP.Utils.FormatMoney(grandTotal)))
    scrollChild:SetHeight(yOffset)
end

--- Creates a single material row.
-- @param parent Frame Scroll child
-- @param yOffset number Vertical position
-- @param mat table Material data
-- @param index number Row index
-- @return number Updated yOffset
function PP.ShoppingListUI:CreateMaterialRow(parent, yOffset, mat, index)
    local L = PP.L
    local ROW_HEIGHT = 24

    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(parent:GetWidth(), ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -yOffset)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(index % 2 == 0 and 0.1 or 0.07, index % 2 == 0 and 0.1 or 0.07, 0.12, 0.5)

    -- Highlight on hover + item tooltip
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(0.2, 0.2, 0.3, 0.6)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(mat.itemID)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(index % 2 == 0 and 0.1 or 0.07, index % 2 == 0 and 0.1 or 0.07, 0.12, 0.5)
        GameTooltip:Hide()
    end)

    -- Material name
    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("LEFT", 8, 0)
    nameText:SetWidth(236)
    nameText:SetJustifyH("LEFT")
    nameText:SetText(mat.name)

    -- Total needed
    local needText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    needText:SetPoint("LEFT", 250, 0)
    needText:SetText(mat.totalNeeded)

    -- Owned
    local haveText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    haveText:SetPoint("LEFT", 320, 0)
    if mat.owned >= mat.totalNeeded then
        haveText:SetText(PP.COLORS.PROFIT .. mat.owned .. "|r")
    else
        haveText:SetText(PP.COLORS.LOSS .. mat.owned .. "|r")
    end

    -- To buy
    local buyText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    buyText:SetPoint("LEFT", 380, 0)
    if mat.toBuy == 0 then
        buyText:SetText(PP.COLORS.PROFIT .. "0" .. "|r")
    else
        buyText:SetText(PP.COLORS.LOSS .. mat.toBuy .. "|r")
    end

    -- Unit price
    local priceText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    priceText:SetPoint("LEFT", 440, 0)
    if mat.unitPrice > 0 then
        priceText:SetText(PP.Utils.FormatMoneyShort(mat.unitPrice))
    else
        priceText:SetText(PP.COLORS.LOSS .. L["PRICE_UNKNOWN"] .. "|r")
    end

    -- Row total
    local totalText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    totalText:SetPoint("RIGHT", -8, 0)
    if mat.totalCost > 0 then
        totalText:SetText(PP.Utils.FormatMoney(mat.totalCost))
    elseif mat.toBuy == 0 then
        totalText:SetText(PP.COLORS.PROFIT .. "0" .. "|r")
    else
        totalText:SetText(PP.COLORS.LOSS .. "?" .. "|r")
    end

    return yOffset + ROW_HEIGHT + 1
end
