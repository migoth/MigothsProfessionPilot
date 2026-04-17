# Changelog

All notable changes to MigothsProfessionPilot will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.7.6] - 2026-04-17

### Fixed
- **ADDON_ACTION_BLOCKED error**: Removed auto-scan system that called the protected `OpenTradeSkill()` function. Profession data is now loaded when the player manually opens each profession window, and cached in SavedVariables for future sessions.

### Changed
- **German localization**: Proper umlauts (ä, ö, ü, ß) instead of ASCII substitutions.

## [0.7.5] - 2026-04-17

### Changed
- **AH tab redesign**: Replaced custom side-tab with a Blizzard-style bottom tab (icon only, with tooltip). Matches the native AH look.

## [0.7.4] - 2026-04-17

### Changed
- **AH side-tab**: Replaced the small icon button on the AH title bar with a vertical side-tab on the right edge of the AH frame. Shows addon icon and "MPP" label, highlights when the panel is open.
- Slash commands changed to `/mpp` (removed old `/pp` alias).

## [0.7.3] - 2026-04-17

### Fixed
- **All professions showing the same guide (Cooking)**: Complete rewrite of
  `ScanCurrentProfession` profID resolution. The function now uses 4 ordered
  strategies to correctly map the Enum.Profession value to the skill-line-based
  cache key:
  1. During auto-scan, uses the exact skill line ID that was opened
  2. Uses the enum->skillLine mapping from ScanExpansionTiers
  3. Exact name match against existing cache entries
  4. Falls back to the enum value itself
  The mapping is now recorded after every successful resolution to prevent
  future mismatches. Recipes are also cleared before re-scanning so stale
  data from a previous incorrect scan is removed.
- **Recipes from wrong expansion tier used in path**: Added `tierID` field to
  each cached recipe by walking the category hierarchy
  (`C_TradeSkillUI.GetCategoryInfo`) up to the expansion tier. `GetSkillableRecipes`
  now filters by tier when a `categoryID` is passed, so the optimizer only uses
  recipes that actually give skill-ups for the selected expansion.

### Changed
- **AH auto-scan removed**: The auction house is no longer scanned automatically
  when opening the AH or logging in. Use `/mpp scan` or the Scan button instead.
  The "Auto Scan" setting checkbox has been removed from both settings panels.

### Added
- **Incomplete path warning**: When the optimizer can't build a path to max skill
  (e.g. because you haven't learned enough recipes yet), the leveling path now
  shows a warning explaining that more recipes are needed instead of just stopping
  silently.
- Debug output (`/mpp debug`) now shows per-tier recipe counts and how many recipes
  are untagged (no tier association).

## [0.7.2] - 2026-04-17

### Fixed
- **Expansion tier detection rewritten from scratch**: Complete redesign using
  a group-by-parent approach instead of per-line matching. The new algorithm:
  1. Collects ALL trade skill lines and their `ProfessionInfo`
  2. Groups them by `parentProfessionID`
  3. Matches each group to our profession using 4 fallback strategies:
     - A) `parentProfessionID` matches our `profID` directly
     - B) Enum resolution via `GetProfessionInfoBySkillLineID(profID)`
     - C) Our `profID` appears as a child line in the group
     - D) Case-insensitive substring name matching (professionName/expansionName)
  4. All children in the matched group become tiers
  This approach is far more robust since it doesn't depend on any single
  API field being correct.
- **Tier display names**: Now uses `expansionName` first (e.g. "Classic Alchemy",
  "Midnight Alchemy") instead of the base `professionName` which was the same
  for all tiers.
- `ScanTiersFromOpenWindow` now delegates to the same robust implementation
  instead of having its own (outdated) matching logic.

### Added
- `/mpp debug` command prints detailed API diagnostics to chat:
  - Character professions from `GetProfessions()`
  - All trade skill lines with parentProfessionID, professionID, names
  - Cached profession data with tier count and recipe count
  Use this to diagnose tier detection issues.

## [0.7.1] - 2026-04-17

### Fixed
- **Single step in leveling path**: The optimizer now always creates separate
  steps at difficulty transitions (orange->yellow->green). Previously all crafts
  were merged into one step because the same recipe stayed cheapest at every
  level. Now you see e.g. "Step 1: 8x Recipe A (orange), Step 2: 11x Recipe A
  (yellow), Step 3: 24x Recipe B (green)".
- **Expansion tiers not showing (again)**: Added name-based matching as a third
  fallback when detecting expansion tiers. If both the skill line ID comparison
  and Enum.Profession resolution fail, the scanner now compares the child
  tier's `professionName` against the cached profession name. Also stores the
  reverse enum mapping when discovered through child tiers.
- **AH scan never completing**: Replaced the unreliable `ReplicateItems()` full
  AH scan with targeted per-material commodity searches. The scan now:
  - Collects all material IDs from scanned recipes
  - Searches each one individually via `C_AuctionHouse.SendSearchQuery`
  - Processes `COMMODITY_SEARCH_RESULTS_UPDATED` for each material
  - Skips non-commodity items after a 2-second timeout
  - Falls back to `ReplicateItems` only when no recipe data exists
  - Has proper error handling (pcall) and AH-close detection

## [0.7.0] - 2026-04-17

### Changed
- **Leveling path simulation rewrite**: The path optimizer now simulates skill
  progression point by point instead of assuming a single recipe covers all
  remaining skill points.
  - Recipes degrade in difficulty as your skill increases (orange -> yellow ->
    green -> gray), matching WoW's actual skill-up mechanics.
  - The optimizer switches to cheaper recipes automatically when the current
    recipe's difficulty drops and a better option is available.
  - Multiple steps are generated showing exactly when to switch recipes and
    how many crafts are needed at each stage.
  - Craft counts account for reduced skill-up probability at yellow (~75%)
    and green (~35%) difficulty levels.
- Path cost calculation now uses pure AH market prices (not inventory-adjusted)
  for accurate recipe comparison across the entire simulated path.
- Tooltip shows difficulty range (e.g. "~100% -> ~75%") when a step spans
  multiple difficulty transitions.

## [0.6.2] - 2026-04-17

### Fixed
- **Expansion tiers not showing**: Fixed a critical bug where only one tier (the current expansion) was displayed for crafting professions. The WoW API returns `parentProfessionID` as an `Enum.Profession` value (e.g. 3 for Alchemy) while MigothsProfessionPilot was comparing against the skill line ID (e.g. 171). These never matched, so child expansion tiers were silently discarded. The scanner now resolves the Enum.Profession value via `GetProfessionInfoBySkillLineID` before comparing, and uses both ID types as fallback.
- **Cache key mismatch**: `ScanCurrentProfession` (triggered when opening the profession window) could create a duplicate cache entry under a different key than the initial login scan. Now uses an `enumToSkillLine` mapping and name-based fallback to always find the correct entry.
- **Fallback tier cleanup**: When real expansion tiers are discovered, the single fallback tier entry is now automatically removed so it doesn't show alongside the real tiers.

## [0.6.1] - 2026-04-17

### Changed
- **Incomplete filter on by default**: The profession list now shows only incomplete (non-maxed) tiers by default. Can be toggled off.
- **Sellback disabled by default**: Cost calculations now show pure material cost only. The "Include Sellback" setting is still available in Settings if needed.

### Fixed
- **UI not refreshing after opening profession window**: MigothsProfessionPilot now automatically refreshes the profession list and all visible panels when the profession window updates (TRADE_SKILL_LIST_UPDATE). Opening the profession window to scan expansion tiers now immediately reflects in the addon.
- **Format string bug**: Fixed "Kosten: %s 12g 34s" in tooltips — the `%s` placeholder was displayed literally instead of being replaced by the formatted value. All tooltip cost lines now use `string.format` correctly.

### Added
- **Click recipe to open crafting window**: Clicking a recipe row in the Leveling Path now opens the WoW profession window with that recipe selected via `C_TradeSkillUI.OpenRecipe`.
- **Shift-click to search AH**: Shift-left-clicking a recipe row in the Leveling Path inserts the crafted item link into the AH search bar (or chat). Shift-left-clicking a material row in the Shopping List does the same for that material. Uses standard `HandleModifiedItemClick` behavior.
- AuctionHouseTab now has a `Refresh()` method for external UI refresh triggers.

## [0.6.0] - 2026-04-17

### Changed
- **Complete modern UI redesign**: Replaced all Blizzard standard templates with a custom Theme system. Every panel now uses a dark, flat, borderless design with a cyan accent color scheme.
- **New Theme.lua module**: Shared UI component library providing styled windows, title bars, tab bars, buttons, progress bars, checkboxes (toggle switches), scroll areas with minimal scrollbars, section headers, and alternating-color list rows — all without Blizzard templates.
- **MainFrame**: Modern frameless window with shadow, accent-colored title bar, pill-style tab navigation, and compact layout (720x540).
- **AuctionHouseTab**: Floating panel beside the AH using Theme components. Dark card styling with the same tab system and layout as the main window.
- **ProfessionList**: Custom filter toggle button, Theme-based section headers with accent bar, progress bars with maxed/incomplete coloring, and styled Calculate buttons.
- **LevelingPath**: Compact 42px rows with difficulty color bars, 28x28 recipe icons, skill range sub-text, and rich hover tooltips showing full cost breakdown and material status.
- **ShoppingList**: Column header bar with accent-colored labels, 26px material rows with item tooltips, color-coded Have/Buy/Total columns, and grand total in header.

### Technical
- All UI files rewritten to use `PP.Theme` helpers exclusively — no `UIPanelButtonTemplate`, `UIPanelScrollFrameTemplate`, or `UICheckButtonTemplate` usage.
- Custom scrollbar implementation with thin 4px track and drag-proportional thumb.
- Toggle-style checkboxes replacing standard WoW checkboxes.
- Alternating row colors with hover highlight across all list views.

## [0.5.0] - 2026-04-17

### Changed
- **Simplified leveling path UI**: Compact single-line rows with difficulty color bar, recipe icon, craft instruction, and net cost. Full cost breakdown and material list moved to hover tooltip.
- **Improved path optimizer**: Produces one consolidated step per difficulty tier instead of many repeated 5-point chunks of the same recipe.
- **Better cost display**: Negative costs (profitable recipes) now show as green "Profit" instead of confusing negative numbers. Both the total header and individual step rows use this treatment.

### Added
- **Item tooltips on shopping list**: Hovering a material row now shows the WoW item tooltip (quality, type, item level, etc.).
- **Crafted item info in path tooltip**: Hovering a path step shows what item is produced.
- Gathering professions (Mining, Herbalism, Skinning) are now excluded from the profession list and path calculations since they're leveled by gathering, not crafting.

### Fixed
- Replaced Unicode arrow character in skill range display with ASCII to prevent broken glyphs in WoW.

## [0.4.0] - 2026-04-17

### Changed
- **AH integration reworked**: Replaced the AH tab (which overlaid the AH content) with a small icon button in the AH title bar. Clicking it opens MigothsProfessionPilot as a standalone floating panel next to the AH, so both windows are visible simultaneously. The panel is movable, has a close button, and auto-closes when the AH is closed.

### Fixed
- **Calculate Path button now works**: Fixed recipe lookup that was failing because recipe sub-category IDs didn't match expansion tier skill line IDs. The path optimizer now uses the full recipe cache, so all skillable recipes are considered for path calculation.
- Calculate Path button now correctly switches to the path tab in the AH panel context instead of only working in the standalone window.

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
- Core framework: event system, saved variables, slash commands (/mpp, /migothsprofessionpilot).
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
