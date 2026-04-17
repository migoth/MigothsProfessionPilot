-- InventoryScanner.lua
-- Scans player inventory (bags, bank, reagent bank) for material counts.
-- Used to subtract owned materials from the leveling path cost.

local ADDON_NAME, PP = ...

PP.InventoryScanner = {}

-- Cached item counts: itemID -> total count across all storage
local itemCounts = {}

--- Initializes the inventory scanner.
function PP.InventoryScanner:Init()
    itemCounts = {}
    self:ScanBags()
end

--- Scans all bags for item counts.
-- Includes backpack (0) and bags 1-4.
function PP.InventoryScanner:ScanBags()
    itemCounts = {}

    -- Scan backpack and regular bags (0 = backpack, 1-4 = bags)
    for bag = 0, 4 do
        self:ScanContainer(bag)
    end

    -- Scan reagent bag (bag 5 in retail)
    self:ScanContainer(5)
end

--- Scans the bank when it's open.
-- Called on BANKFRAME_OPENED event if needed.
function PP.InventoryScanner:ScanBank()
    -- Main bank slots (bag -1)
    self:ScanContainer(-1)

    -- Bank bags (6-12)
    for bag = 6, 12 do
        self:ScanContainer(bag)
    end

    -- Reagent bank (bag -3 in retail)
    self:ScanContainer(-3)
end

--- Scans a single container (bag) and adds item counts.
-- @param bagID number The bag/container ID
function PP.InventoryScanner:ScanContainer(bagID)
    local numSlots = C_Container.GetContainerNumSlots(bagID)
    if not numSlots or numSlots == 0 then return end

    for slot = 1, numSlots do
        local itemInfo = C_Container.GetContainerItemInfo(bagID, slot)
        if itemInfo and itemInfo.itemID then
            local itemID = itemInfo.itemID
            local count = itemInfo.stackCount or 1
            itemCounts[itemID] = (itemCounts[itemID] or 0) + count
        end
    end
end

--- Returns the total count of an item across all scanned storage.
-- @param itemID number The item ID
-- @return number Total count (0 if not owned)
function PP.InventoryScanner:GetItemCount(itemID)
    return itemCounts[itemID] or 0
end

--- Returns how many of an item need to be purchased.
-- Subtracts owned quantity from required quantity.
-- @param itemID number The item ID
-- @param needed number How many are required
-- @return number Quantity to buy (0 if already have enough)
function PP.InventoryScanner:GetBuyCount(itemID, needed)
    local owned = self:GetItemCount(itemID)
    return math.max(0, needed - owned)
end

--- Returns the full inventory cache.
-- @return table itemID -> count
function PP.InventoryScanner:GetAllCounts()
    return itemCounts
end

--- Calculates the cost of materials needed for a recipe, subtracting owned items.
-- @param reagents table Array of {itemID, quantity, alternatives}
-- @param craftCount number How many times to craft
-- @return number totalCost in copper (only for items that must be bought)
-- @return table breakdown Array of {itemID, needed, owned, toBuy, unitPrice, cost}
function PP.InventoryScanner:CalculateNetCost(reagents, craftCount)
    craftCount = craftCount or 1
    local totalCost = 0
    local breakdown = {}
    local useInventory = PP.Database:GetSettings().useInventory

    for _, reagent in ipairs(reagents) do
        if not reagent.isOptional then
            -- Find cheapest alternative
            local itemID, unitPrice = PP.ProfessionScanner:FindCheapestAlternative(reagent.alternatives)
            itemID = itemID or reagent.itemID

            local needed = reagent.quantity * craftCount
            local owned = useInventory and self:GetItemCount(itemID) or 0
            local toBuy = math.max(0, needed - owned)
            local cost = unitPrice and (toBuy * unitPrice) or nil

            table.insert(breakdown, {
                itemID = itemID,
                needed = needed,
                owned = math.min(owned, needed),
                toBuy = toBuy,
                unitPrice = unitPrice,
                cost = cost,
            })

            if cost then
                totalCost = totalCost + cost
            end
        end
    end

    return totalCost, breakdown
end
