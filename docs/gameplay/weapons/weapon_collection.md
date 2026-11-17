# Weapon blueprint and ownership flags

Open `gameplay/player/foxy.tscn`, select **WeaponController → Weapon Collection → Collection**, then expand **Dagger** or **Bow**:

- **Blueprint Unlocked** grants crafting permission. It does not create, equip or remove an item.
- **Owned** grants an instance to Equipment. Turning it off removes all instances of that weapon ID. If that type is equipped, the controller cancels the current attack and clears equipment safely.
- **Definition** points to immutable WeaponData; **Forge** optionally supplies the granted item's starting forge.

Both flags are independent: a looted weapon can be owned without knowing its recipe. Inventory continues to show owned instances only. The selected weapon's detail footer shows blueprint status.

Foxy starts with Dagger owned, equipped and its blueprint unlocked. Storm Bow, Harpoon and Meteor Staff start unowned with their blueprints locked. Edit checkboxes before running, or edit the controller's per-player collection resources at runtime. Setup copies resources and the collection array, so edits do not alter other players or shared WeaponData.

`default_weapon` is the preferred starting equipment. An explicit unowned collection entry prevents it from granting that weapon. If there is no explicit entry, the old starter behavior is retained. Granting a weapon later does not force equip; the user selects Equip in inventory. Existing `equip(instance)` callers can still grant loot directly, without unlocking its blueprint.

Gameplay APIs after controller setup:

```gdscript
controller.set_blueprint_unlocked(&"dagger", true)
controller.set_weapon_owned(&"dagger", true)
controller.is_blueprint_unlocked(&"dagger")
controller.is_weapon_owned(&"dagger")
```

Setters reject unknown weapon IDs. To configure another weapon, add a WeaponCollectionEntry with a unique definition ID to the scene's Collection array. The `collection_changed` signal updates Equipment immediately. This change supplies initial configuration and runtime state; it does not add a crafting screen or disk save system.

## Blueprint pickups

`data/items/blueprints/` contains item resources for Storm Bow, Harpoon and Meteor Staff.
Each uses `BaseItem.weapon_blueprint` to reference the corresponding `WeaponData` and
can be assigned to an existing item pickup or chest drop. On collection, the pickup
plays the [blueprint discovery presentation](../economy/blueprint_unlock_presentation.md)
for a locked recipe: pause, camera focus, golden drafting VFX, Space confirmation
and absorption. The blueprint is unlocked when the paper reaches the player and takes no
inventory space. It does not grant or equip the weapon; Master Tortuga's Craft tab
then shows the recipe. Repeated pickups are consumed safely and do not grant weapons.
An unknown or unavailable weapon controller leaves the pickup uncollected. Blueprint
state follows the existing player scene-transition state; a general disk save remains
outside the current implementation. Item resources do not themselves specify drop
locations or rates.

Run `test/weapon_collection_test.gd` for the two independent flags, idempotent grants, revoking equipped items, resource isolation and live inventory updates.
