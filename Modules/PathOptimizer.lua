-- PathOptimizer.lua
-- Calculates the cheapest leveling path for a profession tier.
--
-- Simulates skill progression point by point.  As skill increases,
-- recipe difficulty degrades (orange -> yellow -> green -> gray),
-- reducing the skill-up chance.  At each level the optimizer picks
-- the cheapest recipe per expected skill point and switches when a
-- better option appears at a difficulty transition.

local ADDON_NAME, PP = ...

PP.PathOptimizer = {}

--- Initializes the path optimizer.
function PP.PathOptimizer:Init()
    -- Nothing to initialize; calculations are on-demand
end

------------------------------------------------------------------------
-- Core: point-by-point simulation
------------------------------------------------------------------------

--- Calculates the optimal leveling path for a profession tier.
-- Simulates gaining one skill point at a time, picking the cheapest
-- recipe at each level and switching at difficulty transitions.
-- @param profID number The profession ID
-- @param categoryID number|nil The expansion tier category ID
-- @param currentSkill number Current skill level
-- @param maxSkill number Target skill level
-- @return table Array of path steps
-- @return number totalCost Total net cost of the full path
function PP.PathOptimizer:CalculatePath(profID, categoryID, currentSkill, maxSkill)
    local allRecipes = PP.ProfessionScanner:GetSkillableRecipes(profID, categoryID)
    if #allRecipes == 0 then return {}, 0 end

    -- Pre-compute material cost for one craft of each usable recipe.
    -- Uses AH prices (via FindCheapestAlternative) so the cost reflects
    -- what the player would actually pay, independent of current inventory.
    local recipes = {}  -- array of {data, materialCost}
    for _, recipe in ipairs(allRecipes) do
        if not recipe.disabled and recipe.skillUpChance > 0 then
            local cost = self:ComputeMaterialCost(recipe.reagents)
            if cost and cost > 0 then
                recipes[#recipes + 1] = {
                    data = recipe,
                    materialCost = cost,
                }
            end
        end
    end
    if #recipes == 0 then return {}, 0 end

    -- Difficulty degradation rate: how many skill points before a recipe
    -- drops one difficulty level (orange->yellow, yellow->green, etc.).
    -- Scales with the tier's max skill so Classic (300) degrades slower
    -- than modern tiers (75-100).
    local diffRange = math.max(4, math.floor(maxSkill / 12))
    local scanSkill = currentSkill

    local path = {}
    local totalCost = 0
    local sim = currentSkill

    while sim < maxSkill do
        -- Find the cheapest recipe per expected skill point at this level
        local bestEntry = self:FindBestRecipe(
            recipes, sim, scanSkill, diffRange)
        if not bestEntry then break end  -- no usable recipes left

        -- Use this recipe, accumulating crafts into a single step
        local stepStart = sim
        local stepCrafts = 0
        local stepCost = 0
        local startDiff = self:EstimateDifficulty(
            bestEntry.data.difficulty, sim, scanSkill, diffRange)

        while sim < maxSkill do
            local diff = self:EstimateDifficulty(
                bestEntry.data.difficulty, sim, scanSkill, diffRange)
            if diff >= 3 then break end  -- recipe went gray

            local chance = PP.Utils.GetSkillUpChance(diff)
            if chance <= 0 then break end

            -- Each successful craft gives numSkillUps points
            local ups = math.min(
                bestEntry.data.numSkillUps or 1, maxSkill - sim)
            local crafts = self:CraftsForOnePoint(chance)

            stepCrafts = stepCrafts + crafts
            stepCost = stepCost + bestEntry.materialCost * crafts
            sim = sim + ups

            -- At difficulty transitions, check if a better recipe exists
            if sim < maxSkill then
                local newDiff = self:EstimateDifficulty(
                    bestEntry.data.difficulty, sim, scanSkill, diffRange)
                if newDiff ~= diff then
                    local newBest = self:FindBestRecipe(
                        recipes, sim, scanSkill, diffRange)
                    if newBest
                       and newBest.data.recipeID ~= bestEntry.data.recipeID
                    then
                        break  -- switch to better recipe
                    end
                end
            end
        end

        if stepCrafts > 0 then
            local pointsGained = sim - stepStart
            -- End difficulty: what the recipe is at when we stop using it
            local endDiff = self:EstimateDifficulty(
                bestEntry.data.difficulty, sim - 1, scanSkill, diffRange)
            table.insert(path, {
                recipeID      = bestEntry.data.recipeID,
                name          = bestEntry.data.name,
                icon          = bestEntry.data.icon,
                craftCount    = stepCrafts,
                materialCost  = stepCost,
                sellback      = 0,
                netCost       = stepCost,
                costPerPoint  = pointsGained > 0
                    and (stepCost / pointsGained) or 0,
                skillFrom     = stepStart,
                skillTo       = sim,
                difficulty    = startDiff,
                endDifficulty = endDiff,
                skillUpChance = PP.Utils.GetSkillUpChance(startDiff),
                reagents      = bestEntry.data.reagents,
                outputItemID  = bestEntry.data.outputItemID,
            })
            totalCost = totalCost + stepCost
        else
            break  -- no progress possible
        end
    end

    return path, totalCost
end

------------------------------------------------------------------------
-- Difficulty estimation
------------------------------------------------------------------------

--- Estimates a recipe's difficulty at a simulated skill level.
-- Recipes degrade from their scanned difficulty as skill increases.
-- Every `diffRange` skill points gained, the difficulty drops one
-- level (e.g. orange -> yellow).
-- @param scannedDiff number Difficulty at scan time (0-3)
-- @param atSkill number Simulated skill level
-- @param scanSkill number Skill level when recipes were scanned
-- @param diffRange number Skill points per difficulty step
-- @return number Estimated difficulty (0-3)
function PP.PathOptimizer:EstimateDifficulty(scannedDiff, atSkill, scanSkill, diffRange)
    local gained = math.max(0, atSkill - scanSkill)
    local degradation = math.floor(gained / diffRange)
    return math.min(3, scannedDiff + degradation)
end

------------------------------------------------------------------------
-- Recipe evaluation
------------------------------------------------------------------------

--- Finds the cheapest recipe at a given simulated skill level.
-- Cost is measured as material cost per expected skill point,
-- accounting for the estimated difficulty (and thus skill-up chance).
-- @param recipes table Array of {data, materialCost}
-- @param atSkill number Simulated skill level
-- @param scanSkill number Skill level when recipes were scanned
-- @param diffRange number Skill points per difficulty step
-- @return table|nil Best recipe entry {data, materialCost}
function PP.PathOptimizer:FindBestRecipe(recipes, atSkill, scanSkill, diffRange)
    local bestEntry = nil
    local bestCPP = math.huge  -- cost per point

    for _, entry in ipairs(recipes) do
        local diff = self:EstimateDifficulty(
            entry.data.difficulty, atSkill, scanSkill, diffRange)
        if diff < 3 then
            local chance = PP.Utils.GetSkillUpChance(diff)
            if chance > 0 then
                local ups = entry.data.numSkillUps or 1
                local cpp = entry.materialCost / (chance * ups)
                if cpp < bestCPP then
                    bestCPP = cpp
                    bestEntry = entry
                end
            end
        end
    end

    return bestEntry
end

--- Computes the pure material cost of one craft from AH prices.
-- Does NOT subtract inventory (the simulation needs the real market cost).
-- @param reagents table Array of {itemID, quantity, isOptional, alternatives}
-- @return number Total material cost in copper
function PP.PathOptimizer:ComputeMaterialCost(reagents)
    local total = 0
    for _, reagent in ipairs(reagents) do
        if not reagent.isOptional then
            -- Use cheapest alternative if available
            local _, price = PP.ProfessionScanner:FindCheapestAlternative(
                reagent.alternatives)
            if not price then
                price = PP.PriceSource:GetPrice(reagent.itemID)
            end
            total = total + (price or 0) * reagent.quantity
        end
    end
    return total
end

--- Returns the expected number of crafts needed for one guaranteed skill point.
-- @param chance number Probability of skill-up per craft (0.0-1.0)
-- @return number Expected crafts for one point
function PP.PathOptimizer:CraftsForOnePoint(chance)
    if chance <= 0 then return math.huge end
    if chance >= 1 then return 1 end
    -- Expected value: 1/p crafts for one success
    return math.ceil(1 / chance)
end

--- Generates a consolidated shopping list from a leveling path.
-- Aggregates all materials needed across all steps.
-- @param path table Array of path steps from CalculatePath
-- @return table Array of {itemID, name, totalNeeded, owned, toBuy, unitPrice, totalCost}
-- @return number totalCost Total cost of all materials to buy
function PP.PathOptimizer:GenerateShoppingList(path)
    if not path or #path == 0 then return {}, 0 end

    -- Aggregate material needs across all steps
    local materialNeeds = {}  -- itemID -> total quantity needed

    for _, step in ipairs(path) do
        if step.reagents then
            for _, reagent in ipairs(step.reagents) do
                if not reagent.isOptional then
                    local itemID = reagent.itemID
                    -- Use cheapest alternative
                    local cheapestID = PP.ProfessionScanner:FindCheapestAlternative(reagent.alternatives)
                    if cheapestID then itemID = cheapestID end

                    local needed = reagent.quantity * step.craftCount
                    materialNeeds[itemID] = (materialNeeds[itemID] or 0) + needed
                end
            end
        end
    end

    -- Build shopping list with inventory awareness
    local shoppingList = {}
    local totalCost = 0

    for itemID, totalNeeded in pairs(materialNeeds) do
        local owned = PP.InventoryScanner:GetItemCount(itemID)
        local toBuy = math.max(0, totalNeeded - owned)
        local unitPrice = PP.PriceSource:GetPrice(itemID)
        local cost = unitPrice and (toBuy * unitPrice) or nil
        local name = PP.Utils.GetItemName(itemID) or ("Item:" .. itemID)

        table.insert(shoppingList, {
            itemID = itemID,
            name = name,
            totalNeeded = totalNeeded,
            owned = math.min(owned, totalNeeded),
            toBuy = toBuy,
            unitPrice = unitPrice,
            totalCost = cost,
        })

        if cost then totalCost = totalCost + cost end
    end

    -- Sort by total cost descending
    table.sort(shoppingList, function(a, b)
        return (a.totalCost or 0) > (b.totalCost or 0)
    end)

    return shoppingList, totalCost
end
