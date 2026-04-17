-- PriceSource.lua
-- AH price scanning and caching for MigothsProfessionPilot.
-- Provides material and crafted item prices for cost calculations.

local ADDON_NAME, PP = ...

PP.PriceSource = {}

local isScanning = false
local scanStartTime = 0
local itemsUpdated = 0

--- Initializes the price source module.
function PP.PriceSource:Init()
    -- Register AH scan result events
    PP:RegisterEvent("REPLICATE_ITEM_LIST_UPDATE", function(self)
        PP.PriceSource:OnReplicateResults()
    end)

    PP:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", function(self)
        PP.PriceSource:OnBrowseResults()
    end)

    PP:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED", function(self, event, itemID)
        PP.PriceSource:OnCommodityResults(itemID)
    end)
end

--- Starts a full AH price scan.
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
    C_AuctionHouse.ReplicateItems()
end

--- Processes replicate scan results.
function PP.PriceSource:OnReplicateResults()
    if not isScanning then return end

    local prices = PP.Database:GetPrices()
    local numItems = C_AuctionHouse.GetNumReplicateItems()

    for i = 0, numItems - 1 do
        local name, texture, count, qualityID, usable, level, levelType,
              minBid, minIncrement, buyoutPrice, bidAmount, highBidder,
              bidderFullName, owner, ownerFullName, saleStatus, itemID,
              hasAllInfo = C_AuctionHouse.GetReplicateItemInfo(i)

        if itemID and buyoutPrice and buyoutPrice > 0 then
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

--- Processes browse results.
function PP.PriceSource:OnBrowseResults()
    local results = C_AuctionHouse.GetBrowseResults()
    local prices = PP.Database:GetPrices()

    for _, result in ipairs(results) do
        local itemID = result.itemKey.itemID
        local minPrice = result.minPrice
        if itemID and minPrice and minPrice > 0 then
            prices[itemID] = {
                minBuyout = minPrice,
                lastScan = time(),
            }
        end
    end
end

--- Processes commodity search results.
-- @param itemID number The commodity item ID
function PP.PriceSource:OnCommodityResults(itemID)
    if not itemID then return end
    local numResults = C_AuctionHouse.GetNumCommoditySearchResults(itemID)
    if numResults == 0 then return end

    local firstResult = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, 1)
    if firstResult and firstResult.unitPrice then
        PP.Database:GetPrices()[itemID] = {
            minBuyout = firstResult.unitPrice,
            lastScan = time(),
        }
    end
end

--- Finalizes the scan.
function PP.PriceSource:FinishScan()
    isScanning = false
    local elapsed = scanStartTime > 0 and debugprofile
        and ((debugprofile() - scanStartTime) / 1000) or 0

    PP.charDb.lastScanTime = time()

    -- Refresh UI if visible
    if PP.MainFrame:IsVisible() then
        PP.MainFrame:Refresh()
    end

    PP.Utils.Print(string.format(PP.L["AH_SCAN_COMPLETE"], itemsUpdated, elapsed))
end

--- Called when AH closes during a scan.
function PP.PriceSource:OnAuctionHouseClosed()
    if isScanning then
        isScanning = false
        PP.Utils.Print(PP.L["AH_SCAN_FAILED"])
    end
end

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
