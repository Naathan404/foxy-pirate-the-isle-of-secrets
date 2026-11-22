# Coral Valley room layout

Numbering follows the reference diagram: middle row left to right, then top row, then bottom row.

Mobs, Raid, Chest, Boss, Farm and Checkpoint rooms use Medium layouts; all other room types use Small layouts (12 Medium and 14 Small rooms). Two-island rooms keep both islands and their moving-platform connections.

| Room | Row | Type | Layout | Exits |
| --- | --- | --- | --- | --- |
| room_00 | Middle | Checkpoint | Medium | right: room_01, left: Hub room_04 |
| room_01 | Middle | Empty | Small | left: room_00, right: room_02, up: room_09 |
| room_02 | Middle | Mobs 1 | Medium | left: room_01, right: room_03, down: room_17 |
| room_03 | Middle | Empty | Small | left: room_02, right: room_04, up: room_10 |
| room_04 | Middle | Quiz (2 islands) | Small, 2 islands | left: room_03, right: room_05, up: room_11, down: room_20 |
| room_05 | Middle | Checkpoint 2 | Medium | left: room_04, right: room_06, up: room_13, down: room_22 |
| room_06 | Middle | Empty | Small | left: room_05, right: room_07, up: room_14 |
| room_07 | Middle | Raid | Medium | left: room_06, right: room_08 |
| room_08 | Middle | Boss | Medium | left: room_07 |
| room_09 | Top | Empty (2 islands) | Small, 2 islands | right: room_10, down: room_01 |
| room_10 | Top | Materials | Small | left: room_09, down: room_03 |
| room_11 | Top | Empty | Small | right: room_12, down: room_04 |
| room_12 | Top | Mobs 2 | Medium | left: room_11 |
| room_13 | Top | Mobs 5 | Medium | down: room_05 |
| room_14 | Top | Materials | Small | right: room_15, down: room_06 |
| room_15 | Top | Empty | Small | left: room_14, right: room_16 |
| room_16 | Top | Mobs 6 | Medium | left: room_15 |
| room_17 | Bottom | Empty | Small | right: room_18, up: room_02 |
| room_18 | Bottom | Quiz | Small | left: room_17, right: room_19 |
| room_19 | Bottom | Chest | Medium | left: room_18 |
| room_20 | Bottom | NPC | Small | right: room_21, up: room_04 |
| room_21 | Bottom | Mobs 3 | Medium | left: room_20 |
| room_22 | Bottom | Empty | Small | right: room_23, up: room_05 |
| room_23 | Bottom | Mobs 4 | Medium | left: room_22, right: room_24 |
| room_24 | Bottom | Quiz (2 islands) | Small, 2 islands | left: room_23, right: room_25 |
| room_25 | Bottom | Farm | Medium | left: room_24 |

## Existing scene renumbering

00 -> 00, 01 -> 01, 02 -> 02, 03 -> 03, 04 -> 04, 05 -> 05, 06 -> 09, 07 -> 10, 08 -> 11, 09 -> 12, 10 -> 17, 11 -> 18, 12 -> 19, 13 -> 20, 14 -> 21

The 15 existing scenes keep their authored contents and scene UIDs. New materials, mobs, empty and two-island quiz rooms reuse their existing counterparts. Raid, Boss and Farm instantiate their room templates; their gameplay encounters are not authored by this layout change. Ground artwork is unchanged.

## Random destructible props

The two Materials rooms use the Small room template, with spawn positions pulled inward to fit the smaller ground, and have separate resource pools:

- The left Materials room (`room_10`) spawns only orange, pink and turquoise coral.
- The right Materials room (`room_14`) spawns only leaning, short and tall coconut palms.

Each Materials room uses its existing spawn positions and randomly spawns 5–10 props per visit (`min_spawn_count = 5`, `max_spawn_count = 10`). Each of its three variants has an equal 1/3 chance per spawned prop; all three variants are available, but a visit does not guarantee every variant.

Mobs 1, 2 and 3 (`room_02`, `room_12`, `room_21`) randomly spawn 7–10 props per visit. Each prop has an equal chance to be stone or wood log. Each room has ten spawn positions.

Mobs 4, 5 and 6 (`room_23`, `room_13`, `room_16`) spawn two independent
groups per visit: `RandomProps` chooses 5–7 props total, each equally likely
to be wood log or shell; `RandomOctopus` chooses 1–3 destructible octopus props.
The groups use ten and five distinct candidate positions respectively, with
at least 3.6 units between groups and 3.3 units from seaweed candidates.
Both use `random_props.gd`; its Inspector count range now starts at 1.

All non-Materials rooms spawn seaweed around their island rims on each visit. Medium rooms spawn 20 seaweed; Small rooms spawn 15 per island. The two Materials rooms (`room_10`, `room_14`) have no seaweed spawner.

| Layout | Rooms | Seaweed per visit |
| --- | --- | --- |
| Medium | `room_00`, `room_02`, `room_05`, `room_07`, `room_08`, `room_12`, `room_13`, `room_16`, `room_19`, `room_21`, `room_23`, `room_25` | 20 per room |
| Small, one island | `room_01`, `room_03`, `room_06`, `room_11`, `room_15`, `room_17`, `room_18`, `room_20`, `room_22` | 15 per room |
| Small, two islands | `room_04`, `room_09`, `room_24` | 15 on each island, 30 per room |

Each island has its own `RandomSeaweed` spawner using the existing `random_props.gd`, with candidate positions fitted to its actual ground collision shape and scale. Positions are selected without replacement and inset 3–4.5 world units from the ground collision outline, with gaps at open entrances and moving-platform docks and at least 2.8 units of clearance from existing prop spawn positions. Mobs 1–3 retain their approved rim positions. Each seaweed independently chooses `seaweed_1`, `seaweed_2` or `seaweed_3` with equal probability.

Coral and coconut palms do not appear in any other Coral Valley room. The old
mixed shell, stone and octopus pool is no longer used by any room, including
the removed unused spawner in `room_00`. Only Materials and Mobs rooms use
the explicit prop pools described above. Seaweed spawners retain their
existing setup.

## Tide enemy pools

The Small, Medium and Large Coral Valley base scenes enable
`Enemy Boundary Enabled` under Ground boundaries.
The existing floor-boundary builder generates `EnemyGroundBoundaries` from
island floors only, keeping the outline closed across all four path entrances
and player-only openings. Enemy bodies and their forward obstacle rays use
the `EnemyBoundary` layer; player movement and attacks ignore it. Player
boundaries keep their existing open-path behavior. Rooms outside these Coral
Valley templates retain the default disabled setting.

All six Mobs rooms inherit the same CameraBounds from `base_medium_room.tscn`.
Mobs 1–3 use two mirrored `Vector2(45, 66)` water zones, running
`LeftShallows` → `RightShallows`. Mobs 4–6 (`room_23`, `room_13`, `room_16`)
run clockwise: `LeftShallows` → `UpShallows` → `RightShallows` →
`DownShallows`. The added upper/lower zones use `Vector2(78, 45)` to span
the room's width while keeping the same 45-unit travel depth.
Each zone rises for 6 seconds, stays high for 6, falls for 6 and rests for 6
before the next zone starts. A full cycle takes 48 seconds for Mobs 1–3
or 96 seconds for Mobs 4–6. Timing is configured under `Cycle Timing`;
the controller's `Zones` array controls order. Only one zone floods at a time.

Mobs 1–3 select up to three enemies per falling tide. Each enemy independently
chooses either entry in its room's pool with equal probability; a wave can contain
three of the same type. All three spawners use `elite_chance = 10.0`, and only
the Coral Skeleton entry has an elite scene assigned. A selected skeleton has
a 10% chance to use its elite variant; starfish, barrel and crab remain normal.

Mobs 4–6 each select up to three enemies of a single species per falling tide.
Each enemy independently has a 10% chance to use that species' elite variant.
These three rooms have no skeleton entries.

| Room | Type | Tide enemy pool |
| --- | --- | --- |
| `room_02` | Mobs 1 | Starfish, Coral Skeleton |
| `room_12` | Mobs 2 | Barrel, Coral Skeleton |
| `room_21` | Mobs 3 | Crab, Coral Skeleton |
| `room_23` | Mobs 4 | Barrel (normal or elite) |
| `room_13` | Mobs 5 | Starfish (normal or elite) |
| `room_16` | Mobs 6 | Crab (normal or elite) |
