-- Utils.lua
-- Utility functions for MigothsProfessionPilot.

local ADDON_NAME, PP = ...

PP.Utils = {}

--- Formats a copper value into a human-readable gold/silver/copper string.
-- @param copper number The amount in copper
-- @return string Formatted string like "12g 34s 56c"
function PP.Utils.FormatMoney(copper)
    if not copper or copper == 0 then return "0g" end

    local negative = copper < 0
    copper = math.abs(copper)

    local gold = math.floor(copper / PP.COPPER_PER_GOLD)
    local silver = math.floor((copper % PP.COPPER_PER_GOLD) / PP.COPPER_PER_SILVER)
    local remainingCopper = copper % PP.COPPER_PER_SILVER

    local result = ""
    if gold > 0 then
        result = result .. PP.COLORS.GOLD .. gold .. "g|r "
    end
    if silver > 0 or gold > 0 then
        result = result .. "|cFFC0C0C0" .. silver .. "s|r "
    end
    if remainingCopper > 0 and gold == 0 then
        result = result .. "|cFFB87333" .. remainingCopper .. "c|r"
    end

    result = strtrim(result)
    if negative then
        result = PP.COLORS.LOSS .. "-|r" .. result
    end
    return result
end

--- Formats a copper value into a short string (e.g. "12.5k", "1.2m").
-- @param copper number The amount in copper
-- @return string Shortened gold string
function PP.Utils.FormatMoneyShort(copper)
    if not copper then return "?" end
    local gold = copper / PP.COPPER_PER_GOLD
    if math.abs(gold) >= 1000000 then
        return string.format("%.1fm", gold / 1000000)
    elseif math.abs(gold) >= 1000 then
        return string.format("%.1fk", gold / 1000)
    elseif math.abs(gold) >= 1 then
        return string.format("%.0fg", gold)
    else
        return string.format("%.0fs", copper / PP.COPPER_PER_SILVER)
    end
end

--- Formats a timestamp difference into a relative time string.
-- @param timestamp number The past timestamp
-- @return string Relative time like "5 minutes"
function PP.Utils.FormatTimeAgo(timestamp)
    local L = PP.L
    local diff = time() - timestamp
    if diff < 60 then return L["TIME_JUST_NOW"]
    elseif diff < 3600 then return string.format(L["TIME_MINUTES"], math.floor(diff / 60))
    elseif diff < 86400 then return string.format(L["TIME_HOURS"], math.floor(diff / 3600))
    else return string.format(L["TIME_DAYS"], math.floor(diff / 86400))
    end
end

--- Prints a message with the addon prefix.
-- @param msg string The message
function PP.Utils.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(PP.COLORS.HEADER .. "Migoth's Profession Pilot|r: " .. msg)
end

--- Deep copies a table.
-- @param original table The table to copy
-- @return table A deep copy
function PP.Utils.DeepCopy(original)
    if type(original) ~= "table" then return original end
    local copy = {}
    for key, value in pairs(original) do
        copy[PP.Utils.DeepCopy(key)] = PP.Utils.DeepCopy(value)
    end
    return setmetatable(copy, getmetatable(original))
end

--- Merges defaults into a target table without overwriting existing keys.
-- @param target table The table to fill
-- @param defaults table The default values
function PP.Utils.ApplyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then target[key] = {} end
            PP.Utils.ApplyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

--- Returns an item name, requesting server data if needed.
-- @param itemID number The item ID
-- @return string|nil The item name
function PP.Utils.GetItemName(itemID)
    local name = C_Item.GetItemNameByID(itemID)
    if not name then C_Item.RequestLoadItemDataByID(itemID) end
    return name
end

--- Checks if the auction house frame is open.
-- @return boolean
function PP.Utils.IsAuctionHouseOpen()
    return AuctionHouseFrame and AuctionHouseFrame:IsShown()
end

--- Returns the difficulty color for a recipe.
-- @param difficulty number Enum.TradeskillRelativeDifficulty value (0-3)
-- @return string Color code
function PP.Utils.GetDifficultyColor(difficulty)
    if difficulty == 0 then return PP.DIFFICULTY.OPTIMAL.color
    elseif difficulty == 1 then return PP.DIFFICULTY.MEDIUM.color
    elseif difficulty == 2 then return PP.DIFFICULTY.EASY.color
    else return PP.DIFFICULTY.TRIVIAL.color
    end
end

--- Returns the skill-up chance for a difficulty level.
-- @param difficulty number Enum.TradeskillRelativeDifficulty value (0-3)
-- @return number Probability between 0.0 and 1.0
function PP.Utils.GetSkillUpChance(difficulty)
    if difficulty == 0 then return PP.DIFFICULTY.OPTIMAL.chance
    elseif difficulty == 1 then return PP.DIFFICULTY.MEDIUM.chance
    elseif difficulty == 2 then return PP.DIFFICULTY.EASY.chance
    else return PP.DIFFICULTY.TRIVIAL.chance
    end
end
