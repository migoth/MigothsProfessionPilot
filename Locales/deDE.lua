-- deDE.lua
-- German localization for MigothsProfessionPilot.

local ADDON_NAME, PP = ...

PP:RegisterLocale("deDE", {
    -- General
    ["ADDON_LOADED"] = "MigothsProfessionPilot v%s geladen. Tippe /pp fuer Hilfe.",
    ["SLASH_HELP"] = "Verfuegbare Befehle:",
    ["SLASH_HELP_TOGGLE"] = "/pp - Hauptfenster umschalten",
    ["SLASH_HELP_SCAN"] = "/pp scan - AH-Preisscan starten",
    ["SLASH_HELP_LIST"] = "/pp list - Einkaufsliste anzeigen",
    ["SLASH_HELP_RESET"] = "/pp reset - Alle gespeicherten Daten zuruecksetzen",
    ["SLASH_HELP_HELP"] = "/pp help - Diese Hilfe anzeigen",
    ["RESET_CONFIRM"] = "Alle MigothsProfessionPilot-Daten wurden zurueckgesetzt.",
    ["RESET_PROMPT"] = "Tippe '/pp reset confirm' um alle Daten zurueckzusetzen.",

    -- Professions
    ["PROF_ALCHEMY"] = "Alchemie",
    ["PROF_BLACKSMITHING"] = "Schmiedekunst",
    ["PROF_ENCHANTING"] = "Verzauberkunst",
    ["PROF_ENGINEERING"] = "Ingenieurskunst",
    ["PROF_INSCRIPTION"] = "Inschriftenkunde",
    ["PROF_JEWELCRAFTING"] = "Juwelierskunst",
    ["PROF_LEATHERWORKING"] = "Lederverarbeitung",
    ["PROF_TAILORING"] = "Schneiderei",
    ["PROF_COOKING"] = "Kochen",
    ["PROF_FISHING"] = "Angeln",
    ["PROF_FIRST_AID"] = "Erste Hilfe",
    ["PROF_HERBALISM"] = "Kraeuterkunde",
    ["PROF_MINING"] = "Bergbau",
    ["PROF_SKINNING"] = "Kuerschnerei",

    -- Expansions
    ["XPAC_CLASSIC"] = "Klassisch",
    ["XPAC_TBC"] = "Brennender Kreuzzug",
    ["XPAC_WOTLK"] = "Zorn des Lichkoenigs",
    ["XPAC_CATA"] = "Kataklysmus",
    ["XPAC_MOP"] = "Nebel von Pandaria",
    ["XPAC_WOD"] = "Warlords of Draenor",
    ["XPAC_LEGION"] = "Legion",
    ["XPAC_BFA"] = "Schlacht um Azeroth",
    ["XPAC_SL"] = "Shadowlands",
    ["XPAC_DF"] = "Dragonflight",
    ["XPAC_TWW"] = "The War Within",
    ["XPAC_MIDNIGHT"] = "Midnight",

    -- Skill levels
    ["SKILL_LEVEL"] = "Fertigkeitsstufe",
    ["SKILL_CURRENT"] = "%d / %d",
    ["SKILL_MAXED"] = "Maximal!",
    ["SKILL_REMAINING"] = "%d Punkte verbleibend",

    -- Recipe difficulty
    ["DIFFICULTY_OPTIMAL"] = "Optimal",
    ["DIFFICULTY_MEDIUM"] = "Mittel",
    ["DIFFICULTY_EASY"] = "Einfach",
    ["DIFFICULTY_TRIVIAL"] = "Trivial",
    ["DIFFICULTY_HEADER"] = "Schwierigkeit",

    -- Path optimizer
    ["PATH_TITLE"] = "Leveling-Pfad",
    ["PATH_EMPTY"] = "Noch kein Leveling-Pfad berechnet. Waehle eine Berufsstufe und klicke 'Pfad berechnen'.",
    ["PROF_EMPTY"] = "Keine Berufe erkannt. Logge dich ein und warte einen Moment.",
    ["PROF_HINT_RECIPES"] = "Oeffne das Berufsfenster einmal, um Rezepte fuer die Pfadberechnung zu scannen.",
    ["PATH_STEP"] = "Schritt %d",
    ["PATH_CRAFT"] = "Stelle %dx %s her",
    ["PATH_COST"] = "Kosten: %s",
    ["PATH_COST_PER_POINT"] = "Kosten/Punkt: %s",
    ["PATH_SELLBACK"] = "Verkaufswert: %s",
    ["PATH_NET_COST"] = "Nettokosten: %s",
    ["PATH_TOTAL_COST"] = "Gesamtkosten: %s",
    ["PATH_SKILL_RANGE"] = "Fertigkeit %d → %d",
    ["PATH_GUARANTEED"] = "Garantierter Fertigkeitspunkt",
    ["PATH_CHANCE"] = "~%.0f%% Chance pro Herstellung",
    ["PATH_CALCULATING"] = "Berechne optimalen Pfad...",
    ["PATH_NO_RECIPES"] = "Keine Rezepte fuer Fertigkeitspunkte auf dieser Stufe verfuegbar.",
    ["PATH_HAVE_MATERIALS"] = "Materialien vorhanden",
    ["PATH_NEED_MATERIALS"] = "Muss gekauft werden",

    -- Inventory
    ["INV_IN_BAGS"] = "In Taschen: %d",
    ["INV_IN_BANK"] = "In Bank: %d",
    ["INV_IN_REAGENT_BANK"] = "In Reagenzienbank: %d",
    ["INV_TOTAL_OWNED"] = "Insgesamt vorhanden: %d",
    ["INV_NEED_TO_BUY"] = "Muss gekauft werden: %d",

    -- AH / Prices
    ["AH_SCAN_START"] = "Auktionshaus-Scan wird gestartet...",
    ["AH_SCAN_COMPLETE"] = "Scan abgeschlossen. %d Artikel in %.1f Sekunden aktualisiert.",
    ["AH_SCAN_FAILED"] = "Scan fehlgeschlagen. Stelle sicher, dass das Auktionshaus geoeffnet ist.",
    ["AH_NOT_OPEN"] = "Du musst am Auktionshaus sein, um Preise zu scannen.",
    ["AH_PRICES_OUTDATED"] = "Preisdaten sind %s alt. Besuche das AH zum Aktualisieren.",
    ["PRICE_UNKNOWN"] = "Preis unbekannt",

    -- Shopping List
    ["SHOP_TITLE"] = "Einkaufsliste",
    ["SHOPPING_LIST"] = "Einkaufsliste",
    ["SHOPPING_LIST_EMPTY"] = "Keine Materialien benoetigt.",
    ["SHOPPING_LIST_TOTAL"] = "Gesamtkosten: %s",
    ["SHOPPING_LIST_GENERATE"] = "Einkaufsliste erstellen",
    ["SHOPPING_LIST_COPY"] = "In Chat kopieren",
    ["COL_MATERIAL"] = "Material",
    ["COL_NEED"] = "Bedarf",
    ["COL_HAVE"] = "Vorhanden",
    ["COL_BUY"] = "Kaufen",
    ["COL_PRICE"] = "Preis",
    ["COL_TOTAL"] = "Gesamt",

    -- UI
    ["MAIN_TITLE"] = "MigothsProfessionPilot",
    ["AH_TAB_TITLE"] = "MigothsProfessionPilot",
    ["TAB_PROFESSIONS"] = "Berufe",
    ["TAB_PATH"] = "Leveling-Pfad",
    ["TAB_SHOPPING"] = "Einkaufsliste",
    ["TAB_SETTINGS"] = "Einstellungen",
    ["BTN_SCAN"] = "AH Scannen",
    ["BTN_CALCULATE"] = "Pfad berechnen",
    ["BTN_REFRESH"] = "Aktualisieren",
    ["FILTER_INCOMPLETE"] = "Nur unvollstaendige",

    -- Settings
    ["SETTINGS_TITLE"] = "MigothsProfessionPilot Einstellungen",
    ["SETTINGS_INCLUDE_SELLBACK"] = "Verkaufswert einbeziehen",
    ["SETTINGS_INCLUDE_SELLBACK_DESC"] = "Materialkosten durch geschaetzten AH-Verkaufswert der hergestellten Gegenstaende ausgleichen.",
    ["SETTINGS_USE_INVENTORY"] = "Inventar verwenden",
    ["SETTINGS_USE_INVENTORY_DESC"] = "Bereits vorhandene Materialien von der Kostenberechnung abziehen.",
    ["SETTINGS_AUTO_SCAN"] = "Automatischer Scan",
    ["SETTINGS_AUTO_SCAN_DESC"] = "Preise automatisch scannen, wenn das Auktionshaus geoeffnet wird.",

    -- Time
    ["TIME_SECONDS"] = "%d Sekunden",
    ["TIME_MINUTES"] = "%d Minuten",
    ["TIME_HOURS"] = "%d Stunden",
    ["TIME_DAYS"] = "%d Tage",
    ["TIME_JUST_NOW"] = "gerade eben",
})
