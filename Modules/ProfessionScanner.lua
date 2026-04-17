-- ProfessionScanner.lua
-- Scans all character professions and their expansion-specific skill tiers.
-- Reads known recipes, skill levels, difficulty, and specialization data.
--
-- Two scanning modes:
--   1) Proactive scan (addon load): uses GetProfessions() +
--      C_TradeSkillUI.GetProfessionInfoBySkillLineID() to detect professions
--      and expansion tiers WITHOUT requiring the trade skill window.
--   2) Detailed scan (trade skill window open): reads recipes, reagents,
--      and difficulty via C_TradeSkillUI when TRADE_SKILL_LIST_UPDATE fires.

local ADDON_NAME, PP = ...

PP.ProfessionScanner = {}

-- Cache of scanned profession data
-- Structure: { professionID -> { name, tiers -> { skillLevel, maxSkill, recipes[] } } }
local professionCache = {}

-- Mapping: Enum.Profession value -> base skill line ID (cache key)
-- Populated by ScanExpansionTiers so ScanCurrentProfession can find the right entry.
local enumToSkillLine = {}

-- Auto-scan state for proactive profession opening
local autoScanQueue = {}
local isAutoScanning = false

-- The skill line ID we intentionally opened during auto-scan.
-- Used by ScanCurrentProfession to resolve the correct cache key.
local expectedSkillLineID = nil

--- Initializes the profession scanner.
-- Restores cached data from SavedVariables and schedules a proactive scan.
function PP.ProfessionScanner:Init()
    -- Restore previous scan data from character DB
    if PP.charDb and PP.charDb.professions then
        for profID, data in pairs(PP.charDb.professions) do
            professionCache[profID] = data
        end
    end

    -- Schedule a proactive scan shortly after login to pick up professions
    -- without requiring the user to open the trade skill window.
    C_Timer.After(2, function()
        PP.ProfessionScanner:ScanAllProfessions()
    end)
end

--- Returns whether an auto-scan is currently in progress.
function PP.ProfessionScanner:IsAutoScanning()
    return isAutoScanning
end

------------------------------------------------------------------------
-- Proactive scan: detect professions and expansion tiers at login
------------------------------------------------------------------------

--- Collects the character's profession indices, handling nil gaps from
-- GetProfessions() (prof1, prof2, archaeology, fishing, cooking).
local function CollectProfessions()
    local prof1, prof2, _, fishing, cooking = GetProfessions()
    local professions = {}
    if prof1 then table.insert(professions, prof1) end
    if prof2 then table.insert(professions, prof2) end
    if fishing then table.insert(professions, fishing) end
    if cooking then table.insert(professions, cooking) end
    return professions
end

--- Scans all known professions using APIs that work without the
-- trade skill window being open. If no recipe data is cached,
-- triggers an automatic scan by briefly opening each profession.
function PP.ProfessionScanner:ScanAllProfessions()
    local professions = CollectProfessions()

    -- Scan primary crafting professions + cooking + fishing
    for _, profIndex in ipairs(professions) do
        self:ScanProfessionByIndex(profIndex)
    end

    -- Persist to SavedVariables
    self:PersistAll()

    -- If any profession lacks recipe data, auto-scan all of them
    local needsAutoScan = false
    for _, profData in pairs(professionCache) do
        if not profData.recipes or not next(profData.recipes) then
            needsAutoScan = true
            break
        end
    end

    if needsAutoScan then
        self:AutoScanProfessions()
    end
end

--- Scans a single profession using its spellbook tab index.
-- Uses GetProfessionInfo() for basic data and then tries to read
-- expansion-specific skill tiers via C_TradeSkillUI.
-- @param profIndex number Spellbook profession tab index
function PP.ProfessionScanner:ScanProfessionByIndex(profIndex)
    local name, icon, skillLevel, maxSkillLevel, numAbilities,
          spellOffset, skillLineID, skillModifier = GetProfessionInfo(profIndex)
    if not skillLineID then return end

    local profID = skillLineID

    if not professionCache[profID] then
        professionCache[profID] = {
            name = name or "Unknown",
            professionID = profID,
            icon = icon,
            tiers = {},
            recipes = {},
        }
    end

    local cache = professionCache[profID]
    cache.name = name or cache.name
    cache.icon = icon or cache.icon

    -- Try reading expansion-specific child skill lines.
    -- C_TradeSkillUI.GetAllProfTradeSkillLines() returns all skill line IDs
    -- for the character's professions (works outside the trade skill window).
    self:ScanExpansionTiers(profID)

    -- Fallback: if no expansion tiers were found, store the overall skill
    -- as a single tier so the UI still shows something useful.
    if not next(cache.tiers) then
        cache.tiers[profID] = {
            categoryID = profID,
            name = name or "Unknown",
            skillLevel = skillLevel or 0,
            maxSkill = maxSkillLevel or 0,
            recipes = cache.tiers[profID] and cache.tiers[profID].recipes or {},
        }
    end
end

--- Scans expansion-specific skill tiers for a given profession.
-- Groups all trade skill lines by parentProfessionID, then matches
-- the correct group to our profession using multiple fallback strategies:
--   1) parentProfessionID matches profID directly
--   2) profID appears as a child line in a group
--   3) Enum resolution: GetProfessionInfoBySkillLineID(profID) gives
--      a professionID that matches a parentProfessionID
--   4) Name matching: a child's professionName contains our profession name
--      (case-insensitive substring match)
-- @param profID number The base profession skill line ID
function PP.ProfessionScanner:ScanExpansionTiers(profID)
    local cache = professionCache[profID]
    if not cache then return end

    if not (C_TradeSkillUI.GetAllProfTradeSkillLines
            and C_TradeSkillUI.GetProfessionInfoBySkillLineID) then
        return
    end

    local allLines = C_TradeSkillUI.GetAllProfTradeSkillLines()
    if not allLines or #allLines == 0 then return end

    -- Step 1: Collect info for every skill line and group by parentProfessionID
    local lineInfos = {}   -- lineID -> ProfessionInfo
    local groups = {}      -- parentProfID -> { lineID -> ProfessionInfo }

    for _, lineID in ipairs(allLines) do
        local ok, info = pcall(
            C_TradeSkillUI.GetProfessionInfoBySkillLineID, lineID)
        if ok and info then
            lineInfos[lineID] = info
            local parent = info.parentProfessionID
            if parent then
                if not groups[parent] then groups[parent] = {} end
                groups[parent][lineID] = info
            end
        end
    end

    -- Step 2: Find which group belongs to our profession
    local myGroup = nil
    local myEnum = nil

    -- Strategy A: profID is itself a parentProfessionID
    if not myGroup and groups[profID] then
        myGroup = groups[profID]
        myEnum = profID
    end

    -- Strategy B: Resolve our enum via GetProfessionInfoBySkillLineID
    if not myGroup then
        local baseInfo = lineInfos[profID]
        if not baseInfo then
            local ok
            ok, baseInfo = pcall(
                C_TradeSkillUI.GetProfessionInfoBySkillLineID, profID)
            if not ok then baseInfo = nil end
        end
        if baseInfo then
            -- Try every numeric field that could be the enum value
            for _, candidate in ipairs({
                baseInfo.professionID,
                baseInfo.parentProfessionID,
            }) do
                if candidate and groups[candidate] then
                    myGroup = groups[candidate]
                    myEnum = candidate
                    break
                end
            end
        end
    end

    -- Strategy C: profID appears as one of the child line IDs
    if not myGroup then
        for parentID, children in pairs(groups) do
            if children[profID] then
                myGroup = children
                myEnum = parentID
                break
            end
        end
    end

    -- Strategy D: Name matching (case-insensitive substring)
    if not myGroup and cache.name then
        local myNameLower = cache.name:lower()
        for parentID, children in pairs(groups) do
            for _, info in pairs(children) do
                local cName = (info.professionName or ""):lower()
                local eName = (info.expansionName or ""):lower()
                if (cName ~= "" and (cName == myNameLower
                        or myNameLower:find(cName, 1, true)
                        or cName:find(myNameLower, 1, true)))
                    or (eName ~= "" and (eName == myNameLower
                        or myNameLower:find(eName, 1, true)
                        or eName:find(myNameLower, 1, true)))
                then
                    myGroup = children
                    myEnum = parentID
                    break
                end
            end
            if myGroup then break end
        end
    end

    -- Step 3: Add all children from the matched group as tiers
    if myGroup then
        if myEnum and myEnum ~= profID then
            enumToSkillLine[myEnum] = profID
        end

        for lineID, info in pairs(myGroup) do
            -- Use expansionName first (e.g. "Classic Alchemy") so each
            -- tier has a distinct label; fall back to professionName.
            cache.tiers[lineID] = {
                categoryID = lineID,
                name = info.expansionName or info.professionName or "Unknown",
                skillLevel = info.skillLevel or 0,
                maxSkill = info.maxSkillLevel or 0,
                recipes = cache.tiers[lineID]
                    and cache.tiers[lineID].recipes or {},
            }
        end
    end

    -- Method 2: GetChildProfessionInfos (alternative/newer API)
    if not next(cache.tiers) and C_TradeSkillUI.GetChildProfessionInfos then
        local ok, children = pcall(C_TradeSkillUI.GetChildProfessionInfos)
        if ok and children then
            for _, childInfo in ipairs(children) do
                local id = childInfo.professionID or childInfo.skillLineID
                if id then
                    cache.tiers[id] = {
                        categoryID = id,
                        name = childInfo.expansionName
                            or childInfo.professionName or "Unknown",
                        skillLevel = childInfo.skillLevel or 0,
                        maxSkill = childInfo.maxSkillLevel or 0,
                        recipes = cache.tiers[id]
                            and cache.tiers[id].recipes or {},
                    }
                end
            end
        end
    end

    -- Clean up: if real expansion tiers were found, remove the fallback
    -- single-tier entry (which has key == profID)
    if cache.tiers[profID] then
        local hasRealTiers = false
        for tierID, _ in pairs(cache.tiers) do
            if tierID ~= profID then
                hasRealTiers = true
                break
            end
        end
        if hasRealTiers then
            cache.tiers[profID] = nil
        end
    end
end

------------------------------------------------------------------------
-- Auto-scan: silently open each profession to load full data
------------------------------------------------------------------------

--- Queues all professions that lack recipe data for automatic scanning.
function PP.ProfessionScanner:AutoScanProfessions()
    local professions = CollectProfessions()

    autoScanQueue = {}
    for _, profIndex in ipairs(professions) do
        local _, _, _, _, _, _, skillLineID = GetProfessionInfo(profIndex)
        if skillLineID then
            local cache = professionCache[skillLineID]
            if not cache or not cache.recipes or not next(cache.recipes) then
                table.insert(autoScanQueue, skillLineID)
            end
        end
    end

    if #autoScanQueue > 0 then
        isAutoScanning = true
        self:SetupProfFrameSuppression()
        self:ProcessAutoScanQueue()
    end
end

--- Hooks ProfessionsFrame's OnShow to suppress it during auto-scan.
-- The frame is loaded on demand (Blizzard_Professions), so we handle
-- both the case where it already exists and where it hasn't loaded yet.
function PP.ProfessionScanner:SetupProfFrameSuppression()
    if self._profFrameHooked then return end

    local function HookFrame()
        if ProfessionsFrame then
            ProfessionsFrame:HookScript("OnShow", function(frame)
                if isAutoScanning then
                    frame:Hide()
                end
            end)
            self._profFrameHooked = true
            return true
        end
        return false
    end

    -- Try immediately (frame might already be loaded)
    if HookFrame() then return end

    -- Watch for the addon to load
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("ADDON_LOADED")
    watcher:SetScript("OnEvent", function(_, _, addon)
        if (addon == "Blizzard_Professions" or addon == "Blizzard_ProfessionsTemplates")
           and HookFrame() then
            watcher:UnregisterEvent("ADDON_LOADED")
        end
    end)
end

--- Processes the next profession in the auto-scan queue.
function PP.ProfessionScanner:ProcessAutoScanQueue()
    if #autoScanQueue == 0 then
        isAutoScanning = false
        -- Close any lingering trade skill UI
        if C_TradeSkillUI and C_TradeSkillUI.CloseTradeSkill then
            C_TradeSkillUI.CloseTradeSkill()
        end
        if ProfessionsFrame and ProfessionsFrame:IsShown() then
            ProfessionsFrame:Hide()
        end
        -- Persist and notify UI
        self:PersistAll()
        return
    end

    local skillLineID = table.remove(autoScanQueue, 1)
    expectedSkillLineID = skillLineID

    -- Open the profession to trigger data loading.
    -- TRADE_SKILL_LIST_UPDATE will fire and our existing handler calls
    -- ScanCurrentProfession(), which caches tiers + recipes.
    if C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill then
        C_TradeSkillUI.OpenTradeSkill(skillLineID)
    end

    -- Immediately suppress the frame if it appeared
    C_Timer.After(0, function()
        if ProfessionsFrame and ProfessionsFrame:IsShown() then
            ProfessionsFrame:Hide()
        end
    end)

    -- Wait for the scan to complete, then close and continue
    C_Timer.After(1.5, function()
        expectedSkillLineID = nil
        if C_TradeSkillUI and C_TradeSkillUI.CloseTradeSkill then
            C_TradeSkillUI.CloseTradeSkill()
        end
        if ProfessionsFrame and ProfessionsFrame:IsShown() then
            ProfessionsFrame:Hide()
        end
        C_Timer.After(0.5, function()
            PP.ProfessionScanner:ProcessAutoScanQueue()
        end)
    end)
end

------------------------------------------------------------------------
-- Detailed scan: runs when the trade skill window is open
------------------------------------------------------------------------

--- Scans the currently open profession window for recipes and updates tiers.
-- Triggered by TRADE_SKILL_LIST_UPDATE event.
function PP.ProfessionScanner:ScanCurrentProfession()
    if not C_TradeSkillUI.IsTradeSkillReady() then return end

    local profInfo = C_TradeSkillUI.GetBaseProfessionInfo()
    if not profInfo or not profInfo.professionID then return end

    local enumID = profInfo.professionID  -- Enum.Profession value (small int)

    -- Resolve to the correct skill-line-based cache key using multiple
    -- strategies, in order of reliability:
    local profID = nil

    -- Strategy 1: During auto-scan we know exactly which skillLineID was opened
    if expectedSkillLineID and professionCache[expectedSkillLineID] then
        profID = expectedSkillLineID
    end

    -- Strategy 2: Use the enum->skillLine mapping from ScanExpansionTiers
    if not profID and enumToSkillLine[enumID] then
        profID = enumToSkillLine[enumID]
    end

    -- Strategy 3: Exact name match against existing cache entries
    if not profID then
        local profName = profInfo.professionName or ""
        if profName ~= "" then
            for existingID, data in pairs(professionCache) do
                if data.name == profName then
                    profID = existingID
                    break
                end
            end
        end
    end

    -- Strategy 4: The enum value itself (unlikely to match a cache key
    -- but keeps the old behaviour as last resort)
    if not profID then
        profID = enumID
    end

    -- Record the mapping for future calls so we never resolve wrong again
    if profID ~= enumID then
        enumToSkillLine[enumID] = profID
    end

    -- Create cache entry if needed
    if not professionCache[profID] then
        professionCache[profID] = {
            name = profInfo.professionName or "Unknown",
            professionID = profID,
            tiers = {},
            recipes = {},
        }
    end

    local cache = professionCache[profID]
    cache.name = profInfo.professionName or cache.name

    -- Re-scan expansion tiers (more accurate while window is open)
    self:ScanExpansionTiers(profID)

    -- Also try reading tiers from the TradeSkill tab info (while window is open)
    self:ScanTiersFromOpenWindow(profID)

    -- Scan all recipes.  Clear the old set first so stale recipes from
    -- a previous (possibly incorrect) scan are removed.
    local recipeIDs = C_TradeSkillUI.GetAllRecipeIDs()
    if recipeIDs and #recipeIDs > 0 then
        cache.recipes = {}
        for _, recipeID in ipairs(recipeIDs) do
            self:CacheRecipe(profID, recipeID)
        end
    end

    -- Persist to character DB
    self:PersistAll()
end

--- Reads expansion tiers from the currently open trade skill window.
-- This is a secondary method that uses C_TradeSkillUI.GetProfessionInfo
-- (the detailed frame variant) to get accurate per-expansion skill levels.
-- @param profID number The base profession ID (skill line ID)
function PP.ProfessionScanner:ScanTiersFromOpenWindow(profID)
    -- Delegate to the same robust implementation used at login.
    -- While the window is open the API should return even more accurate data.
    self:ScanExpansionTiers(profID)
end

------------------------------------------------------------------------
-- Recipe caching
------------------------------------------------------------------------

--- Walks up the recipe category hierarchy to find the expansion tier.
-- Returns the tier ID (skill line ID) if the category chain leads to a
-- known tier, or nil if we can't determine it.
-- @param profID number The profession cache key
-- @param categoryID number The recipe's immediate category
-- @return number|nil tierID
local function FindRecipeTier(profID, categoryID)
    local cache = professionCache[profID]
    if not cache or not cache.tiers or not categoryID then return nil end

    -- C_TradeSkillUI.GetCategoryInfo might not be available
    if not C_TradeSkillUI.GetCategoryInfo then return nil end

    local catID = categoryID
    local visited = {}
    while catID and not visited[catID] do
        visited[catID] = true
        -- Is this category itself a tier?
        if cache.tiers[catID] then return catID end
        -- Walk up
        local ok, catInfo = pcall(C_TradeSkillUI.GetCategoryInfo, catID)
        if ok and catInfo and catInfo.parentCategoryID
           and catInfo.parentCategoryID ~= 0 then
            catID = catInfo.parentCategoryID
        else
            break
        end
    end
    return nil
end

--- Caches detailed data for a single recipe including difficulty and reagents.
-- @param profID number The profession ID
-- @param recipeID number The recipe spell ID
function PP.ProfessionScanner:CacheRecipe(profID, recipeID)
    local recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeID)
    if not recipeInfo or not recipeInfo.learned then return end

    -- Get the schematic for reagent data
    local schematic = C_TradeSkillUI.GetRecipeSchematic(recipeID, false)
    if not schematic then return end

    -- Parse reagents
    local reagents = {}
    if schematic.reagentSlotSchematics then
        for _, slot in ipairs(schematic.reagentSlotSchematics) do
            local parsed = self:ParseReagentSlot(slot)
            if parsed then
                table.insert(reagents, parsed)
            end
        end
    end

    -- Determine difficulty level
    local difficulty = recipeInfo.relativeDifficulty or 3  -- Default to trivial
    local skillUpChance = PP.Utils.GetSkillUpChance(difficulty)

    -- Determine which expansion tier this recipe belongs to
    local tierID = FindRecipeTier(profID, recipeInfo.categoryID)

    -- Build recipe entry
    local recipe = {
        recipeID = recipeID,
        name = recipeInfo.name or schematic.name or "Unknown",
        icon = recipeInfo.icon or schematic.icon,
        categoryID = recipeInfo.categoryID,
        tierID = tierID,
        difficulty = difficulty,
        skillUpChance = skillUpChance,
        numSkillUps = recipeInfo.numSkillUps or 1,
        outputItemID = schematic.outputItemID,
        quantityMin = schematic.quantityMin or 1,
        quantityMax = schematic.quantityMax or 1,
        reagents = reagents,
        disabled = recipeInfo.disabled or false,
        supportsQualities = recipeInfo.supportsQualities or false,
        qualityItemIDs = recipeInfo.qualityItemIDs,
    }

    -- Store in the profession cache
    local cache = professionCache[profID]
    if cache then
        cache.recipes[recipeID] = recipe
    end
end

--- Parses a reagent slot into a simplified structure.
-- @param slot table CraftingReagentSlotSchematic from the API
-- @return table|nil {itemID, quantity, isOptional, alternatives}
function PP.ProfessionScanner:ParseReagentSlot(slot)
    if not slot or not slot.reagents or #slot.reagents == 0 then return nil end

    local isOptional = (slot.reagentType == Enum.CraftingReagentType.Optional)
        or (slot.reagentType == Enum.CraftingReagentType.Finishing)

    local alternatives = {}
    local primaryItemID = nil
    for _, reagent in ipairs(slot.reagents) do
        if reagent.itemID then
            table.insert(alternatives, reagent.itemID)
            if not primaryItemID then primaryItemID = reagent.itemID end
        end
    end

    if not primaryItemID then return nil end

    return {
        itemID = primaryItemID,
        quantity = slot.quantityRequired or 1,
        isOptional = isOptional,
        alternatives = alternatives,
    }
end

------------------------------------------------------------------------
-- Persistence
------------------------------------------------------------------------

--- Persists the entire profession cache to character SavedVariables.
function PP.ProfessionScanner:PersistAll()
    if not PP.charDb then return end
    PP.charDb.professions = {}
    for profID, data in pairs(professionCache) do
        PP.charDb.professions[profID] = data
    end
end

------------------------------------------------------------------------
-- Public query API
------------------------------------------------------------------------

--- Returns all cached profession data.
-- @return table The full profession cache
function PP.ProfessionScanner:GetAllProfessions()
    return professionCache
end

--- Returns data for a specific profession.
-- @param profID number The profession ID
-- @return table|nil Profession data
function PP.ProfessionScanner:GetProfession(profID)
    return professionCache[profID]
end

--- Returns a recipe by ID from any cached profession.
-- @param recipeID number The recipe spell ID
-- @return table|nil Recipe data
function PP.ProfessionScanner:GetRecipe(recipeID)
    for _, prof in pairs(professionCache) do
        if prof.recipes and prof.recipes[recipeID] then
            return prof.recipes[recipeID]
        end
    end
    return nil
end

--- Returns all recipes that can give skill-ups at the given skill level.
-- Excludes trivial (gray) recipes.  When a categoryID (expansion tier) is
-- given, only recipes belonging to that tier are returned.
-- @param profID number The profession ID
-- @param categoryID number|nil Expansion tier ID to filter by
-- @return table Array of recipe data tables sorted by difficulty (orange first)
function PP.ProfessionScanner:GetSkillableRecipes(profID, categoryID)
    local cache = professionCache[profID]
    if not cache then return {} end

    local results = {}

    for recipeID, recipe in pairs(cache.recipes) do
        if not recipe.disabled and recipe.skillUpChance > 0 then
            -- If a tier filter is requested and the recipe has a known tier,
            -- only include recipes from that specific expansion tier.
            local matchesTier = true
            if categoryID and recipe.tierID then
                matchesTier = (recipe.tierID == categoryID)
            end

            if matchesTier then
                table.insert(results, recipe)
            end
        end
    end

    -- Sort by difficulty: orange (0) first, then yellow (1), then green (2)
    table.sort(results, function(a, b)
        return a.difficulty < b.difficulty
    end)

    return results
end

--- Finds the cheapest reagent alternative for a slot based on prices.
-- @param alternatives table Array of item IDs
-- @return number|nil cheapestID
-- @return number|nil price in copper
function PP.ProfessionScanner:FindCheapestAlternative(alternatives)
    if not alternatives or #alternatives == 0 then return nil, nil end

    local cheapestID, cheapestPrice = nil, nil
    for _, itemID in ipairs(alternatives) do
        local price = PP.PriceSource:GetPrice(itemID)
        if price and (not cheapestPrice or price < cheapestPrice) then
            cheapestPrice = price
            cheapestID = itemID
        end
    end
    return cheapestID, cheapestPrice
end

------------------------------------------------------------------------
-- Diagnostics (for /pp debug)
------------------------------------------------------------------------

--- Prints detailed API diagnostic information to help debug tier detection.
function PP.ProfessionScanner:PrintDebugInfo()
    local P = PP.Utils.Print

    P("--- MigothsProfessionPilot Debug ---")

    -- Character professions
    local prof1, prof2, _, fishing, cooking = GetProfessions()
    P("GetProfessions: " .. tostring(prof1) .. ", " .. tostring(prof2)
        .. ", fish=" .. tostring(fishing) .. ", cook=" .. tostring(cooking))

    local profIndices = {}
    if prof1 then profIndices[#profIndices + 1] = prof1 end
    if prof2 then profIndices[#profIndices + 1] = prof2 end
    if cooking then profIndices[#profIndices + 1] = cooking end

    for _, idx in ipairs(profIndices) do
        local name, icon, skillLevel, maxSkillLevel, numAbilities,
              spellOffset, skillLineID = GetProfessionInfo(idx)
        P("  Prof[" .. idx .. "]: name=" .. tostring(name)
            .. " skillLineID=" .. tostring(skillLineID)
            .. " skill=" .. tostring(skillLevel) .. "/" .. tostring(maxSkillLevel))
    end

    -- All trade skill lines
    if C_TradeSkillUI.GetAllProfTradeSkillLines then
        local allLines = C_TradeSkillUI.GetAllProfTradeSkillLines()
        if allLines then
            P("GetAllProfTradeSkillLines: " .. #allLines .. " lines")
            for _, lineID in ipairs(allLines) do
                if C_TradeSkillUI.GetProfessionInfoBySkillLineID then
                    local ok, info = pcall(
                        C_TradeSkillUI.GetProfessionInfoBySkillLineID, lineID)
                    if ok and info then
                        P("  Line " .. lineID
                            .. ": parent=" .. tostring(info.parentProfessionID)
                            .. " profID=" .. tostring(info.professionID)
                            .. " name=" .. tostring(info.professionName)
                            .. " exp=" .. tostring(info.expansionName)
                            .. " skill=" .. tostring(info.skillLevel)
                            .. "/" .. tostring(info.maxSkillLevel))
                    else
                        P("  Line " .. lineID .. ": (no info)")
                    end
                end
            end
        else
            P("GetAllProfTradeSkillLines: returned nil")
        end
    else
        P("GetAllProfTradeSkillLines: API not available")
    end

    -- Cached tiers
    P("Cached professions:")
    for profID, data in pairs(professionCache) do
        local tierCount = 0
        for _ in pairs(data.tiers or {}) do tierCount = tierCount + 1 end
        local recipeCount = 0
        for _ in pairs(data.recipes or {}) do recipeCount = recipeCount + 1 end
        P("  [" .. profID .. "] " .. tostring(data.name)
            .. ": " .. tierCount .. " tiers, " .. recipeCount .. " recipes")
        for tierID, tier in pairs(data.tiers or {}) do
            -- Count recipes that belong to this tier
            local tierRecipes = 0
            local untagged = 0
            for _, recipe in pairs(data.recipes or {}) do
                if recipe.tierID == tierID then
                    tierRecipes = tierRecipes + 1
                elseif not recipe.tierID then
                    untagged = untagged + 1
                end
            end
            P("    Tier[" .. tierID .. "]: " .. tostring(tier.name)
                .. " skill=" .. tostring(tier.skillLevel)
                .. "/" .. tostring(tier.maxSkill)
                .. " recipes=" .. tierRecipes
                .. " untagged=" .. untagged)
        end
    end

    P("--- End Debug ---")
end
