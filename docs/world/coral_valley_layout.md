# Coral Valley room layout

Numbering follows the final reference diagram: middle row left to right (`room_00`–`room_08`), then top row (`room_09`–`room_16`), then bottom row (`room_17`–`room_24`). Quiz left/right counts as one room.

![Numbered room and path diagram](coral_valley_layout.svg)

Mobs, Raid, Boss, Farm and Checkpoint rooms use Medium layouts; all other room types use Small layouts (11 Medium and 14 Small rooms). Quiz `23` has a fixed center lever and an automatically orbiting platform; Quiz `09` has one two-stop ferry with hidden shore levers; Quiz `18` has one lever-operated shuttle; Quiz `04` has a fixed center and an eight-stop orbit platform controlled from both shores.

All 25 map rooms use the clipped-corner Coral Valley ground and convex ground
collision. The four paired Quiz rooms are `room_04`, `room_09`, `room_18` and `room_23`.
Each contains two Small islands, one room root and one shared CameraBounds.
All four Quiz rooms use the Small room template with their own platform layouts.

Spacing uses the visible sprite edges (alpha >= 0.5), rather than the platform's
4-unit collision box. Each platform is rotated 90 degrees around Y, keeping its
surface horizontal. At the existing sprite scale, the rotated visible width along
X is `716 × 0.01 × 0.5 = 3.58` units.

Three platforms create four gaps: island–platform, platform–platform,
platform–platform, platform–island. Each gap is 4 units, giving **16 empty units**
and a total visible island gap of `3 × 3.58 + 4 × 4 = 26.74` units.
The ground artwork spans `1134 × 0.01 × 0.995455 × 2.5 = 28.22114925` units along X,
so the right island center is offset `54.96114925` units. Its paths, seaweed and
shared CameraBounds move with it.

Quiz `room_04` keeps `Platform2` fixed at
`Vector3(27.61284825, -0.03991985, -0.44552031)`. Its other platform begins directly
right of it, and can stop only at eight surrounding markers: **E → SE → S → SW →
W → NW → N → NE**, clockwise. The center is never a moving-platform stop.
Horizontal pitch is 7.58 units; vertical pitch is 9.78 units, preserving 4 units
between the platform sprites. Travel follows neighboring markers around the
perimeter in either direction, without crossing the fixed platform.

Each shore has two attack-operated `platform_puzzle_lever.tscn` instances. All
four target the same `MovingPlatform`. Upper levers request **+3 stops clockwise**;
lower levers request **−2 stops counterclockwise**. Steps wrap modulo eight.
Hits during movement queue their signed steps after the existing travel; turns
remain on the perimeter. No lever is attached to either platform.
The existing `MovingPlatform` script exposes `route_marker_paths` and
`request_route_steps(count)`; `PlatformLever.DestinationMode.ADVANCE_ROUTE` uses
its signed `route_step_count`. Existing endpoint and Quiz 18 center-stop modes
remain supported. Both inward island openings follow the fixed center's Z,
and remain 5.78 units wide.

Quiz `room_09` replaces all three stationary platforms with one `MovingPlatform`
using two-endpoint mode with `start_at_center = true`. It initially rests at
Center (X `27.61284825`); the first hit sends it to the right stop
(X `35.19284825`). Subsequent hits toggle directly between right and left
(X `20.03284825`), passing the center without stopping. Its speed is 6 units/second.
An onboard `platform_puzzle_lever.tscn` instance is a child of the moving body,
so it rides with the platform. It and the two hidden shore levers target the
same `MovingPlatform` in `TOGGLE` mode. The left island's lever sits at its upper-right corner
(`Vector3(9, 0.21008015, -10)`); the right island's lever sits at its upper-left
corner (`Vector3(45.96114925, 0.21008015, -10)`). Each has one hand-placed
`seaweed_3.tscn` instance 0.9 units in front of it, scaled to 1.25, concealing
the lever independently of random seaweed generation. The seaweed retains its
existing destructible behavior. Paths, ground spacing and shared CameraBounds
stay as before. `MovingPlatform.start_at_center` only changes initial placement;
it defaults to false and does not enable intermediate stops.

Quiz `room_18` removes both side platforms and places
`objects/quiz_shuttle_platform.tscn` at the former center position. Its onboard
lever uses the existing attack HurtBox and `MovingPlatform.receive_damage`.
The platform starts at Center. Each valid player hit requests the next stop:
**Left → Center → Right → Center**, repeating even if hit during travel.
The former platform positions remain the stop coordinates: X `20.03284825`,
`27.61284825` and `35.19284825`. Speed is 3 units/second. No shore call levers
are added. The existing two-stop platform behavior remains the default; this
scene enables `center_stop_enabled` and supplies a `Center` marker.

Quiz `room_23` has a fixed center platform at
`Vector3(27.61284825, -0.03991985, 0.55447969)` and one moving platform using
`objects/quiz_orbit_platform.tscn`, the same eight surrounding stops as Quiz 04.
It starts east and automatically loops clockwise at 6 units/second, without
pauses at markers or crossing the center. One attack-operated lever sits on the
fixed center platform; there are no shore or remote-room levers.
On a player hit, `PlatformLever.DestinationMode.TOGGLE_ROUTE_LOOP` calls
`MovingPlatform.toggle_route_motion()`: finish the current edge and stop exactly
at its destination marker. The next hit resumes clockwise travel, alternating
stop/resume on every hit. A hit during a pending stop cancels that stop and keeps
the platform moving. This state resets when the scene is reloaded.
Only Quiz 23 enables `route_autoplay`; Quiz 04
keeps its manual +3/-2 controls. Island spacing, paths and CameraBounds are retained.

Rooms `23`, `09` and `18` open the player boundary at both island edges facing the
platforms using `boundary_openings`: `Rect2(12.7, -2.33552031, 29.58614925, 5.78)`.
The 5.78-unit-wide passage follows the platforms' visible sprite width along Z, centered
at `0.55447969`. Other island edges retain their player boundaries, and enemy
boundaries stay closed. The existing gaps between islands and platforms remain.

External paths attach to the islands shown in the final diagram:

- `room_04`: left, up (Empty `room_11`) and down (NPC `room_19`) on the left
  island; right (Checkpoint 2 `room_05`) on the right island.
- `room_09`: down (Empty `room_01`) and right (Materials `room_10`) on the
  right island.
- `room_18`: left (Empty `room_17`) on the left island; no other external exit.
- `room_23`: left (Mobs 4 `room_22`) on the left island; right (Farm
  `room_24`) on the right island.

| Room | Row | Type | Layout | Exits |
| --- | --- | --- | --- | --- |
| room_00 | Middle | Checkpoint | Medium | right: room_01, left: Hub `castaway_cove` (east gate) |
| room_01 | Middle | Empty | Small | left: room_00, right: room_02, up: room_09 |
| room_02 | Middle | Mobs 1 | Medium | left: room_01, right: room_03, down: room_17 |
| room_03 | Middle | Empty | Small | left: room_02, right: room_04, up: room_10 |
| room_04 | Middle | Quiz (2 islands) | Small, 2 islands | left: room_03, right: room_05, up: room_11, down: room_19 |
| room_05 | Middle | Checkpoint 2 | Medium | left: room_04, right: room_06, up: room_13, down: room_21 |
| room_06 | Middle | Empty | Small | left: room_05, right: room_07, up: room_14 |
| room_07 | Middle | Raid | Medium | left: room_06, right: room_08 |
| room_08 | Middle | Boss | Medium | left: room_07 |
| room_09 | Top | Quiz (2 islands) | Small, 2 islands | right: room_10, down: room_01 |
| room_10 | Top | Materials | Small | left: room_09, down: room_03 |
| room_11 | Top | Empty | Small | right: room_12, down: room_04 |
| room_12 | Top | Mobs 2 | Medium | left: room_11 |
| room_13 | Top | Mobs 5 | Medium | down: room_05 |
| room_14 | Top | Materials | Small | right: room_15, down: room_06 |
| room_15 | Top | Empty | Small | left: room_14, right: room_16 |
| room_16 | Top | Mobs 6 | Medium | left: room_15 |
| room_17 | Bottom | Empty | Small | right: room_18, up: room_02 |
| room_18 | Bottom | Quiz (2 islands) | Small, 2 islands | left: room_17 |
| room_19 | Bottom | NPC | Small | right: room_20, up: room_04 |
| room_20 | Bottom | Mobs 3 | Medium | left: room_19 |
| room_21 | Bottom | Empty | Small | right: room_22, up: room_05 |
| room_22 | Bottom | Mobs 4 | Medium | left: room_21, right: room_23 |
| room_23 | Bottom | Quiz (2 islands) | Small, 2 islands | left: room_22, right: room_24 |
| room_24 | Bottom | Farm | Medium | left: room_23 |

## Scene identity

The map contains 25 rooms, numbered `room_00`–`room_24`. The former single-island
Quiz `room_18` and Chest `room_19` are replaced by one paired Quiz `room_18`;
the Chest room and its scene transition are removed. Former rooms `20`–`25`
move to `19`–`24` (NPC, Mobs 3, Empty, Mobs 4, paired Quiz, Farm).
Retained scenes keep their authored content and scene UIDs. Every scene root
matches its filename. All path destinations and the Silas room fixture use the
new IDs; the Hub connection through `hub/map/room_04.tscn` stays the same.
Raid, Boss and Farm instantiate their room templates; their gameplay encounters
are not authored by this layout change. Ground artwork is unchanged.

## Random destructible props

The two Materials rooms use the Small room template, with spawn positions pulled inward to fit the smaller ground, and have separate resource pools:

- The left Materials room (`room_10`) spawns only orange, pink and turquoise coral.
- The right Materials room (`room_14`) spawns only leaning, short and tall coconut palms.

Each Materials room uses its existing spawn positions and randomly spawns 5–10 props per visit (`min_spawn_count = 5`, `max_spawn_count = 10`). Each of its three variants has an equal 1/3 chance per spawned prop; all three variants are available, but a visit does not guarantee every variant.

Mobs 1, 2 and 3 (`room_02`, `room_12`, `room_20`) randomly spawn 7–10 props per visit. Each prop has an equal chance to be stone or wood log. Each room has ten spawn positions.

Mobs 4, 5 and 6 (`room_22`, `room_13`, `room_16`) spawn two independent
groups per visit: `RandomProps` chooses 5–7 props total, each equally likely
to be wood log or shell; `RandomOctopus` chooses 1–3 destructible octopus props.
The groups use ten and five distinct candidate positions respectively, with
at least 3.6 units between groups and 3.3 units from seaweed candidates.
Both use `random_props.gd`; its Inspector count range now starts at 1.

All non-Materials rooms spawn seaweed around their island rims on each visit. Medium rooms spawn 20 seaweed; Small rooms spawn 15 per island. The two Materials rooms (`room_10`, `room_14`) have no seaweed spawner.

| Layout | Rooms | Seaweed per visit |
| --- | --- | --- |
| Medium | `room_00`, `room_02`, `room_05`, `room_07`, `room_08`, `room_12`, `room_13`, `room_16`, `room_20`, `room_22`, `room_24` | 20 per room |
| Small, one island | `room_01`, `room_03`, `room_06`, `room_11`, `room_15`, `room_17`, `room_19`, `room_21` | 15 per room |
| Small, two islands | `room_04`, `room_09`, `room_18`, `room_23` | 15 on each island, 30 per room |

Each island has its own `RandomSeaweed` spawner using the existing `random_props.gd`, with candidate positions fitted to its actual ground collision shape and scale. Positions are selected without replacement and inset 3–4.5 world units from the ground collision outline, with gaps at open entrances and former dock locations and at least 2.8 units of clearance from existing prop spawn positions. Mobs 1–3 retain their approved rim positions. Each seaweed independently chooses `seaweed_1`, `seaweed_2` or `seaweed_3` with equal probability.

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
`LeftShallows` → `RightShallows`. Mobs 4–6 (`room_22`, `room_13`, `room_16`)
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
| `room_20` | Mobs 3 | Crab, Coral Skeleton |
| `room_22` | Mobs 4 | Barrel (normal or elite) |
| `room_13` | Mobs 5 | Starfish (normal or elite) |
| `room_16` | Mobs 6 | Crab (normal or elite) |
