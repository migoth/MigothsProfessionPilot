-- PathOptimizer.lua
-- Calculates the cheapest leveling path for a profession tier.
-- Uses a greedy algorithm: at each skill level, pick the recipe with
-- the lowest effective cost per guaranteed skill point.

local ADDON_NAME, PP = ...

PP.PathOptimizer = {}

--- Initializes the path optimizer.
function PP.PathOptimizer:Init()
    -- Nothing to initialize; calculations are on-demand
end

--- Calculates the optimal leveling path for a profession tier.
-- Steps from currentSkill to maxSkill, always choosing the cheapest option.
-- @param profID number The profession ID
-- @param categoryID number|nil The expansion tier category ID (nil = all recipes)
-- @param currentSkill number Current skill level
-- @param maxSkill number Target skill level
-- @return table Array of path steps: {recipeID, name, craftCount, cost, sellback, netCost, costPerPoint, skillRange, difficulty}
-- @return number totalCost Total net cost of the full path
function PP.PathOptimizer:CalculatePath(profID, categoryID, currentSkill, maxSkill)
    local skillableRecipes = PP.ProfessionScanner:GetSkillableRecipes(profID, categoryID)
    if #skillableRecipes == 0 then return {}, 0 end

    local path = {}
    local totalCost = 0
    local simulatedSkill = currentSkill
    local includeSellback = PP.Database:GetSettings().includeSellback

    -- Greedy optimization: at each skill level, choose the cheapest recipe
    local maxIterations = maxSkill * 3  -- Safety limit against infinite loops
    local iterations = 0

    while simulatedSkill < maxSkill and iterations < maxIterations do
        iterations = iterations + 1

        -- Find the best recipe at this skill level
        local bestRecipe, bestScore = nil, math.huge
        local bestCost, bestSellback, bestChance = 0, 0, 0

        for _, recipe in ipairs(skillableRecipes) do
            if not recipe.disabled and recipe.skillUpChance > 0 then
                local score, materialCost, sellback = self:ScoreRecipe(recipe, simulatedSkill, maxSkill)
                if score and score < bestScore then
                    bestScore = score
                    bestRecipe = recipe
                    bestCost = materialCost
                    bestSellback = sellback
                    bestChance = recipe.skillUpChance
                end
            end
        end

        -- No recipe found that gives skill-ups; stop
        if not bestRecipe then break end

        -- Calculate how many crafts are needed for this recipe
        -- before it becomes trivial or we reach the next breakpoint
        local craftsForOnePoint = self:CraftsForOnePoint(bestRecipe.skillUpChance)
        local pointsFromRecipe = bestRecipe.numSkillUps or 1
        local remainingPoints = maxSkill - simulatedSkill

        -- Craft enough to get skill-ups, but re-evaluate recipe choice regularly
        -- We batch up to 5 skill points per step to avoid excessive path entries
        local targetPoints = math.min(remainingPoints, 5)
        local craftsNeeded = math.ceil(targetPoints / pointsFromRecipe) * craftsForOnePoint

        -- Calculate costs for this batch
        local batchMaterialCost = bestCost * craftsNeeded
        local batchSellback = includeSellback and (bestSellback * craftsNeeded) or 0
        local batchNetCost = batchMaterialCost - batchSellback
        local skillGain = math.min(targetPoints, remainingPoints)
        local costPerPoint = skillGain > 0 and (batchNetCost / skillGain) or 0

        -- Add step to the path
        table.insert(path, {
            recipeID = bestRecipe.recipeID,
            name = bestRecipe.name,
            icon = bestRecipe.icon,
            craftCount = craftsNeeded,
            materialCost = batchMaterialCost,
            sellback = batchSellback,
            netCost = batchNetCost,
            costPerPoint = costPerPoint,
            skillFrom = simulatedSkill,
            skillTo = simulatedSkill + skillGain,
            difficulty = bestRecipe.difficulty,
            skillUpChance = bestChance,
            reagents = bestRecipe.reagents,
            outputItemID = bestRecipe.outputItemID,
        })

        totalCost = totalCost + batchNetCost
        simulatedSkill = simulatedSkill + skillGain

        -- Re-evaluate available recipes at the new skill level
        -- (some recipes may have changed difficulty)
        -- In a real scenario, difficulty changes as skill increases,
        -- but we can't simulate that without knowing the exact thresholds.
        -- The greedy approach re-evaluates each iteration.
    end

    return path, totalCost
end

--- Scores a recipe for the optimizer.
-- Lower score = better choice. Score = effective cost per expected skill point.
-- @param recipe table Recipe data from ProfessionScanner
-- @param currentSkill number Current skill level
-- @param maxSkill number Target skill level
-- @return number|nil score Cost per skill point (nil if recipe has no price data)
-- @return number materialCost Total material cost for one craft
-- @return number sellback Estimated sellback value for one craft
function PP.PathOptimizer:ScoreRecipe(recipe, currentSkill, maxSkill)
    -- Calculate material cost
    local materialCost, _ = PP.InventoryScanner:CalculateNetCost(recipe.reagents, 1)

    -- Calculate sellback value of crafted item
    local sellback = 0
    local includeSellback = PP.Database:GetSettings().includeSellback
    if includeSellback and recipe.outputItemID then
        local sellValue = PP.PriceSource:GetSellbackValue(recipe.outputItemID)
        if sellValue then
            local avgQuantity = (recipe.quantityMin + recipe.quantityMax) / 2
            sellback = sellValue * avgQuantity
        end
    end

    -- Effective cost = material cost minus what we get back
    local effectiveCost = materialCost - sellback

    -- Expected skill points per craft
    local expectedSkillUps = recipe.skillUpChance * (recipe.numSkillUps or 1)
    if expectedSkillUps <= 0 then return nil, materialCost, sellback end

    -- Cost per skill point
    local costPerPoint = effectiveCost / expectedSkillUps

    return costPerPoint, materialCost, sellback
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
