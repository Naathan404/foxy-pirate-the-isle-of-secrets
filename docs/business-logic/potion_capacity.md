# Potion carrying capacity

`Inventory` owns the limit: by default, 3 health bottles, 3 stamina bottles,
and 3 dual essence bottles (an independent `Potion.Kind.DUAL_ESSENCE` group).
Small and large bottles count together within their `Potion.Kind`. Each distinct
kind/size uses its own item ID and stacks separately (up to `max_stack = 99`).
`Potion.potion_size` describes size; it does not multiply carrying cost.

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
inventory.count_potions(Potion.Kind.HEALTH)
inventory.get_potion_capacity(Potion.Kind.HEALTH)
inventory.upgrade_potion_capacity(Potion.Kind.HEALTH) # +1, returns success
inventory.upgrade_potion_capacity(Potion.Kind.STAMINA, 2)
inventory.set_potion_capacity(Potion.Kind.HEALTH, 5) # restore progression
```

Upgrades are independent per kind. Invalid kinds, nonpositive upgrades, limits
above 100000, and reductions below currently carried quantities are rejected.
Successful capacity changes emit `potion_capacity_changed(kind, new_capacity)`
and `changed`. `clear()` removes items but keeps upgraded capacities.

Capacity belongs to the inventory instance. Saving progression across player
recreation/game restarts and charging an NPC upgrade price are future integrations.
Restore capacities before adding saved items. These methods do not spend Gold.
Do not modify `slots` directly when adding items; use the inventory API.
