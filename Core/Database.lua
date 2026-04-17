-- Database.lua
-- SavedVariables management for MigothsProfessionPilot.

local ADDON_NAME, PP = ...

PP.Database = {}

--- Initializes global and per-character saved variable tables.
function PP.Database:Init()
    if not MigothsProfessionPilotDB then MigothsProfessionPilotDB = {} end
    PP.Utils.ApplyDefaults(MigothsProfessionPilotDB, PP.DEFAULTS.global)
    PP.db = MigothsProfessionPilotDB

    if not MigothsProfessionPilotCharDB then MigothsProfessionPilotCharDB = {} end
    PP.Utils.ApplyDefaults(MigothsProfessionPilotCharDB, PP.DEFAULTS.char)
    PP.charDb = MigothsProfessionPilotCharDB
end

--- Resets all saved data to defaults.
function PP.Database:Reset()
    MigothsProfessionPilotDB = PP.Utils.DeepCopy(PP.DEFAULTS.global)
    MigothsProfessionPilotCharDB = PP.Utils.DeepCopy(PP.DEFAULTS.char)
    PP.db = MigothsProfessionPilotDB
    PP.charDb = MigothsProfessionPilotCharDB
end

--- Returns the settings table.
-- @return table
function PP.Database:GetSettings()
    return PP.db.settings
end

--- Returns the price cache.
-- @return table
function PP.Database:GetPrices()
    return PP.db.prices
end
