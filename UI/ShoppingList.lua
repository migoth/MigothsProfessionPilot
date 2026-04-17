-- ShoppingList.lua
-- Shopping list panel showing all materials needed to follow the calculated
-- leveling path.  Combines reagent requirements, subtracts inventory, and
-- displays price + total.
--
-- Modern UI redesign using PP.Theme components.

local ADDON_NAME, PP = ...

PP.ShoppingListUI = {}

local T = PP.Theme
local C = T.C

------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------

local ROW_HEIGHT    = 26
local COL_HDR_H     = 24
local HEADER_Y      = -12
local COL_NAME_X    = 12
local COL_NEED_X    = 250
local COL_HAVE_X    = 320
local COL_BUY_X     = 380
local COL_PRICE_X   = 440
local COL_TOTAL_PAD = -12

------------------------------------------------------------------------
-- Panel creation
------------------------------------------------------------------------

--- Creates the shopping list panel.
-- @param parent Frame The content area
-- @return Frame panel (with .Refresh helper)
function PP.ShoppingListUI:Create(parent)
    local L = PP.L

    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()

    -- ── Title (top-left) ────────────────────────────────────────────
    panel.headerText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    panel.headerText:SetPoint("TOPLEFT", 16, HEADER_Y)
    panel.headerText:SetText(L["SHOP_TITLE"])
    panel.headerText:SetTextColor(C(T.palette.textPrimary))

    -- ── Total cost (top-right) ──────────────────────────────────────
    panel.totalCostText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.totalCostText:SetPoint("TOPRIGHT", -16, HEADER_Y)
    panel.totalCostText:SetTextColor(C(T.palette.textPrimary))

    -- ── Column header bar ───────────────────────────────────────────
    local colTop = 36  -- vertical offset where column bar starts
    local colFrame = CreateFrame("Frame", nil, panel)
    colFrame:SetPoint("TOPLEFT", 0, -colTop)
    colFrame:SetPoint("TOPRIGHT", 0, -colTop)
    colFrame:SetHeight(COL_HDR_H)

    colFrame.bg = colFrame:CreateTexture(nil, "BACKGROUND")
    colFrame.bg:SetAllPoints()
    colFrame.bg:SetColorTexture(C(T.palette.card))

    -- Bottom border of column header
    colFrame.border = colFrame:CreateTexture(nil, "ARTWORK")
    colFrame.border:SetHeight(1)
    colFrame.border:SetPoint("BOTTOMLEFT")
    colFrame.border:SetPoint("BOTTOMRIGHT")
    colFrame.border:SetColorTexture(C(T.palette.border))

    -- Helper to stamp out a column label
    local function MakeColLabel(anchor, x, text, justifyH)
        local fs = colFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        if anchor == "LEFT" then
            fs:SetPoint("LEFT", x, 0)
        else
            fs:SetPoint("RIGHT", x, 0)
        end
        fs:SetText(text)
        fs:SetTextColor(C(T.palette.accent))
        if justifyH then fs:SetJustifyH(justifyH) end
        return fs
    end

    MakeColLabel("LEFT",  COL_NAME_X,   L["COL_MATERIAL"], "LEFT")
    MakeColLabel("LEFT",  COL_NEED_X,   L["COL_NEED"])
    MakeColLabel("LEFT",  COL_HAVE_X,   L["COL_HAVE"])
    MakeColLabel("LEFT",  COL_BUY_X,    L["COL_BUY"])
    MakeColLabel("LEFT",  COL_PRICE_X,  L["COL_PRICE"])
    MakeColLabel("RIGHT", COL_TOTAL_PAD, L["COL_TOTAL"])

    -- ── Scroll area (Theme-based) ───────────────────────────────────
    local scrollContainer = CreateFrame("Frame", nil, panel)
    scrollContainer:SetPoint("TOPLEFT", 0, -(colTop + COL_HDR_H))
    scrollContainer:SetPoint("BOTTOMRIGHT", 0, 0)

    local scrollFrame, scrollChild = T:CreateScrollArea(scrollContainer)
    panel.scrollChild = scrollChild

    -- ── Refresh shorthand ───────────────────────────────────────────
    panel.Refresh = function()
        PP.ShoppingListUI:RefreshPanel(panel)
    end

    return panel
end

------------------------------------------------------------------------
-- Refresh / data aggregation
------------------------------------------------------------------------

--- Refreshes the shopping list from current path data.
-- @param panel Frame
function PP.ShoppingListUI:RefreshPanel(panel)
    local L = PP.L
    local scrollChild = panel.scrollChild
    if not scrollChild then return end

    -- Clear previous content via Theme utility
    T:ClearScrollChild(scrollChild)

    local pathData = PP.charDb.lastPath
    if not pathData or not pathData.path or #pathData.path == 0 then
        panel.totalCostText:SetText("")
        T:ShowEmptyState(scrollChild, L["PATH_EMPTY"])
        return
    end

    -- ── Aggregate materials from every path step ────────────────────
    local materials = {}
    for _, step in ipairs(pathData.path) do
        if step.reagents then
            for _, reagent in ipairs(step.reagents) do
                if not reagent.isOptional then
                    local key = reagent.itemID
                    if not materials[key] then
                        materials[key] = {
                            itemID      = key,
                            totalNeeded = 0,
                            unitPrice   = PP.PriceSource:GetPrice(key) or 0,
                            name        = PP.Utils.GetItemName(key) or ("Item:" .. key),
                        }
                    end
                    materials[key].totalNeeded = materials[key].totalNeeded
                        + (reagent.quantity * step.craftCount)
                end
            end
        end
    end

    -- ── Compute inventory / buy / cost ──────────────────────────────
    local sorted = {}
    for _, mat in pairs(materials) do
        local owned   = PP.InventoryScanner:GetItemCount(mat.itemID)
        mat.owned     = owned
        mat.toBuy     = math.max(0, mat.totalNeeded - owned)
        mat.totalCost = mat.toBuy * mat.unitPrice
        sorted[#sorted + 1] = mat
    end
    table.sort(sorted, function(a, b) return a.totalCost > b.totalCost end)

    -- ── Render rows ─────────────────────────────────────────────────
    local yOffset    = 0
    local grandTotal = 0
    for i, mat in ipairs(sorted) do
        yOffset    = self:CreateMaterialRow(scrollChild, yOffset, mat, i)
        grandTotal = grandTotal + mat.totalCost
    end

    panel.totalCostText:SetText(
        string.format(L["PATH_TOTAL_COST"], PP.Utils.FormatMoney(grandTotal))
    )
    scrollChild:SetHeight(math.max(1, yOffset))
end

------------------------------------------------------------------------
-- Material row
------------------------------------------------------------------------

--- Creates a single material row inside the scroll child.
-- @param parent  Frame  Scroll child
-- @param yOffset number  Current vertical cursor
-- @param mat     table   Aggregated material data
-- @param index   number  Row index (1-based)
-- @return number Updated yOffset
function PP.ShoppingListUI:CreateMaterialRow(parent, yOffset, mat, index)
    local L = PP.L

    -- Use Theme row (alternating colors + hover)
    local row = T:CreateRow(parent, yOffset, ROW_HEIGHT, index)

    -- Override OnEnter/OnLeave to add GameTooltip while keeping hover color
    local baseColor = row._baseColor
    row:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(C(T.palette.rowHover))
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(mat.itemID)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(C(baseColor))
        GameTooltip:Hide()
    end)

    -- Shift-click: insert material item link into AH search / chat
    row:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and IsShiftKeyDown() then
            local _, itemLink = GetItemInfo(mat.itemID)
            if itemLink then HandleModifiedItemClick(itemLink) end
        end
    end)

    -- ── Material name ───────────────────────────────────────────────
    local nameFs = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameFs:SetPoint("LEFT", COL_NAME_X, 0)
    nameFs:SetWidth(230)
    nameFs:SetJustifyH("LEFT")
    nameFs:SetText(mat.name)
    nameFs:SetTextColor(C(T.palette.textPrimary))

    -- ── Need ────────────────────────────────────────────────────────
    local needFs = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    needFs:SetPoint("LEFT", COL_NEED_X, 0)
    needFs:SetText(mat.totalNeeded)
    needFs:SetTextColor(C(T.palette.textPrimary))

    -- ── Have (green if sufficient, red if not) ──────────────────────
    local haveFs = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    haveFs:SetPoint("LEFT", COL_HAVE_X, 0)
    if mat.owned >= mat.totalNeeded then
        haveFs:SetText(PP.COLORS.PROFIT .. mat.owned .. "|r")
    else
        haveFs:SetText(PP.COLORS.LOSS .. mat.owned .. "|r")
    end

    -- ── Buy (green "0" or red count) ────────────────────────────────
    local buyFs = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    buyFs:SetPoint("LEFT", COL_BUY_X, 0)
    if mat.toBuy == 0 then
        buyFs:SetText(PP.COLORS.PROFIT .. "0" .. "|r")
    else
        buyFs:SetText(PP.COLORS.LOSS .. mat.toBuy .. "|r")
    end

    -- ── Unit price ──────────────────────────────────────────────────
    local priceFs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    priceFs:SetPoint("LEFT", COL_PRICE_X, 0)
    if mat.unitPrice > 0 then
        priceFs:SetText(PP.Utils.FormatMoneyShort(mat.unitPrice))
    else
        priceFs:SetText(PP.COLORS.LOSS .. L["PRICE_UNKNOWN"] .. "|r")
    end

    -- ── Row total ───────────────────────────────────────────────────
    local totalFs = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    totalFs:SetPoint("RIGHT", COL_TOTAL_PAD, 0)
    if mat.totalCost > 0 then
        totalFs:SetText(PP.Utils.FormatMoney(mat.totalCost))
    elseif mat.toBuy == 0 then
        totalFs:SetText(PP.COLORS.PROFIT .. "0" .. "|r")
    else
        totalFs:SetText(PP.COLORS.LOSS .. "?" .. "|r")
    end

    return yOffset + ROW_HEIGHT + 1
end
