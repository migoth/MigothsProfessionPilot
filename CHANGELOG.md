# Changelog

All notable changes to MigothsProfessionPilot will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.3.2] - 2026-04-17

### Fixed
- AH tab now closes properly when switching to other AH tabs. Added per-tab OnClick hooks alongside PanelTemplates_SetTab hook since the modern AH uses custom click handlers that bypass PanelTemplates.
- Fishing is now included in profession scanning (previously only prof1, prof2, and cooking were scanned).
- nil gaps from GetProfessions() are now handled correctly (e.g., character with one primary profession and cooking but no second primary).

### Added
- **Automatic profession scanning**: MigothsProfessionPilot now silently opens each profession at login to scan recipes and expansion tiers. No need to manually open each profession window. The ProfessionsFrame is suppressed during auto-scan.
- All professions (including fishing) now show expansion-specific skill tiers after auto-scan.
- "Calculate Path" button is now functional after auto-scan populates recipe data.

## [0.3.1] - 2026-04-17

### Fixed
- AH tab z-ordering: tabs now use `PanelTemplates_EnableTab` and `PanelTemplates_DeselectTab` for proper frame level management, fixing the tab appearing behind standard AH tabs.
- Tab deactivation now hooks `PanelTemplates_SetTab` globally instead of individual tab OnClick handlers for more robust behavior.

## [0.3.0] - 2026-04-17

### Fixed
- AH tab integration completely reworked: custom tab was overlaid by standard tabs and non-functional because `AuctionHouseFrame_SetDisplayMode` doesn't exist in the modern retail AH.
- Tab deactivation now hooks each existing AH tab's OnClick directly.
- Panel uses overlay approach with `EnableMouse(true)` and raised frame level instead of fragile child-frame hide/show.

### Improved
- Profession list now clearly indicates when only a single fallback tier is available (hint to open profession window for all expansion tiers).
- Recipe hints shown directly below each profession header instead of at the bottom.
- Calculate Path button is disabled with tooltip when no recipes are scanned yet, preventing empty results.
- Leveling Path view now shows specific error messages: "no skillable recipes at this level" vs "no path calculated".
- Added German translations for all new UI strings.

## [0.2.1] - 2026-04-17

### Fixed
- Professions are now detected automatically at login via `GetProfessions()` — no need to open the trade skill window first.
- Expansion-specific skill tiers (e.g., Midnight 1/100) are now read correctly using `C_TradeSkillUI.GetProfessionInfoBySkillLineID()` instead of recipe categories, fixing tiers incorrectly showing as "Maxed".
- Cached profession data is restored from SavedVariables on addon load so data persists across sessions.
- Added `SKILL_LINES_CHANGED` listener for detecting newly learned professions.

### Improved
- Profession list shows a hint per profession when recipes haven't been scanned yet.
- Clearer empty-state messages throughout the UI.

## [0.2.0] - 2026-04-17

### Added
- Auction House tab: MigothsProfessionPilot UI is now embedded directly in the AH window as an extra tab. No need to open a separate window while at the auction house.

## [0.1.0] - 2026-04-16

### Added
- Core framework: event system, saved variables, slash commands (/pp, /migothsprofessionpilot).
- Full i18n support with English (enUS) and German (deDE) locales.
- Profession scanner: reads all professions, expansion skill tiers, known recipes, difficulty levels, and reagent data via C_TradeSkillUI.
- Inventory scanner: tracks materials across bags, bank, and reagent bank.
- AH price source: scans auction house for material prices, caches results, calculates sellback values with 5% AH cut.
- Path optimizer: greedy cost-per-skill-point algorithm that finds the cheapest leveling route per expansion tier, factoring in difficulty-based skill-up chances, inventory offsets, and sellback values.
- Main UI frame with tab navigation (Professions, Leveling Path, Shopping List, Settings).
- Profession list view with skill progress bars, incomplete-only filter, and per-tier "Calculate Path" button.
- Leveling path display showing step-by-step crafting instructions with cost breakdown, sellback, net cost, and material tooltips.
- Shopping list aggregating all required materials with inventory comparison, unit prices, and grand total.
- Settings panel: toggle sellback inclusion, inventory usage, and auto-scan on AH open.
- LibDBIcon minimap button with left-click toggle and right-click quick scan.
- Library stubs: LibStub, CallbackHandler, LibDataBroker, LibDBIcon.
