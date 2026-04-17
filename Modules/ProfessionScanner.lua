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

------------------------------------------------------------------------
-- Proactive scan: detect professions and expansion tiers at login
------------------------------------------------------------------------

--- Scans all known professions using APIs that work without the
-- trade skill window being open.
function PP.ProfessionScanner:ScanAllProfessions()
    -- GetProfessions() returns: prof1, prof2, archaeology, fishing, cooking
    local prof1, prof2, _, _, cooking = GetProfessions()

    -- Scan primary crafting professions + cooking
    for _, profIndex in ipairs({prof1, prof2, cooking}) do
        if profIndex then
            self:ScanProfessionByIndex(profIndex)
        end
    end

    -- Persist to SavedVariables
    self:PersistAll()
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
-- @param profID number The base profession skill line ID
function PP.ProfessionScanner:ScanExpansionTiers(profID)
    local cache = professionCache[profID]
    if not cache then return end

    -- Method 1: GetAllProfTradeSkillLines + GetProfessionInfoBySkillLineID
    -- These APIs were added in 10.0+ and can return per-expansion skill data.
    if C_TradeSkillUI.GetAllProfTradeSkillLines then
        local allLines = C_TradeSkillUI.GetAllProfTradeSkillLines()
        if allLines then
            for _, childLineID in ipairs(allLines) do
                if C_TradeSkillUI.GetProfessionInfoBySkillLineID then
                    local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(childLineID)
                    if info and info.parentProfessionID == profID then
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
                if childInfo.parentProfessionID == profID then
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
-- @param profID number The base profession ID
function PP.ProfessionScanner:ScanTiersFromOpenWindow(profID)
    local cache = professionCache[profID]
    if not cache then return end

    -- C_TradeSkillUI.GetTradeSkillLineForRecipe or tab-level info
    -- When the window is open, the profession info is available
    -- through multiple channels. Try the child skill lines API again
    -- as it may return richer data with the window open.
    if C_TradeSkillUI.GetAllProfTradeSkillLines then
        local allLines = C_TradeSkillUI.GetAllProfTradeSkillLines()
        if allLines then
            for _, lineID in ipairs(allLines) do
                if C_TradeSkillUI.GetProfessionInfoBySkillLineID then
                    local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(lineID)
                    if info and info.parentProfessionID == profID then
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
-- @param categoryID number|nil Optional tier/category filter
-- @return table Array of recipe data tables sorted by difficulty (orange first)
function PP.ProfessionScanner:GetSkillableRecipes(profID, categoryID)
    local cache = professionCache[profID]
    if not cache then return {} end

    local results = {}
    local recipeSource = cache.recipes

    -- If filtering by category, use the tier's recipe list
    if categoryID and cache.tiers[categoryID] then
        recipeSource = cache.tiers[categoryID].recipes
    end

    for recipeID, recipe in pairs(recipeSource) do
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
