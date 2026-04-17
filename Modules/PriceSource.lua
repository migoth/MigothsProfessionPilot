-- PriceSource.lua
-- AH price scanning and caching for MigothsProfessionPilot.
-- Scans material prices by sending individual commodity searches for each
-- reagent found in scanned recipes.  Falls back to ReplicateItems when no
-- recipe data is available.

local ADDON_NAME, PP = ...

PP.PriceSource = {}

local isScanning = false
local scanStartTime = 0
local itemsUpdated = 0

-- Targeted material scan state
local scanQueue = {}       -- array of itemIDs to scan
local scanQueueIndex = 0   -- current position in the queue
local scanExpectedID = nil  -- itemID we're waiting for a result on

--- Initializes the price source module.
function PP.PriceSource:Init()
    -- Commodity search results (primary scan method)
    PP:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED", function(self, event, itemID)
        PP.PriceSource:OnCommodityResults(itemID)
    end)

    -- Browse results (opportunistic: picks up data from manual browsing)
    PP:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", function(self)
        PP.PriceSource:OnBrowseResults()
    end)

    -- Replicate results (fallback scan method)
    PP:RegisterEvent("REPLICATE_ITEM_LIST_UPDATE", function(self)
        PP.PriceSource:OnReplicateResults()
    end)
end

------------------------------------------------------------------------
-- Scan entry point
------------------------------------------------------------------------

--- Starts an AH price scan.
-- Scans materials from known recipes one by one using commodity searches.
-- If no recipes are cached yet, falls back to a full AH replicate scan.
function PP.PriceSource:StartScan()
    local L = PP.L

    if not PP.Utils.IsAuctionHouseOpen() then
        PP.Utils.Print(L["AH_NOT_OPEN"])
        return
    end

    if isScanning then return end

    isScanning = true
    scanStartTime = debugprofile and debugprofile() or 0
    itemsUpdated = 0

    PP.Utils.Print(L["AH_SCAN_START"])

    -- Collect unique material IDs from all scanned recipes
    scanQueue = self:CollectMaterialIDs()
    scanQueueIndex = 0
    scanExpectedID = nil

    if #scanQueue > 0 then
        -- Targeted scan: one commodity search per material
        self:ScanNextMaterial()
    else
        -- No recipes cached yet – try a full replicate scan as fallback
        if C_AuctionHouse.ReplicateItems then
            C_AuctionHouse.ReplicateItems()
            -- Safety timeout: if replicate never responds, finish anyway
            C_Timer.After(30, function()
                if isScanning then self:FinishScan() end
            end)
        else
            self:FinishScan()
        end
    end
end

------------------------------------------------------------------------
-- Targeted material scan (one commodity search per item)
------------------------------------------------------------------------

--- Collects all unique material item IDs from scanned recipe reagents.
-- @return table Array of unique item IDs
function PP.PriceSource:CollectMaterialIDs()
    local seen = {}
    local ids = {}

    for _, profData in pairs(PP.ProfessionScanner:GetAllProfessions()) do
        if profData.recipes then
            for _, recipe in pairs(profData.recipes) do
                if recipe.reagents then
                    for _, reagent in ipairs(recipe.reagents) do
                        if not reagent.isOptional then
                            local allIDs = reagent.alternatives
                            if allIDs then
                                for _, id in ipairs(allIDs) do
                                    if not seen[id] then
                                        seen[id] = true
                                        ids[#ids + 1] = id
                                    end
                                end
                            elseif not seen[reagent.itemID] then
                                seen[reagent.itemID] = true
                                ids[#ids + 1] = reagent.itemID
                            end
                        end
                    end
                end
            end
        end
    end

    return ids
end

--- Advances to the next material in the scan queue.
function PP.PriceSource:ScanNextMaterial()
    if not isScanning or not PP.Utils.IsAuctionHouseOpen() then
        self:FinishScan()
        return
    end

    scanQueueIndex = scanQueueIndex + 1
    if scanQueueIndex > #scanQueue then
        self:FinishScan()
        return
    end

    local itemID = scanQueue[scanQueueIndex]
    scanExpectedID = itemID

    -- Send commodity search for this item
    local ok = pcall(function()
        local itemKey = C_AuctionHouse.MakeItemKey(itemID)
        C_AuctionHouse.SendSearchQuery(itemKey, {}, false)
    end)

    if not ok then
        -- Search failed (API missing, throttled, etc.) – skip to next
        C_Timer.After(0.15, function()
            if isScanning then PP.PriceSource:ScanNextMaterial() end
        end)
        return
    end

    -- Timeout: if no commodity result within 2 seconds, skip this item
    -- (it might be a non-commodity item, or the search was throttled)
    local expectedIdx = scanQueueIndex
    C_Timer.After(2, function()
        if isScanning and scanQueueIndex == expectedIdx then
            PP.PriceSource:ScanNextMaterial()
        end
    end)
end

------------------------------------------------------------------------
-- Event handlers
------------------------------------------------------------------------

--- Processes commodity search results.
-- Saves the cheapest price and advances the scan queue if active.
-- @param itemID number The commodity item ID
function PP.PriceSource:OnCommodityResults(itemID)
    if not isScanning then return end
    if not itemID then return end

    local numResults = C_AuctionHouse.GetNumCommoditySearchResults(itemID)
    if numResults > 0 then
        local firstResult = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, 1)
        if firstResult and firstResult.unitPrice then
            PP.Database:GetPrices()[itemID] = {
                minBuyout = firstResult.unitPrice,
                lastScan = time(),
            }
            itemsUpdated = itemsUpdated + 1
        end
    end

    -- Advance to next material if this result matches what we're waiting for
    if itemID == scanExpectedID then
        C_Timer.After(0.1, function()
            if isScanning then PP.PriceSource:ScanNextMaterial() end
        end)
    end
end

--- Processes browse results (opportunistic: user browsing the AH).
function PP.PriceSource:OnBrowseResults()
    if not isScanning then return end

    local ok, results = pcall(C_AuctionHouse.GetBrowseResults)
    if not ok or not results then return end

    local prices = PP.Database:GetPrices()
    for _, result in ipairs(results) do
        local itemID = result.itemKey and result.itemKey.itemID
        local minPrice = result.minPrice
        if itemID and minPrice and minPrice > 0 then
            prices[itemID] = {
                minBuyout = minPrice,
                lastScan = time(),
            }
        end
    end
end

--- Processes replicate scan results (fallback method).
function PP.PriceSource:OnReplicateResults()
    if not isScanning then return end

    local prices = PP.Database:GetPrices()
    local ok, numItems = pcall(C_AuctionHouse.GetNumReplicateItems)
    if not ok or not numItems then
        self:FinishScan()
        return
    end

    for i = 0, numItems - 1 do
        local ok2, name, texture, count, qualityID, usable, level, levelType,
              minBid, minIncrement, buyoutPrice, bidAmount, highBidder,
              bidderFullName, owner, ownerFullName, saleStatus, itemID,
              hasAllInfo = pcall(C_AuctionHouse.GetReplicateItemInfo, i)

        if ok2 and itemID and buyoutPrice and buyoutPrice > 0 then
            local unitPrice = count and count > 1
                and math.floor(buyoutPrice / count)
                or buyoutPrice

            if not prices[itemID] or unitPrice < prices[itemID].minBuyout then
                prices[itemID] = {
                    minBuyout = unitPrice,
                    lastScan = time(),
                }
                itemsUpdated = itemsUpdated + 1
            elseif prices[itemID] then
                prices[itemID].lastScan = time()
            end
        end
    end

    self:FinishScan()
end

------------------------------------------------------------------------
-- Scan lifecycle
------------------------------------------------------------------------

--- Finalizes the scan.
function PP.PriceSource:FinishScan()
    if not isScanning then return end
    isScanning = false

    local elapsed = scanStartTime > 0 and debugprofile
        and ((debugprofile() - scanStartTime) / 1000) or 0

    PP.charDb.lastScanTime = time()

    -- Refresh UI if visible
    if PP.MainFrame and PP.MainFrame:IsVisible() then
        PP.MainFrame:Refresh()
    end
    if PP.AuctionHouseTab then
        PP.AuctionHouseTab:Refresh()
    end

    PP.Utils.Print(string.format(PP.L["AH_SCAN_COMPLETE"], itemsUpdated, elapsed))
end

--- Called when AH closes during a scan.
function PP.PriceSource:OnAuctionHouseClosed()
    if isScanning then
        isScanning = false
        scanQueue = {}
        scanQueueIndex = 0
        scanExpectedID = nil
        PP.Utils.Print(PP.L["AH_SCAN_FAILED"])
    end
end

------------------------------------------------------------------------
-- Price queries
------------------------------------------------------------------------

--- Returns the cached price for an item.
-- @param itemID number The item ID
-- @return number|nil Price in copper
function PP.PriceSource:GetPrice(itemID)
    local prices = PP.Database:GetPrices()
    local data = prices[itemID]
    return data and data.minBuyout or nil
end

--- Returns the estimated sellback value for a crafted item after AH cut.
-- @param itemID number The item ID
-- @return number|nil Net sell value in copper (after 5% cut)
function PP.PriceSource:GetSellbackValue(itemID)
    local price = self:GetPrice(itemID)
    if not price then return nil end
    return math.floor(price * (1 - PP.AH_CUT))
end

--- Returns whether a scan is in progress.
-- @return boolean
function PP.PriceSource:IsScanning()
    return isScanning
end
