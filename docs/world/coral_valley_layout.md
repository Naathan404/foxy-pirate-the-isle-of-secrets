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

Mobs 1, 2 and 3 (`room_02`, `room_12`, `room_21`) also spawn exactly 20 seaweed props per room per visit, selected without replacement from 30 rim positions in each room. Positions are inset 3–4.5 world units from the ground collision outline, with gaps at the left, right and bottom entrances and clearance from each room's stone/wood spawn positions. Each prop independently chooses `seaweed_1`, `seaweed_2` or `seaweed_3` with equal probability.

Coral and coconut palms do not appear in any other Coral Valley room. Remaining rooms keep their existing spawn counts and shell, stone and octopus pools. `RandomProps.include_coral` stays false; the Materials and Mobs 1–3 rooms specify their own `prop_scenes` arrays.
