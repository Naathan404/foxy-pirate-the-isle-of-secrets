# Item data contract

Items are authored as `.tres` resources under `data/items/` and are referenced
directly by inventories, enemy drops, weapons and merchant catalogs.

- Every item has a unique, non-empty `item_id`, icon, display name, description
  and positive `max_stack`.
- Potions use a `Potion` subclass, `CONSUMABLE` type and positive effect values.
- Each merchant offer has a unique `offer_id`. Multiple buy offers can reference
  the same item (for example, single arrows and a five-arrow bundle), but only
  one offer per item may have a positive `sell_price`.
- Current enemy drops are merchant sell offers. Add a sell offer when adding a
  new enemy drop intended for Silas.

Run `test/item_data_test.gd` after changing item, weapon, enemy-drop or Silas
catalog data. The test intentionally does not require every item to be used:
future content may be authored before it has a consumer.

Charm pickups are authored under `data/items/charms/`, one per Charm in
`gameplay/charms/charm_data/`. All 25 are currently playable and can be collected.
Each item references its `CharmData` through `BaseItem.charm` and may be used by
existing item pickup and chest drop flows. Collecting it starts the Charm unlock presentation and grants ownership through
the player's registry at absorption, without using an inventory slot. Already-owned
Charm pickups are removed when encountered. A chest whose guaranteed drop (`chance = 1`) is a
Charm lays it out again on each visit while Foxy does not own it. Missing or unavailable Charm definitions
leave the pickup in the world; prototype and disabled Charms cannot be granted through
this flow. See `charm_unlock_presentation.md` for the sequence. Ownership follows the existing Charm progression
and scene-transition mechanisms.
