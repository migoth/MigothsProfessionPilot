# Changelog

All notable changes to MigothsProfessionPilot will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

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
