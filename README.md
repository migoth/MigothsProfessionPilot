# MigothsProfessionPilot

A World of Warcraft addon that calculates the cheapest and fastest path to max out your professions. Analyzes your current skill levels, known recipes, available materials, and auction house prices to generate an optimal leveling route for every expansion.

## Features

- **Smart Path Calculation** – Finds the cheapest crafting route per skill point, factoring in recipe difficulty, material costs, and available inventory.
- **All Expansions** – Covers every expansion where your profession isn't maxed yet (Classic through Midnight).
- **Inventory Aware** – Checks your bags, bank, and reagent bank for materials you already own before suggesting purchases.
- **AH Price Integration** – Scans live auction house data for accurate material cost calculations.
- **Recipe Difficulty Tracking** – Knows which recipes still give guaranteed skill-ups (orange/yellow) vs. chance-based (green/gray).
- **Skill Tree Awareness** – Considers profession specializations and knowledge points.
- **Shopping List** – Generates a consolidated list of everything you need to buy.
- **Sellback Calculation** – Offsets costs by estimating how much crafted items sell for on the AH.
- **Multi-Language** – Full support for English and German (Deutsch).

## Installation

1. Download the latest release from the [Releases](../../releases) page.
2. Extract the `MigothsProfessionPilot` folder into your WoW addons directory:
   - Windows: `World of Warcraft\_retail_\Interface\AddOns\`
   - macOS: `/Applications/World of Warcraft/_retail_/Interface/AddOns/`
3. Restart WoW or type `/reload` in the chat.

## Usage

- **Open the main window**: Click the minimap button or type `/pp` in chat.
- **Select a profession**: Click on any profession in the list to see its leveling path.
- **Scan prices**: Visit the auction house for up-to-date material costs.
- **Follow the path**: Craft items in the suggested order for maximum efficiency.
- **Generate shopping list**: Click "Shopping List" to see all materials needed.

### Slash Commands

| Command | Description |
|---------|-------------|
| `/pp` | Toggle the main window |
| `/pp scan` | Start a manual AH price scan (must be at AH) |
| `/pp list` | Show the shopping list for current path |
| `/pp reset` | Reset all saved data |
| `/pp help` | Show available commands |

## How It Works

MigothsProfessionPilot reads your profession data via the TradeSkill API and builds a leveling graph:

1. **Scan** all known and learnable recipes with their skill-up ranges.
2. **Calculate** the material cost for each recipe using AH prices minus inventory on hand.
3. **Score** each recipe by cost-per-guaranteed-skill-point at the current level.
4. **Generate** a step-by-step path from current skill to max, always picking the cheapest option.
5. **Offset** costs by estimating AH sell value of crafted items.

### Cost Efficiency Formula

```
Effective Cost = Material Cost - Sellback Value
Cost per Skill Point = Effective Cost / Expected Skill-ups
```

The optimizer picks the recipe with the lowest cost per skill point at each level.

## Requirements

- World of Warcraft Retail (Midnight, Interface 120001)
- No external dependencies – everything runs in-game.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
