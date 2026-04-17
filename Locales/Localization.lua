-- Localization.lua
-- Localization framework for MigothsProfessionPilot.
-- Provides key-value lookup with fallback to English.

local ADDON_NAME, PP = ...

-- Default locale table (English is the fallback)
PP.L = {}

-- Registry of locale-specific overrides
PP.localeOverrides = {}

--- Registers translations for a specific locale.
-- @param locale string The locale code (e.g. "enUS", "deDE")
-- @param translations table Key-value pairs of translated strings
function PP:RegisterLocale(locale, translations)
    self.localeOverrides[locale] = translations
end

--- Initializes the localization system.
-- Merges the matching locale's overrides into the active table.
function PP:InitLocalization()
    local clientLocale = GetLocale()
    local overrides = self.localeOverrides[clientLocale]
    if overrides then
        for key, value in pairs(overrides) do
            self.L[key] = value
        end
    end
end
