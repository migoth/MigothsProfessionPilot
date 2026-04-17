-- enUS.lua
-- English localization for MigothsProfessionPilot (default / fallback locale).

local ADDON_NAME, PP = ...
local L = PP.L

-- General
L["ADDON_NAME"] = "MigothsProfessionPilot"
L["ADDON_LOADED"] = "MigothsProfessionPilot v%s loaded. Type /pp for help."
L["SLASH_HELP"] = "Available commands:"
L["SLASH_HELP_TOGGLE"] = "/pp - Toggle main window"
L["SLASH_HELP_SCAN"] = "/pp scan - Start AH price scan"
L["SLASH_HELP_LIST"] = "/pp list - Show shopping list"
L["SLASH_HELP_RESET"] = "/pp reset - Reset all saved data"
L["SLASH_HELP_HELP"] = "/pp help - Show this help"
L["RESET_CONFIRM"] = "All MigothsProfessionPilot data has been reset."
L["RESET_PROMPT"] = "Type '/pp reset confirm' to reset all data. This cannot be undone."

-- Professions
L["PROF_ALCHEMY"] = "Alchemy"
L["PROF_BLACKSMITHING"] = "Blacksmithing"
L["PROF_ENCHANTING"] = "Enchanting"
L["PROF_ENGINEERING"] = "Engineering"
L["PROF_INSCRIPTION"] = "Inscription"
L["PROF_JEWELCRAFTING"] = "Jewelcrafting"
L["PROF_LEATHERWORKING"] = "Leatherworking"
L["PROF_TAILORING"] = "Tailoring"
L["PROF_COOKING"] = "Cooking"
L["PROF_FISHING"] = "Fishing"
L["PROF_FIRST_AID"] = "First Aid"
L["PROF_HERBALISM"] = "Herbalism"
L["PROF_MINING"] = "Mining"
L["PROF_SKINNING"] = "Skinning"

-- Expansions
L["XPAC_CLASSIC"] = "Classic"
L["XPAC_TBC"] = "The Burning Crusade"
L["XPAC_WOTLK"] = "Wrath of the Lich King"
L["XPAC_CATA"] = "Cataclysm"
L["XPAC_MOP"] = "Mists of Pandaria"
L["XPAC_WOD"] = "Warlords of Draenor"
L["XPAC_LEGION"] = "Legion"
L["XPAC_BFA"] = "Battle for Azeroth"
L["XPAC_SL"] = "Shadowlands"
L["XPAC_DF"] = "Dragonflight"
L["XPAC_TWW"] = "The War Within"
L["XPAC_MIDNIGHT"] = "Midnight"

-- Skill levels
L["SKILL_LEVEL"] = "Skill Level"
L["SKILL_CURRENT"] = "%d / %d"
L["SKILL_MAXED"] = "Maxed!"
L["SKILL_REMAINING"] = "%d points remaining"

-- Recipe difficulty
L["DIFFICULTY_OPTIMAL"] = "Optimal"
L["DIFFICULTY_MEDIUM"] = "Medium"
L["DIFFICULTY_EASY"] = "Easy"
L["DIFFICULTY_TRIVIAL"] = "Trivial"
L["DIFFICULTY_HEADER"] = "Difficulty"

-- Path optimizer
L["PATH_TITLE"] = "Leveling Path"
L["PATH_EMPTY"] = "No leveling path calculated yet. Select a profession tier and click 'Calculate Path'."
L["PROF_EMPTY"] = "No professions detected. Log in to your character and wait a moment."
L["PROF_HINT_RECIPES"] = "Open the profession window once to scan recipes for path calculation."
L["PATH_STEP"] = "Step %d"
L["PATH_CRAFT"] = "Craft %dx %s"
L["PATH_COST"] = "Cost: %s"
L["PATH_COST_PER_POINT"] = "Cost/Point: %s"
L["PATH_SELLBACK"] = "Sellback: %s"
L["PATH_NET_COST"] = "Net Cost: %s"
L["PATH_TOTAL_COST"] = "Total Cost: %s"
L["PATH_TOTAL_PROFIT"] = "Total Profit: %s"
L["PATH_SKILL_RANGE"] = "Skill %d -> %d"
L["PATH_GUARANTEED"] = "Guaranteed skill-up"
L["PATH_CHANCE"] = "~%.0f%% chance per craft"
L["PATH_CHANCE_RANGE"] = "%s~%.0f%%|r -> %s~%.0f%%|r chance per craft"
L["PATH_CALCULATING"] = "Calculating optimal path..."
L["PATH_NO_RECIPES"] = "No recipes available for skill-ups at this level."
L["PATH_NEED_RECIPES"] = "Recipes not yet scanned"
L["PATH_NO_RECIPES_HINT"] = "All known recipes may be trivial (gray) at this skill level, or no AH price data is available."
L["PATH_HAVE_MATERIALS"] = "Have materials"
L["PATH_NEED_MATERIALS"] = "Need to buy"
L["PROF_HINT_OPEN_TIERS"] = "Open the profession window to see all expansion tiers."

-- Inventory
L["INV_IN_BAGS"] = "In Bags: %d"
L["INV_IN_BANK"] = "In Bank: %d"
L["INV_IN_REAGENT_BANK"] = "In Reagent Bank: %d"
L["INV_TOTAL_OWNED"] = "Total Owned: %d"
L["INV_NEED_TO_BUY"] = "Need to Buy: %d"

-- AH / Prices
L["AH_SCAN_START"] = "Starting auction house scan..."
L["AH_SCAN_COMPLETE"] = "Scan complete. %d items updated in %.1f seconds."
L["AH_SCAN_FAILED"] = "Scan failed. Make sure the auction house is open."
L["AH_NOT_OPEN"] = "You must be at the auction house to scan prices."
L["AH_PRICES_OUTDATED"] = "Price data is %s old. Visit the AH to update."
L["PRICE_UNKNOWN"] = "Price unknown"

-- Shopping List
L["SHOP_TITLE"] = "Shopping List"
L["SHOPPING_LIST"] = "Shopping List"
L["SHOPPING_LIST_EMPTY"] = "No materials needed."
L["SHOPPING_LIST_TOTAL"] = "Total Cost: %s"
L["SHOPPING_LIST_GENERATE"] = "Generate Shopping List"
L["SHOPPING_LIST_COPY"] = "Copy to Chat"
L["COL_MATERIAL"] = "Material"
L["COL_NEED"] = "Need"
L["COL_HAVE"] = "Have"
L["COL_BUY"] = "Buy"
L["COL_PRICE"] = "Price"
L["COL_TOTAL"] = "Total"

-- UI
L["MAIN_TITLE"] = "MigothsProfessionPilot"
L["AH_TAB_TITLE"] = "MigothsProfessionPilot"
L["AH_BTN_TOOLTIP"] = "Click to open MigothsProfessionPilot panel"
L["TAB_PROFESSIONS"] = "Professions"
L["TAB_PATH"] = "Leveling Path"
L["TAB_SHOPPING"] = "Shopping List"
L["TAB_SETTINGS"] = "Settings"
L["BTN_SCAN"] = "Scan AH"
L["BTN_CALCULATE"] = "Calculate Path"
L["BTN_REFRESH"] = "Refresh"
L["FILTER_INCOMPLETE"] = "Incomplete Only"

-- Settings
L["SETTINGS_TITLE"] = "MigothsProfessionPilot Settings"
L["SETTINGS_INCLUDE_SELLBACK"] = "Include Sellback"
L["SETTINGS_INCLUDE_SELLBACK_DESC"] = "Offset material costs by estimated AH sell value of crafted items."
L["SETTINGS_USE_INVENTORY"] = "Use Inventory"
L["SETTINGS_USE_INVENTORY_DESC"] = "Subtract materials you already own from the cost calculation."
L["SETTINGS_AUTO_SCAN"] = "Auto Scan"
L["SETTINGS_AUTO_SCAN_DESC"] = "Automatically scan prices when opening the auction house."

-- Time
L["TIME_SECONDS"] = "%d seconds"
L["TIME_MINUTES"] = "%d minutes"
L["TIME_HOURS"] = "%d hours"
L["TIME_DAYS"] = "%d days"
L["TIME_JUST_NOW"] = "just now"
