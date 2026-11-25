# Coral Valley room layout

Numbering follows the final reference diagram: middle row left to right (`room_00`–`room_08`), then top row (`room_09`–`room_16`), then bottom row (`room_17`–`room_24`). Quiz left/right counts as one room.

![Numbered room and path diagram](coral_valley_layout.svg)

Where and how enemies are placed inside a room follows
[enemy placement](coral_valley_enemy_placement.md); this document decides which enemies each
room has. Wonder rooms (split islands, coloured seas, reef rings) are described in
[wonder rooms](coral_valley_wonder_rooms.md).

Mobs, Raid, Boss, Farm and Checkpoint rooms use Medium layouts; all other room types use Small layouts (11 Medium and 14 Small rooms). Quiz `23` has a fixed center lever and an automatically orbiting platform; Quiz `09` has one two-stop ferry with hidden shore levers; Raid `18` has one shuttle called from shore levers (see Island Raid below); Quiz `04` has a fixed center and an eight-stop orbit platform controlled from both shores.

All 25 map rooms use the clipped-corner Coral Valley ground and convex ground
collision. The paired island rooms are Quiz `room_04`, `room_09`, `room_23` and Raid `room_18`.
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

Island Raid `room_18` (was Quiz) uses `objects/raid_shuttle_platform.tscn`, one
platform that idles at its Center marker (X `27.61`) between the two islands. It has no
lever of its own; two `shuttle_call_lever.tscn` levers sit on the shores (west
`(10.5, 0.21, -7)`, east `(44.5, 0.21, -7)`). Stops: Start X `15.5` (west dock), End X
`38.58` (east dock), speed 3 units/second. Rules and scripts are described in
[Island Raid](#island-raid-room_18).

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
| room_08 | Middle | Boss | Large arena (about 1.6× a Medium island) | left: room_07 |
| room_09 | Top | Quiz (2 islands) | Small, 2 islands | right: room_10, down: room_01 |
| room_10 | Top | Materials | Small | left: room_09, down: room_03 |
| room_11 | Top | Empty | Small | right: room_12, down: room_04 |
| room_12 | Top | Mobs 2 | Medium | left: room_11 |
| room_13 | Top | Mobs 5 | Medium | down: room_05 |
| room_14 | Top | Materials | Small | right: room_15, down: room_06 |
| room_15 | Top | Empty | Small | left: room_14, right: room_16 |
| room_16 | Top | Mobs 6 | Medium | left: room_15 |
| room_17 | Bottom | Empty | Small | right: room_18, up: room_02 |
| room_18 | Bottom | Raid (2 islands, shuttle) | Small, 2 islands | left: room_17 |
| room_19 | Bottom | NPC | Small | right: room_20, up: room_04 |
| room_20 | Bottom | Mobs 3 | Medium | left: room_19 |
| room_21 | Bottom | Empty | Small | right: room_22, up: room_05 |
| room_22 | Bottom | Mobs 4 | Medium | left: room_21, right: room_23 |
| room_23 | Bottom | Quiz (2 islands) | Small, 2 islands | left: room_22, right: room_24 |
| room_24 | Bottom | Farm (wonder: split islands) | Medium | left: room_23 |

Six chest reward locations are configured: Quiz `09` at the left island center; Quiz `04` and `23` at the right island centers, Raid `18` at its right island center (spawned after the raid); Raid `07` at its room center; Boss `08` at the defeated boss position. Quiz `09` guarantees 10–20 gold, one Bow blueprint and one Coral Skeleton note. Raid `18`, Quiz `04` and `23` each guarantee 10–20 gold plus one Starfish, Barrel and Crab note respectively. Raid `07` guarantees 10–20 gold and one Harpoon blueprint, with its chest spawned only after clearing wave 4. Boss `08` uses Blubberbeard's existing reward chest after his death animation. Only the four Quiz chests are present on entry.

Quiz `09` retains four Elite Barrels around its chest at local X/Z `(±5, ±5)`,
forming a square with four 10-unit sides. Quiz `04` and `23` retain only
the two right-side Elite Barrels: TopRight `(5, -5)` and BottomRight `(5, 5)`;
TopLeft and BottomLeft have been removed. Groups remain centered on their chests,
and the remaining guards keep their positions and heights. No new scripts or
changes to loot, puzzle controls, island spacing or paths are introduced.

Raid `room_07` starts when Foxy enters the interior activation area. During combat, `BaseRoom.set_exits_locked(true)` closes the existing player
boundary across the exits and disables their scene-change triggers. The paths
stay visible; no separate barriers or barrier visuals are created.
It reuses the Mobs 4 directional tide layout: left → up → right → down. Each tide
rises, holds, and falls with the existing surge/water interactions. New enemies
appear on exposed ground as it recedes. The next tide starts as soon as all requested enemies have spawned and died,
without a timer or waiting for the outgoing tide to finish receding.
`FlatTideController.finish_cycle()` clears that tide before the next direction starts.

| Raid wave | Total | Normal | Elite | Random enemy pool |
| --- | --- | --- | --- | --- |
| 1 | 3 | 3 | 0 | Starfish, Crab, Coral Skeleton |
| 2 | 4 | 4 | 0 | Starfish, Crab, Coral Skeleton, Barrel |
| 3 | 4 | 3 | 1 | Same four types, corresponding elite variants |
| 4 | 5 | 3 | 2 | Same four types, corresponding elite variants |

Types may repeat. Counts are exact, not probability-based; blocked spawns retry
instead of silently losing an enemy. The last clear leaves the water LOW and
opens both exits. Completion is kept in `GameManager.story_flags` for the current
run, so revisiting does not restart the raid; New Game resets it. After the fourth clear, `RaidEncounter` instantiates `raid_reward_chest.tscn`
at room-local `Vector3(0, 0.25209618, 0.45244434)`. It guarantees 10–20 gold and
one Harpoon blueprint. There is no chest instance before the raid is cleared.
Revisiting a cleared raid creates the configured chest without replaying waves;
once opened it stays open for the run ([room state](../systems/room_state.md)).
`FlatTideController.externally_advanced` defaults to false, preserving automatic
cycles in Mobs rooms. The finite spawner subclasses the existing tide spawner,
whose `_spawn()` now reports success as a boolean without changing its old callers.

Boss `room_08` is a round arena island about 1.6× the size of a Medium island
(`BlubberbeardArenaRoom`, [blubberbeard_arena_room.gd](../../world/biomes/coral_valley/blubberbeard_arena_room.gd)).
Captain Blubberbeard stands at the centre, `Vector3(0, 0.252, 0.452)`, and reuses
`BossEncounter` with the `captain_blubberbeard` encounter ID. A short bridge joins
the left pier to the island. Entering the island's interior locks the exit via
`BaseRoom.set_exits_locked()` and starts the fight; at that moment the bridge
breaks (spans fall into the sea, splash, shake) and its floor is removed, so the
island boundary closes the gap. The bridge never comes back while the boss stays
defeated: Foxy leaves with the Tide Grapple he has just won, using the grapple
posts on both sides of the gap (`GrapplePostIsland`, `GrapplePostPier`). If Foxy
dies, the next visit reloads the room with the bridge whole. The exit reopens on
`fight_finished`; the boss's existing death sequence creates his configured
reward chest at his death position. There is no preplaced chest or extra barrier.
The sea follows the fight through `SeaMood`: calm at first, `violet_glow` from
phase two, and `red_tide` while Sky Dive or Anchor Whirlwind winds up and plays
out, then back. The boss reward scene guarantees 10–20 gold, one Tide Grapple Charm and
one boss note (`Diary of Tide`); the old key/material rewards are removed. Defeat, chest-open state and uncollected reward items are restored
by the existing encounter persistence when returning during the same run.
Tracked reward pickups now retain their `MonsterNote` reference as well as item,
quantity and position, so an uncollected boss diary restores as an actual note.
The optional room/activation-area references default to empty, leaving the old
boss test scene's custom bridge lock unchanged.

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

- `room_10` is the Crab and coconut area: it spawns only leaning, short and tall
  coconut palms, and has three hand-placed Crabs.
- `room_14` is the Starfish and coral area: it spawns only orange, pink and
  turquoise coral, and has three hand-placed Starfish.

`room_10`'s palm candidates keep the north half and the sides clear of the paths;
south of the island centre they sit only on the rim, away from the down path, so a
crown never hides Foxy. `room_14`'s coral candidates stay off the path surface.

"Per visit" below now means per world cycle: random spawns are seeded from the
cycle, so a room keeps the same layout (and remembers killed enemies and broken props)
until the next campfire rest or death reshuffles it. See
[room state](../systems/room_state.md).

Each Materials room uses its existing spawn positions and randomly spawns 5–10 props per visit (`min_spawn_count = 5`, `max_spawn_count = 10`). Each of its three variants has an equal 1/3 chance per spawned prop; all three variants are available, but a visit does not guarantee every variant.

Mobs 1, 2 and 3 (`room_02`, `room_12`, `room_20`) randomly spawn 7–10 props per visit. Each prop has an equal chance to be stone or wood log. Each room has ten spawn positions. In every Mobs room the obstacle candidates sit at least about 4 units off the path axes, so no prop can block an exit; the counts and pools are unchanged.

Mobs 4, 5 and 6 (`room_22`, `room_13`, `room_16`) spawn two independent
groups per visit: `RandomProps` chooses 5–7 props total, each equally likely
to be wood log or shell; `RandomOctopus` chooses 1–3 destructible octopus props.
The groups use ten and five distinct candidate positions respectively, with
at least 3.6 units between groups and 3.3 units from seaweed candidates.
Both use `random_props.gd`; its Inspector count range now starts at 1.

All rooms except Materials and Empty rooms spawn seaweed around their island rims on each visit. Medium rooms spawn 20 seaweed, except where hand-placed props need part of the 30-point prop budget of the [art direction](../art/coral_valley_art_direction.md): the six Mobs rooms spawn 14, Checkpoint 2 spawns 8, and Checkpoint `room_00` has 6 hand-placed seaweed instead of a spawner. Small rooms spawn 15 per island. The two Materials rooms (`room_10`, `room_14`) have no seaweed spawner.

| Layout | Rooms | Seaweed per visit |
| --- | --- | --- |
| Medium | `room_07` | 20 per room |
| Boss arena | `room_08` | 16, from 27 candidates along the arena rim, plus 8 from 12 candidates inside the arena (`ArenaSeaweed`) |
| Medium, split islands | `room_24` | 12, from 29 candidates along the island rims |
| Medium, Checkpoint | `room_00` (hand-placed), `room_05` | 6 and 8 |
| Medium, Mobs | `room_02`, `room_12`, `room_13`, `room_16`, `room_20`, `room_22` | 14 per room |
| Small, one island | `room_19` | 15 per room |
| Small, two islands | `room_04`, `room_09`, `room_18`, `room_23` | 10 on each island, 20 per room (was 15; lowered for the 30-point prop budget and each room's landmark) |

In `room_08` both seaweed spawners set `props_receive_enemy_attacks`, so Blubberbeard's attacks (charge, slam, whirlwind, barrels, venom) break seaweed as well as Foxy's. The inner candidates sit 11.5 and 15.5 units from the arena centre and leave the western entrance from the bridge clear. Boss shake and flash play only when an attack hits Foxy.

Each island has its own `RandomSeaweed` spawner using the existing `random_props.gd`, with candidate positions fitted to its actual ground collision shape and scale. Positions are selected without replacement and inset 3–4.5 world units from the ground collision outline, with gaps at open entrances and former dock locations and at least 2.8 units of clearance from existing prop spawn positions. Mobs 1–3 retain their approved rim positions. Each seaweed independently chooses `seaweed_1`, `seaweed_2` or `seaweed_3` with equal probability.

Empty rooms `01`, `03`, `06`, `11`, `15`, `17` and `21` choose exactly one
population layout per visit, with equal 50% probabilities. `RandomEmptyType`
uses `random_props.gd` to instantiate one of two PackedScenes at the origin;
only the selected branch's populations exist. The previous simultaneous groups,
fixed enemies, Scenery and old seaweed configuration are removed. Floor artwork,
water/atmosphere, camera and exit wiring remain unchanged.

| Empty layout | Enemies | Before Checkpoint 2 | After Checkpoint 2 |
| --- | --- | --- | --- |
| Combat / obstacles | Exactly 4, each 10% elite | 5–7 stone/wood props total | 5–7 shell/wood props total |
| Resources only | None | 5–7 coconut palms total + 6 seaweed | 5–7 coral props total + 10 seaweed |

Before Checkpoint 2 means rooms `01`, `03`, `11`, `17`; after it means `06`,
`15`, `21`. Combat picks Starfish, Crab, Coral Skeleton and Barrel equally;
types may repeat. Each type contributes nine normal slots and one elite slot
to the weighted pool, giving every enemy an independent 10% elite probability.
Resource-only layouts use three palm or coral variants with equal probability.
Seaweed was 23 (the Small-room baseline 15 × 1.5); it is now 6 before
Checkpoint 2 and 10 after it, so the palms or coral, each room's fixed palms and
its landmark fit the 30-point prop budget of the
[art direction](../art/coral_valley_art_direction.md). The rooms before
Checkpoint 2 always keep two fixed palms, so they read as a palm grove even when
the combat layout is picked. It is selected without
replacement from 31 candidates on the actual ground polygon, inset 2.5 units with
gaps at the four approaches. Resource plants use a separate interior candidate set;
combat enemies and obstacles also have separate sets. Obstacle, palm and coral
candidates stay at least about 4 units off the path axes so no exit is blocked, and
palm candidates sit only in the north half and on the sides, where their crowns
cannot hide Foxy. Each Empty room also has a fixed landmark of its own in its
`Scenery` node (see the art direction's landmark table); it is not part of the
shared layouts.

The four reusable layout scenes are `objects/empty_combat_before_checkpoint.tscn`,
`empty_combat_after_checkpoint.tscn`, `empty_resources_before_checkpoint.tscn`
and `empty_resources_after_checkpoint.tscn`. All selection and population groups
reuse `random_props.gd`; no GDScript changes are required. Counts refer to
objects, not material quantities dropped. Materials and Mobs keep their own pools.

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

## Island Raid (`room_18`)

Raid with two islands and a shuttle, built on the shared raid system
([docs/systems/raid_room.md](../systems/raid_room.md), `world/gimmick/raid/`). Nodes live
under `IslandRaid` in the room scene. Only the shuttle and lever logic is room-specific
(`world/gimmick/island_raid/`).

| Step | What happens |
| --- | --- |
| 1 | Foxy walks about 7 units in from the west pier and stays inside the `WestStage` entry area for `activation_dwell_seconds` (0.25 s). The dwell stops the fight starting during a room arrival, when Foxy appears briefly at the origin before being moved to the door. Boulders (`BoulderGate`) rise over the west pier and `BaseRoom.set_exits_locked(true)` shuts the exit. |
| 2 | Two scripted waves rise out of the ground (W1 and W2 in the wave table below). |
| 3 | When the last enemy is gone the boulders sink, the exit opens and `WestLever` rises out of the ground. |
| 4 | Striking the lever calls the platform from Center to the west dock. Once Foxy has stood on it for 0.5 s it carries him to the east dock, waits until he steps off, then returns to Center. Both levers ignore hits during the whole trip. If nobody boards within 8 s it returns to Center. |
| 5 | Stepping onto the east island starts `EastStage` and its three scripted waves (E1 to E3). There is no way back until it is cleared. |
| 6 | `EastLever` rises and the reward chest (`island_raid_reward_chest.tscn`: Starfish note) appears at the island centre. Striking the lever brings the shuttle back to the east dock and carries Foxy west. |

Waves are planned, not random. Each `RaidSpawnSpec` names an enemy, whether it is an
elite, an anchor (Foxy or the island centre), an offset (x east, y south, in metres) and a
delay. A wave opens with a ground rumble of `lead_in_seconds`.

| Wave | Intent | Enemies (anchor, offset, delay) |
| --- | --- | --- |
| W1 Ambush | Teaches that the island attacks from the ground: a triangle around Foxy. | Starfish (Foxy, 0/−5, 0 s), Crab (Foxy, −4.5/3, 0.35 s), Coral Skeleton (Foxy, 4.5/3, 0.7 s). |
| W2 Blockade | Barrels fire from the shuttle-side corners, a crab pushes from behind, an elite blocks the way to the shuttle. | Barrel (centre, 8/−8, 0 s), Barrel (centre, 8/8, 0.3 s), Crab (Foxy, −5/0, 0.8 s), **Elite Crab** (centre, 7/0, 1.6 s). |
| E1 Pincer | Closes both sides: crabs north, then starfish south. | Crab ×2 (Foxy, ∓2/−5, 0 s and 0.15 s), Starfish ×2 (Foxy, ∓2/5, 0.7 s and 0.85 s). |
| E2 Firing line | Three barrels top to bottom along the far east edge; a skeleton keeps Foxy moving. | Barrel ×3 (centre, 8/−7, 8/0, 8/7; 0, 0.3, 0.6 s), Coral Skeleton (Foxy, 0/5, 1.2 s). |
| E3 Finale | Long rumble (1.6 s), two elites at the centre, then their escort surrounds Foxy. | **Elite Coral Skeleton** (centre, −3/0, 0 s), **Elite Starfish** (centre, 3/0, 0.5 s), Crab, Coral Skeleton, Starfish (Foxy triangle, 2.0 to 2.6 s). |

The spawn sequence (crack, eruption, emerging enemy) is described in the shared raid doc.

Room configuration:

- `WestStage` (`locks_room = true`) and `EastStage` (`locks_room = false`, since the exits
  are on the west side) each have their own `RaidGroundSpawner`.
- `Lockdown` (`RaidLockdown`) locks the exits and raises `BoulderGate` during the west fight.
  It spawns the reward chest once both islands are cleared.
- `IslandRaidConductor` raises each island's shuttle lever when that island is cleared.
- `ShuttleDirector` runs the platform trips; `MovingPlatform` gained `request_center()`,
  `center_reached` and `is_traveling()` for it. `ShuttleCallLever` only emits `called`.
- Progress is kept in `GameManager.story_flags` (`coral_valley_room_18_west_cleared`,
  `coral_valley_room_18_east_cleared`), so it is saved with the run and a cleared island
  never fights again. Re-entering restores the earned levers and the chest. Dying mid-fight
  restarts that island's waves. The platform and levers reset when the room is entered.
- The two static Elite Barrels that guarded the chest were removed.
