# Player attraction

`player_attraction.tscn` is a reusable movement component composed into both
item and Gold pickup scenes. It does not reference Inventory, GoldWallet or
the concrete Player class. Owners provide an eligibility Callable and commit
their own reward when `arrived(target)` fires.

## Scene references and tuning

The `Attraction` node exports:

- `detector`: the existing pickup Area3D; its mask selects candidate bodies.
- `moving_root`: the Node3D to pull toward the target.
- `anchor`: the visual point that should reach the player's chest.
- `detection_shape`: a CollisionShape3D. Sphere shapes are duplicated once per
  instance before applying `attraction_radius`, default 2.4 units.
- `target_group`: defaults to `player`; other collector groups can reuse it.
- `initial_speed`, `max_speed`, `acceleration`: pull motion, default 4 / 18 / 55.
- `target_offset`: default (0, 0.8, 0), relative to the live target position.
- `arrival_distance`, `scan_interval`, `capture_seconds`: arrival tolerance,
  candidate scan interval and the final shrink animation.

Line of sight uses the configured obstacle mask (WORLD by default). Idle
candidate scans are throttled. During attraction, the destination follows the
target every physics tick. The visual anchor is accounted for so different
sprite heights arrive at the same chest position.

## Owner contract

1. Call `configure(can_attract)` once. The predicate checks business conditions
   such as a living, unblocked player and inventory or wallet capacity.
2. Call `set_enabled(true)` when the object is ready, after its scatter/landing.
3. On `attraction_started`, stop idle visual motion so it cannot compete with pulling.
4. On `arrived`, reserve and grant the reward exactly once. Call `complete()`
   on success, or `retry()` if the reward was rejected or only partly accepted.
5. `complete()` stops detection and shrinks the anchor without allocating a tween.
   On `completed`, the owner frees the pickup or returns it to a pool.
6. `retry()` restores the original grounded transform and emits
   `attraction_cancelled`; the owner resumes its idle visuals.
7. Call `reset()` before reusing or parking a pooled object. It clears targets,
   capture state and restores anchor scale, while disabling processing/detection.

Item pickups remain on the ground if the inventory is full. Partial acceptance
updates the remaining quantity and returns that remainder to its original
position. Capacity is checked again while pulling and at arrival, so competing
pickups cannot destroy items when the last slot fills.

Gold is credited when its coin reaches the player, then the coin shrinks and
returns to GoldPickupPool. Pooled coins retain the existing allocation/activation
budgets. A dead, removed or blocked target cancels an unpaid pull; a completed
reward finishes its visual cleanup even if its target is later removed.

To add another attractable object, compose this component with its own detector,
root and anchor, provide its predicate, and connect `arrived` / `completed` to
that object's reward and lifecycle handling.
