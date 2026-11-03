# Item data contract

Items are authored as `.tres` resources under `data/items/` and are referenced
directly by inventories, enemy drops, weapons and merchant catalogs.

- Every item has a unique, non-empty `item_id`, icon, display name, description
  and positive `max_stack`.
- Potions use a `Potion` subclass, `CONSUMABLE` type and positive effect values.
- A merchant offer uses the same ID as its referenced item or weapon. One
  catalog cannot list a resource twice.
- Current enemy drops are merchant sell offers. Add a sell offer when adding a
  new enemy drop intended for Silas.

Run `test/item_data_test.gd` after changing item, weapon, enemy-drop or Silas
catalog data. The test intentionally does not require every item to be used:
future content may be authored before it has a consumer.
