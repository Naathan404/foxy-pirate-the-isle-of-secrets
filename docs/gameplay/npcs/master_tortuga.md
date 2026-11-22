# Master Tortuga: Craft and Forge

`gameplay/npcs/master_tortuga/master_tortuga_npc.tscn` contains the stationary NPC and its `TortugaPanel`. The NPC says its Dialogic greeting, then opens the panel. Closing it restores normal play. The scene is placed in `world/hub/scenes/hub.tscn` and the project's `world/tests/test_scene.tscn`.

## Craft

The Craft tab lists unlocked blueprints from `data/forge/tortuga_catalog.tres`, including weapons already crafted and the starter Dagger. The counter shows unlocked blueprints / recipes. A crafted weapon carries the anvil badge and the equipped weapon the anchor badge, as in the Inventory; the status line under the name also says "Blueprint", "Crafted" or "Equipped". Selecting one shows its base stats and the gold and material requirements. A successful transaction checks payment, deducts it and grants the weapon without equipping it. The blueprint remains unlocked, while the action becomes a disabled "Crafted" for an owned weapon. A failed grant refunds payment. A recipe with no cost shows "No cost" instead of empty chips.

The selected weapon's detail pane follows the Inventory menu Weapon tab: combat stats, current Forge attributes and the weapon skill appear in a scrollable view. An uncrafted Blueprint uses base values; an owned weapon uses its active Forge. Stat names, icons and Forge field labels come from `InventoryWeaponsTab`, so the two screens stay in sync. The editable layout is `gameplay/forge/tortuga_weapon_details.tscn`.

### Panel layout

`tortuga_panel.tscn` uses the Inventory menu theme, background ink, tab buttons, catalog slots and Back button, so the forge reads as part of the same menu family:

- Left: Master Tortuga's portrait, a line of dialogue for the current tab and the player's gold.
- Middle: the Craft or Forge list, then the cost chips (`tortuga_cost_chip.tscn`). Each chip shows carried / required with a ✓ or ✕ and a red frame when it is short.
- Right: the weapon sheet, then the reason line and the action. When the action is disabled, the reason lists what is missing, for example "Missing 80 gold, 5 Crab Claw".
- Forge mood: orange ink rim, coal glow behind the portrait, rising embers and a short orange flash when the hammer lands (a craft, a roll or an applied Forge).

Controls: mouse; Page Up / Page Down switch tabs; arrow keys move between slots; Enter / Space press the focused slot or button; Esc or Back leaves. All tweens run while the game is paused, the same as the Inventory.

The source for the prototype recipes is the [Weapons tab of the balance sheet](https://docs.google.com/spreadsheets/d/1GFGub8L-NBznHdhdoDl4mzo-B9xavXrR2RNTXG-1DmU/edit?gid=740360440#gid=740360440):

| Weapon | Gold | Materials |
| --- | ---: | --- |
| Dagger | 0 | Starter weapon; no materials |
| Bow | 100 | Starfish Core ×5, Crab Claw ×5 |
| Harpoon | 250 | Crab Claw ×2, Starfish Core ×1, Coral ×5 |

Storm Bow, Harpoon and Meteor Staff are implemented as craftable non-starter weapons. Dagger is the starter and normally appears as already owned. Their blueprint items unlock the corresponding Craft recipes when collected; see [weapon blueprints](../weapons/weapon_collection.md#blueprint-pickups). Meteor Staff currently costs 250 gold, 5 Fireflies Tails and 5 Coral. The debug-only **Debug: Supplies** button gives sample materials and gold for testing.

## Forge

The Forge tab lists owned weapons. Pressing **Forge** pays once and draws two distinct weighted results from the existing shared `WeaponForgePool`. The panel hides while a modal popup shows the two results as cards (`tortuga_forge_card.tscn`): the forge name, what it replaces, its description and a "now → new" comparison of every affected stat (`tortuga_stat_row.tscn`). Changed stats come first and are labelled "▲ better" or "▼ worse" as well as colored; a summary line counts them. For windup, recovery and Stamina cost, a lower value is better. Unchanged or non-applicable values remain neutral. Choosing one replaces the weapon's single active Forge, updates its collection entry, refreshes Equipment and brings the panel back. Both buttons lock after the first press, so a double click cannot apply twice. The player cannot close the panel (Esc, Back), switch tabs or select another weapon until choosing one of the two results; the popup says why.

`close_panel(true)` (used when the NPC leaves the tree, for example on a scene change) cannot wait for a choice. If a paid roll is still open, it calls `TortugaService.refund_forge_roll()` to return that roll's gold and materials before closing, so the payment is never lost.

The GDD specifies gold and materials for each Forge but the balance sheet does not specify their amounts. The temporary values are **75 Gold, 2 Crab Claws, 1 Starfish Core** per roll, editable on `TortugaCatalog` in the Inspector. Payment occurs when the pair is rolled.

Blueprint/weapon ownership, inventory and Forge changes are runtime state. The project still needs its general save system to retain them between launches. Blueprint item resources are available for pickup or drop configuration; their world locations and drop rates are not configured here.

`test/tortuga_test.gd` is no longer in the repository. Check Tortuga by playing `world/biomes/hub/map/room_07.tscn`: greeting, Craft with and without materials, Forge, the choice popup, leaving with Esc or Back, and talking to him again.
