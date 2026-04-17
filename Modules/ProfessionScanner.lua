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
-- Uses C_TradeSkillUI APIs that work outside the trade skill frame.
--
-- IMPORTANT: profID is a skill line ID (e.g. 171 for Alchemy) from
-- GetProfessionInfo(). However, ProfessionInfo.parentProfessionID
-- returned by GetProfessionInfoBySkillLineID() uses Enum.Profession
-- values (e.g. 3 for Alchemy). We resolve the enum value first so
-- the comparison works.
-- @param profID number The base profession skill line ID
function PP.ProfessionScanner:ScanExpansionTiers(profID)
    local cache = professionCache[profID]
    if not cache then return end

    -- Resolve the Enum.Profession value for this skill line.
    local enumID = nil
    if C_TradeSkillUI.GetProfessionInfoBySkillLineID then
        local baseInfo = C_TradeSkillUI.GetProfessionInfoBySkillLineID(profID)
        if baseInfo then
            enumID = baseInfo.professionID or baseInfo.parentProfessionID
            -- Store the mapping so ScanCurrentProfession can find the cache key
            if enumID and enumID ~= profID then
                enumToSkillLine[enumID] = profID
            end
        end
    end

    -- Helper: does this child belong to our profession?
    -- Checks three things in order:
    --   1) parentProfessionID matches the skill line ID directly
    --   2) parentProfessionID matches the resolved Enum.Profession value
    --   3) professionName matches our cached profession name (fallback)
    local profName = cache.name
    local function IsMatch(info)
        if not info then return false end
        if info.parentProfessionID then
            if info.parentProfessionID == profID then return true end
            if enumID and info.parentProfessionID == enumID then return true end
        end
        -- Name-based fallback: compare base profession name
        if profName and info.professionName and info.professionName == profName then
            return true
        end
        return false
    end

    -- Method 1: GetAllProfTradeSkillLines + GetProfessionInfoBySkillLineID
    if C_TradeSkillUI.GetAllProfTradeSkillLines then
        local allLines = C_TradeSkillUI.GetAllProfTradeSkillLines()
        if allLines then
            for _, childLineID in ipairs(allLines) do
                if childLineID ~= profID
                   and C_TradeSkillUI.GetProfessionInfoBySkillLineID
                then
                    local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(childLineID)
                    if IsMatch(info) then
                        -- Store reverse mapping for any newly discovered enum
                        if info.parentProfessionID
                           and info.parentProfessionID ~= profID
                        then
                            enumToSkillLine[info.parentProfessionID] = profID
                            enumID = info.parentProfessionID
                        end
                        cache.tiers[childLineID] = {
                            categoryID = childLineID,
                            name = info.professionName or info.expansionName or "Unknown",
                            skillLevel = info.skillLevel or 0,
                            maxSkill = info.maxSkillLevel or 0,
                            recipes = cache.tiers[childLineID]
                                and cache.tiers[childLineID].recipes or {},
                        }
                    end
                end
            end
        end
    end

    -- Method 2: GetChildProfessionInfos (alternative/newer API)
    if not next(cache.tiers) and C_TradeSkillUI.GetChildProfessionInfos then
        local children = C_TradeSkillUI.GetChildProfessionInfos()
        if children then
            for _, childInfo in ipairs(children) do
                if IsMatch(childInfo) then
                    local id = childInfo.professionID or childInfo.skillLineID
                    if id then
                        cache.tiers[id] = {
                            categoryID = id,
                            name = childInfo.professionName
                                or childInfo.expansionName or "Unknown",
                            skillLevel = childInfo.skillLevel or 0,
                            maxSkill = childInfo.maxSkillLevel or 0,
                            recipes = cache.tiers[id]
                                and cache.tiers[id].recipes or {},
                        }
                    end
                end
            end
        end
    end

    -- If real expansion tiers were found, remove the fallback single-tier
    -- entry (which has key == profID) so it doesn't show alongside the
    -- real tiers in the UI.
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

    local profID = profInfo.professionID

    -- GetBaseProfessionInfo().professionID might be an Enum.Profession value
    -- instead of a skill line ID. If we have a mapping from a previous scan,
    -- use the skill line ID as cache key for consistency.
    if enumToSkillLine[profID] then
        profID = enumToSkillLine[profID]
    end

    -- If profID still doesn't match an existing cache entry, try to
    -- find the right one by profession name.
    if not professionCache[profID] then
        for existingID, data in pairs(professionCache) do
            if data.name == (profInfo.professionName or "") then
                profID = existingID
                break
            end
        end
    end

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

    -- Scan all recipes
    local recipeIDs = C_TradeSkillUI.GetAllRecipeIDs()
    if recipeIDs then
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
    local cache = professionCache[profID]
    if not cache then return end

    -- Resolve enum ID for matching (same as ScanExpansionTiers)
    local enumID = nil
    if C_TradeSkillUI.GetProfessionInfoBySkillLineID then
        local baseInfo = C_TradeSkillUI.GetProfessionInfoBySkillLineID(profID)
        if baseInfo then
            enumID = baseInfo.professionID or baseInfo.parentProfessionID
        end
    end

    local profName = cache.name
    local function IsMatch(info)
        if not info then return false end
        if info.parentProfessionID then
            if info.parentProfessionID == profID then return true end
            if enumID and info.parentProfessionID == enumID then return true end
        end
        if profName and info.professionName and info.professionName == profName then
            return true
        end
        return false
    end

    if C_TradeSkillUI.GetAllProfTradeSkillLines then
        local allLines = C_TradeSkillUI.GetAllProfTradeSkillLines()
        if allLines then
            for _, lineID in ipairs(allLines) do
                if lineID ~= profID
                   and C_TradeSkillUI.GetProfessionInfoBySkillLineID
                then
                    local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(lineID)
                    if IsMatch(info) then
                        if info.parentProfessionID
                           and info.parentProfessionID ~= profID
                        then
                            enumToSkillLine[info.parentProfessionID] = profID
                        end
                        local existing = cache.tiers[lineID]
                        cache.tiers[lineID] = {
                            categoryID = lineID,
                            name = info.professionName or info.expansionName
                                or (existing and existing.name) or "Unknown",
                            skillLevel = info.skillLevel or 0,
                            maxSkill = info.maxSkillLevel or 0,
                            recipes = existing and existing.recipes or {},
                        }
                    end
                end
            end
        end
    end

    -- Clean up fallback tier if real tiers now exist
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
-- Recipe caching
------------------------------------------------------------------------

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

    -- Build recipe entry
    local recipe = {
        recipeID = recipeID,
        name = recipeInfo.name or schematic.name or "Unknown",
        icon = recipeInfo.icon or schematic.icon,
        categoryID = recipeInfo.categoryID,
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

        -- Also assign to the matching tier/category
        if recipe.categoryID and cache.tiers[recipe.categoryID] then
            cache.tiers[recipe.categoryID].recipes[recipeID] = recipe
        end
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
-- Excludes trivial (gray) recipes.
-- @param profID number The profession ID
-- @param categoryID number|nil Optional tier/category filter (unused - recipes
--   always come from the global cache because recipe categoryIDs are
--   sub-categories, not expansion skill line IDs)
-- @return table Array of recipe data tables sorted by difficulty (orange first)
function PP.ProfessionScanner:GetSkillableRecipes(profID, categoryID)
    local cache = professionCache[profID]
    if not cache then return {} end

    local results = {}

    -- Always iterate the global recipe cache.  Tier-specific recipe
    -- lists are unreliable because recipe.categoryID (a sub-category
    -- like "Armor") does not match the tier's key (an expansion skill
    -- line ID).  Recipes that are trivial for the selected tier already
    -- have skillUpChance == 0 and are filtered out below.
    for recipeID, recipe in pairs(cache.recipes) do
        if not recipe.disabled and recipe.skillUpChance > 0 then
            table.insert(results, recipe)
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
