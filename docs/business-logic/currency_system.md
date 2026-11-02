# Gold

Gold is the shared currency for the economy described in the GDD. The current
implementation covers enemy drops, collection, the runtime wallet and HUD.

## Enemy rewards

| Enemy | Drop chance | Gold per successful drop |
| --- | --- | --- |
| Regular enemy | 40% | 5 |
| Elite crab, starfish and barrel | 100% | 20 |

`EnemyData` exposes `Gold Drop / Gold Amount` and `Gold Drop Chance`. The elite
data resources override the regular defaults. War Lord Turtle has Gold Amount
set to zero until a separate boss reward is specified.

Gold and the existing material drop roll independently. Gold rolls once per death:
a successful roll requests exactly `gold_amount` separate coins, each worth 1G.
A regular reward scatters 5 coins; an elite scatters 20. The scene-local
`GoldPickupPool` supplies these coins and assigns separated radial directions.
The guarded `EnemyBase.die()` schedules the reward once. Hiding an enemy during
a tide change does not count as a death.

## Collection and wallet

The coin scatters along a short arc, then becomes collectible when the player walks within its
pickup area. Dead players and blocked gameplay cannot collect it. Collection
credits Gold once, shows a HUD gain and animates the coin toward the player.

`GameManager.gold_wallet` owns the sole balance. `GoldWallet` exposes
`get_balance()`, `add_gold()`, `can_afford()` and `try_spend()`, with
`balance_changed(balance, change)` for UI. Invalid amounts, insufficient funds
and integer overflow cannot change the balance.

The wallet starts at zero and persists across scene transitions and reloads
within the same running game. This does not introduce a save file or a death
penalty. Shop, selling loot, chest rewards and Charm purchase integration remain
separate callers to connect to this wallet.

## Presentation

- `assets/sprites/items/Coin.png` supplies the artwork. `coin_icon.tres` crops
  its transparent margins for both the world pickup and HUD without editing PNG.
- `gold_pickup.tscn` owns the sprite, reward label and pickup radius.
  `Show Value Label` defaults to false so 20 single-coin labels do not overlap.
- `gold_display.tscn` is instanced beside the player's stat HUD. It observes
  the wallet and combines rapidly collected rewards into one temporary `+G` label.

## Loot scatter and pooled trails

Item and Gold pickup scenes both compose `PickupScatter`. Enemy drops choose
separated radial directions using the golden angle; flight moves the pickup area
with its sprite. Collection stays disabled until landing. The component checks
walls and floor height before choosing a destination, shortening the throw or
staying at the origin if no nearby landing is safe.

`Scatter` exposes distance min/max, trail color/width and an optional trail pool.
Item flight height and duration still use its existing drop animation exports.
Gold uses its `drop_height` and a 0.46-second flight. Item trails are cyan-white;
Gold trails are golden-white. Trails fade for up to 0.22 seconds after landing.

`LootTrailPool` is local to the world scene and reuses ribbon objects, their
meshes, materials and fixed 32-point buffers. It prewarms 64 trails and grows to
128, creating at most 4 per frame; acquisition never creates a new trail in the
drop path. Saturation skips additional trails without changing rewards. Idle entries
are hidden, have empty meshes and do not process. Each activation has a lease
ID so an old pickup cannot stop a trail that another pickup has acquired.
Removing a pickup ends its emission; changing scene frees the entire scene pool.

Responsibilities stay separate: EnemyBase selects rewards and directions,
pickup roots own collection, PickupScatter owns flight, and the pool/ribbon own
visual lifetime.

## Coin object pool

Enemy setup schedules scene-local coin and trail pool warmup before the first
kill. `GoldPickupPool` prewarms 64 coins, caps total allocation at 256, creates
at most 4 per frame and activates at most 8 per frame. These exports can be
tuned on a `GoldPickupPool` node. A fully warm 20G reward appears over 3 frames.

Each death queues one request containing the original reward, position and
direction, so the enemy may be destroyed before all coins activate. If the pool
is saturated, the request retains its remaining coin count and resumes when
collected coins return. It never drops or silently merges the queued reward.

After collection, a pooled coin is hidden and has its collision and processing
disabled. Reuse restores sprite position, scale, color/alpha, pickup flags and
scatter state; signals are connected once. Manually placed standalone pickups
retain their normal drop/collection behavior. All coins and pending requests
belong to their world scene and are released when that scene is removed.
