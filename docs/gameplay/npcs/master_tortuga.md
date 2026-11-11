# Master Tortuga: Craft and Forge

`gameplay/npcs/master_tortuga/master_tortuga_npc.tscn` contains the stationary NPC and its `TortugaPanel`. The NPC says its Dialogic greeting, then opens the panel. Closing it restores normal play. The scene is placed in `world/hub/scenes/hub.tscn` and the project's `world/tests/test_scene.tscn`.

## Craft

The Craft tab lists unlocked blueprints from `data/forge/tortuga_catalog.tres`, including weapons already crafted and the starter Dagger. Owned weapons have a darker slot. Selecting one shows its base stats and the gold and material requirements. A successful transaction checks payment, deducts it and grants the weapon without equipping it. The blueprint remains unlocked, while the Craft button becomes disabled for an owned weapon. A failed grant refunds payment.

The selected weapon's detail pane follows the Inventory Equipment tab: combat stats, current Forge attributes and the weapon skill appear in a scrollable view. An uncrafted Blueprint uses base values; an owned weapon uses its active Forge. The editable layout is `gameplay/forge/tortuga_weapon_details.tscn`, with stat tiles in `tortuga_stat_tile.tscn`. Costs and the Craft/Forge action stay below the detail view.

The source for the prototype recipes is the [Weapons tab of the balance sheet](https://docs.google.com/spreadsheets/d/1GFGub8L-NBznHdhdoDl4mzo-B9xavXrR2RNTXG-1DmU/edit?gid=740360440#gid=740360440):

| Weapon | Gold | Materials |
| --- | ---: | --- |
| Dagger | 0 | Starter weapon; no materials |
| Bow | 100 | Starfish Core ×5, Crab Claw ×5 |
| Harpoon | 250 | Crab Claw ×2, Starfish Core ×1, Coral ×5 |

Only Bow and Harpoon are implemented as craftable non-starter weapons. Dagger is the starter and normally appears as already owned. The other five weapons in the sheet have no gameplay `WeaponData` yet. `Coral` has a temporary icon and item resource but no world drop source yet. The debug-only **Debug: Supplies** button gives sample materials and gold for testing.

## Forge

The Forge tab lists owned weapons. Pressing **Forge weapon** pays once and draws two distinct weighted results from the existing shared `WeaponForgePool`. The Tortuga book hides while a modal popup displays one result per column, with its description and stat rows comparing the current and proposed values. Green means a beneficial change; red means a harmful change. For windup, recovery and Stamina cost, a lower value is beneficial. Unchanged or non-applicable values remain neutral. Selecting one replaces the weapon's single active Forge, updates its collection entry, refreshes Equipment and reveals the book again. The player cannot close the panel, switch tabs, or select another weapon until choosing one of the two results.

The GDD specifies gold and materials for each Forge but the balance sheet does not specify their amounts. The temporary values are **75 Gold, 2 Crab Claws, 1 Starfish Core** per roll, editable on `TortugaCatalog` in the Inspector. Payment occurs when the pair is rolled. Cost chips show a currency or item icon and current/required counts; their layout is in `gameplay/forge/tortuga_cost_chip.tscn`. The two-column popup and comparison row layouts are in `tortuga_forge_popup.tscn`, `tortuga_forge_card.tscn`, and `tortuga_stat_row.tscn` in the same directory.

Blueprint/weapon ownership, inventory and Forge changes are runtime state. The project still needs its general save system to retain them between launches, and blueprint/world-drop progression is not added here.

Run `godot --headless --path . --script res://test/tortuga_test.gd` to check scene loading, payment, crafting, distinct Forge options and the dialogue-to-panel flow.
