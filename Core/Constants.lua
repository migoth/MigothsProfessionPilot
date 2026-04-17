-- Constants.lua
-- Global constants for MigothsProfessionPilot.

local ADDON_NAME, PP = ...

PP.VERSION = "0.6.1"

-- Auction house cut (5%)
PP.AH_CUT = 0.05

-- Minimum interval between AH scans in seconds
PP.MIN_SCAN_INTERVAL = 60

-- Copper conversion
PP.COPPER_PER_SILVER = 100
PP.COPPER_PER_GOLD = 10000

-- Default settings
PP.DEFAULTS = {
    global = {
        prices = {},            -- AH price cache: itemID -> {minBuyout, lastScan}
        settings = {
            includeSellback = false,   -- Offset costs by crafted item sell value
            useInventory = true,       -- Subtract owned materials from costs
            autoScan = true,           -- Auto-scan when AH opens
            minimapButton = {
                hide = false,
            },
        },
    },
    char = {
        lastScanTime = 0,
        professions = {},       -- Cached profession data per expansion
        inventory = {},         -- Cached material counts
        lastPath = {},          -- Last calculated leveling path
    },
}

-- Recipe difficulty levels mapped to skill-up probability
-- Optimal = guaranteed, Medium = high chance, Easy = low chance, Trivial = no skill-up
PP.DIFFICULTY = {
    OPTIMAL = { id = 0, chance = 1.00,  color = "|cFFFF8040" },  -- Orange
    MEDIUM  = { id = 1, chance = 0.75,  color = "|cFFFFFF00" },  -- Yellow
    EASY    = { id = 2, chance = 0.35,  color = "|cFF40C040" },  -- Green
    TRIVIAL = { id = 3, chance = 0.00,  color = "|cFF808080" },  -- Gray
}

-- Expansion data: skill line prefix IDs and max skill levels
-- Each expansion has its own skill tier since the BfA restructuring.
PP.EXPANSIONS = {
    { id = "classic",   name = "XPAC_CLASSIC",   maxSkill = 300 },
    { id = "tbc",       name = "XPAC_TBC",       maxSkill = 75  },
    { id = "wotlk",     name = "XPAC_WOTLK",     maxSkill = 75  },
    { id = "cata",      name = "XPAC_CATA",       maxSkill = 75  },
    { id = "mop",       name = "XPAC_MOP",        maxSkill = 75  },
    { id = "wod",       name = "XPAC_WOD",        maxSkill = 100 },
    { id = "legion",    name = "XPAC_LEGION",     maxSkill = 100 },
    { id = "bfa",       name = "XPAC_BFA",        maxSkill = 175 },
    { id = "sl",        name = "XPAC_SL",         maxSkill = 100 },
    { id = "df",        name = "XPAC_DF",         maxSkill = 100 },
    { id = "tww",       name = "XPAC_TWW",        maxSkill = 100 },
    { id = "midnight",  name = "XPAC_MIDNIGHT",   maxSkill = 100 },
}

-- Gathering professions - excluded from leveling path calculations
-- (skilled by gathering, not by crafting)
PP.GATHERING_PROFESSION_IDS = {
    [182] = true,   -- Herbalism
    [186] = true,   -- Mining
    [393] = true,   -- Skinning
}

-- Crafting profession skill line IDs (base IDs)
PP.PROFESSION_IDS = {
    ALCHEMY         = 171,
    BLACKSMITHING   = 164,
    ENCHANTING      = 333,
    ENGINEERING     = 202,
    INSCRIPTION     = 773,
    JEWELCRAFTING   = 755,
    LEATHERWORKING  = 165,
    TAILORING       = 197,
    COOKING         = 185,
}

-- Reverse lookup: skill line ID -> localization key
PP.PROFESSION_NAMES = {
    [171] = "PROF_ALCHEMY",
    [164] = "PROF_BLACKSMITHING",
    [333] = "PROF_ENCHANTING",
    [202] = "PROF_ENGINEERING",
    [773] = "PROF_INSCRIPTION",
    [755] = "PROF_JEWELCRAFTING",
    [165] = "PROF_LEATHERWORKING",
    [197] = "PROF_TAILORING",
    [185] = "PROF_COOKING",
}

-- Color codes
PP.COLORS = {
    PROFIT   = "|cFF00FF00",
    LOSS     = "|cFFFF0000",
    NEUTRAL  = "|cFFFFFF00",
    WHITE    = "|cFFFFFFFF",
    GRAY     = "|cFF808080",
    GOLD     = "|cFFFFD700",
    HEADER   = "|cFF00CCFF",
    MAXED    = "|cFF00FF00",
    INCOMPLETE = "|cFFFF8800",
}
