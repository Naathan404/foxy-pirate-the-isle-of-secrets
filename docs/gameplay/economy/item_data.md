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
