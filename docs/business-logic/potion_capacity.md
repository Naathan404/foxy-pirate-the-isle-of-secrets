# Potion carrying capacity

`Inventory` owns one carrying limit per `Potion.Kind`, defaulting to 3 each for
HP, SP, and Dual Essence. Small and large bottles count together: 2 small HP +
1 large HP fills the HP limit, without affecting SP or Dual Essence capacity.
Each kind/size combination keeps its own item ID and separate stack, up to its
resource's `max_stack`. Carrying limits do not merge stacks.

All additions use `Inventory.add_item()`, which returns unaccepted quantities.
`get_available_space()` and `can_add_item()` include both inventory space and the
potion limit. The existing pickup attraction therefore leaves full-kind potions
on the ground, retries after space becomes available, and supports partial pickup.
Starting items also respect the limit. Moving stacks does not change carried totals.
The player scene starts with 2 small + 1 large bottle for health and stamina.

Dual Essence restores both HP and SP in one use. Small restores 2 HP / 200 SP;
large restores 5 HP / 500 SP, as configured in their resources. Both components
are required. A living player can consume it if either bar gains anything; when
both bars are full, no bottle is consumed. Each bar clamps to its own maximum.
Dual Essence uses the same capacity/upgrade API; its two sizes stack separately
with the resource's configured `max_stack` (currently 10).

Progression API on `Inventory`:

```gdscript
inventory.count_potions(Potion.Kind.HEALTH) # total small + large HP
inventory.get_potion_capacity(Potion.Kind.HEALTH)
inventory.upgrade_potion_capacity(Potion.Kind.HEALTH) # shared HP limit +1
inventory.upgrade_potion_capacity(Potion.Kind.STAMINA, 2)
inventory.set_potion_capacity(Potion.Kind.HEALTH, 5) # restore progression
```

Upgrades are independent per kind and apply to both sizes. Invalid kinds, nonpositive upgrades, limits
above 100000, and reductions below currently carried quantities are rejected.
Successful capacity changes emit `potion_capacity_changed(kind, new_capacity)`
and `changed`. `clear()` removes items but keeps upgraded capacities.

Capacity belongs to the inventory instance. Saving progression across player
recreation/game restarts and charging an NPC upgrade price are future integrations.
Restore capacities before adding saved items. These methods do not spend Gold.
Do not modify `slots` directly when adding items; use the inventory API.
