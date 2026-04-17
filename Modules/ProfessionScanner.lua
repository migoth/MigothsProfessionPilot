-- ProfessionScanner.lua
-- Scans all character professions and their expansion-specific skill tiers.
-- Reads known recipes, skill levels, difficulty, and specialization data.

local ADDON_NAME, PP = ...

PP.ProfessionScanner = {}

-- Cache of scanned profession data
-- Structure: { professionID -> { expansions -> { skillLevel, maxSkill, recipes[] } } }
local professionCache = {}

--- Initializes the profession scanner.
function PP.ProfessionScanner:Init()
    professionCache = {}
end

--- Scans the currently open profession window for skill levels and recipes.
-- Triggered by TRADE_SKILL_LIST_UPDATE event.
function PP.ProfessionScanner:ScanCurrentProfession()
    if not C_TradeSkillUI.IsTradeSkillReady() then return end

    local profInfo = C_TradeSkillUI.GetBaseProfessionInfo()
    if not profInfo or not profInfo.professionID then return end

    local profID = profInfo.professionID

    -- Get all tab/tier info (each expansion is a separate skill tier)
    local tabInfo = C_TradeSkillUI.GetTradeSkillLineInfoByID
        and self:ScanSkillTiers(profID)
        or self:ScanFallback(profID)

    -- Scan all recipes for this profession
    local recipeIDs = C_TradeSkillUI.GetAllRecipeIDs()
    if recipeIDs then
        for _, recipeID in ipairs(recipeIDs) do
            self:CacheRecipe(profID, recipeID)
        end
    end

    -- Persist to character DB
    PP.charDb.professions[profID] = professionCache[profID]
end

--- Scans skill tiers (expansion-specific skill levels) for a profession.
-- Uses C_TradeSkillUI profession info to get each tier's current/max skill.
-- @param profID number The base profession ID
-- @return table Tier data
function PP.ProfessionScanner:ScanSkillTiers(profID)
    if not professionCache[profID] then
        professionCache[profID] = {
            name = PP.PROFESSION_NAMES[profID] and PP.L[PP.PROFESSION_NAMES[profID]] or "Unknown",
            professionID = profID,
            tiers = {},
            recipes = {},
        }
    end

    local cache = professionCache[profID]

    -- Get the profession info which includes child skill lines (tiers)
    local profInfo = C_TradeSkillUI.GetBaseProfessionInfo()
    if profInfo then
        cache.name = profInfo.professionName or cache.name
    end

    -- Scan each child profession (tier = expansion)
    local childProfessions = C_TradeSkillUI.GetChildProfessionInfos
        and C_TradeSkillUI.GetChildProfessionInfos()
        or {}

    -- Also try getting profession info directly for skill levels
    local categories = { C_TradeSkillUI.GetCategories() }
    for _, categoryID in ipairs(categories) do
        local catInfo = C_TradeSkillUI.GetCategoryInfo(categoryID)
        if catInfo then
            -- Categories often map to expansion tiers
            local tierData = {
                categoryID = categoryID,
                name = catInfo.name or "Unknown",
                skillLevel = catInfo.skillLineCurrentLevel or 0,
                maxSkill = catInfo.skillLineMaxLevel or 0,
                recipes = {},
            }

            -- Only include tiers that have a skill cap (expansion skill tiers)
            if tierData.maxSkill > 0 then
                cache.tiers[categoryID] = tierData
            end
        end
    end

    return cache.tiers
end

--- Fallback scanning method when detailed tier API isn't available.
-- Reads the basic profession info for overall skill level.
-- @param profID number The base profession ID
-- @return table Basic profession data
function PP.ProfessionScanner:ScanFallback(profID)
    if not professionCache[profID] then
        professionCache[profID] = {
            name = PP.PROFESSION_NAMES[profID] and PP.L[PP.PROFESSION_NAMES[profID]] or "Unknown",
            professionID = profID,
            tiers = {},
            recipes = {},
        }
    end

    local profInfo = C_TradeSkillUI.GetBaseProfessionInfo()
    if profInfo then
        professionCache[profID].name = profInfo.professionName or professionCache[profID].name
        professionCache[profID].currentSkill = profInfo.skillLevel or 0
        professionCache[profID].maxSkill = profInfo.maxSkillLevel or 0
    end

    return professionCache[profID].tiers
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
