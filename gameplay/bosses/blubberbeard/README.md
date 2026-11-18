# Captain Blubberbeard

Open `res://world/tests/boss/blubberbeard_test.tscn` to play the standalone encounter.
The main Coral Valley route also leads from Stage 5 through a marked gate to
`res://world/coral_valley/scenes/stages/blubberbeard_room.tscn`. The fight begins when a
player enters `activation_range`. The `fight_started`, `phase_changed` and `fight_finished`
signals are available for other encounter progression.

Edit `res://data/bosses/blubberbeard_data.tres` to tune HP, phase thresholds, skill order,
damage and timing. The `CaptainBlubberbeard` root node (`BlubberbeardBoss`) also exposes charge acceleration and recovery
deceleration. The four generated poses are combined with procedural breathing, anticipation,
charge lean and recovery motion; they are not a full frame-by-frame animation set. The
reward chest scene exposes its `rewards` array in the Inspector;
as with the existing treasure chest, attack it to open it. Its default rewards are Ancient
Key of Tides, Coral and Gunpowder Bag. The boss room retains defeat, chest state and
uncollected item pickups across scene changes for the current session; this is not a
disk save. The key is a quest item, and the future Ancient Stone Tablet/map unlock flow
has not yet been implemented.

The artwork is a placeholder created with the built-in image generation tool. Prompt:
"Placeholder sprite sheet for a 3D billboard: Captain Blubberbeard, a large round cursed
pufferfish pirate captain with cream belly, turquoise skin, spines, skull tricorn, red coat,
anchor and gunpowder barrel, in pixel-art style. Four equal cells: idle, barrel throw,
charge, inflated spikes; transparent background." The image is
`res://assets/sprites/bosses/blubberbeard/blubberbeard_placeholder.png`. The synthesized
impact sound and simple warning/projectile meshes are also placeholders.

`Feedback` exposes `intensity` for screen shake and flash. The charge, roar and explosion
audio clips are synthesized placeholders; the arena's existing AudioManager owns playback.
It also widens the player camera during the fight and restores its original field of view
on defeat or when leaving the scene. HP and attack damage remain editable through the
boss data resource.

The enraged spike attack launches eight projectiles on outward parabolic arcs. Their
sprite is `res://assets/sprites/bosses/blubberbeard/enraged_spike.png`, generated with
the built-in image tool using the prompt: "A single large, thick pufferfish spine,
diagonal and pointing upper right, ivory tip, turquoise base, orange accents, bold dark
outline, pixel art, isolated on a transparent background; no text or characters."
The sprite and swept collision follow the same arc in `boss_hazard.gd`.

The first `hits_before_counter` damaging hits outside super-armored attack windows show the
hurt reaction; the next vulnerable hit triggers `COUNTER_SHOCK` recoil followed immediately by
a close-range `SPIKY_INFLATION` burst and prolonged giant spiky hold (`spiky_hold_duration`,
no projectile needles). During active windups, parabolic leap, spiky hold, and
Anchor Whirlwind, `super_armor_during_attacks` keeps attacks uninterruptible while still taking
full damage and hit flash. `hits_before_counter`, `counter_cooldown`, `spiky_hold_duration`, and
`super_armor_during_attacks` are exposed on `CaptainBlubberbeard` (`BlubberbeardBoss`).

Powder barrels show their damage radius on the ground as soon as the throw is prepared;
the indicator intensifies until detonation. The barrels travel more slowly, and the
default barrage throws one to three barrels with a longer gap between throws. Its count
and timing remain configurable in the `Barrel Barrage` properties of each barrel skill
resource.

The eight-frame sheets `deflate_front.png`, `deflate_side.png`, and `deflate_back.png`
in `assets/sprites/bosses/blubberbeard/` cover all four facing directions (the side view
is mirrored). They were generated with the built-in image tool from the existing boss
inflation sheet. Prompt: "Eight sequential pixel-art frames of the pirate pufferfish:
inflated, exhaling, belly collapsing and spines folding, small wrinkled deflated balloon,
airborne, inhaling, reinflating, fully inflated. Preserve the hat and coat; transparent
background; use a consistent front, side or back view for each sheet."
The built-in image generation tool created
`res://assets/sprites/bosses/blubberbeard/powder_explosion_placeholder.png` with this prompt:
"Use case: stylized-concept. Asset type: transparent game VFX spritesheet for a pixel-art
pirate boss's gunpowder barrel explosion. Create exactly four evenly spaced square frames
in a single horizontal row, each centered separately within its equal cell with no overlap,
no panel borders: frame 1 bright compact ignition spark, frame 2 expanding fiery burst
with sharp radial streaks, frame 3 large orange and golden fireball with dark smoke, frame 4
dissipating smoke and embers. Side-on view with detailed crisp pixel-art, dramatic orange
yellow red and soot palette; isolated effects only. Transparent background, no characters,
no text, no watermark." The sprite, light and particles are presentation only; damage
radius and attack timing remain owned by the hazard and skill resources.

See `res://gameplay/bosses/README.md` for the shared boss and behavior extension contract.

## Stage B Combat Kit & AI Rework

- **Position-Aware Dynamic AI & Circling Pacing (`blubberbeard_ai.gd`, `blubberbeard.gd`):** Chooses skills using structured distance + arena-boundary rules (`POSITION_RULES`), per-skill cooldowns, repeat penalties, and weighted randomness:
  - *Close (`<= 4.5m`):* heavily favors `SPIKY_INFLATION` (plus `ANCHOR_WHIRLWIND` / `ANCHOR_SLAM` in open space), never jumps away.
  - *Mid (`4.5–9.5m`):* open space mixes `VENOM_SPIT`, `SKY_DIVE`, `POWDER_BARREL`, and `ANCHOR_WHIRLWIND`; near cliff/wall edges strongly prefers `POWDER_BARREL`.
  - *Far (`> 9.5m`):* open space randomizes across `SKY_DIVE` (parabolic leap), `POWDER_BARREL`, and Phase 2 `VENOM_SPIT`; when the player is near an arena boundary (`ai_boundary_margin = 3.6m`), strictly chooses `POWDER_BARREL` (and keeps barrel spread inside walkable ground) so ground craters and poison puddles do not spawn awkwardly off edges.
  - After each `RECOVERY`, the boss enters a `WAIT` circling stalk window (`1.85s` Phase 1 / `1.25s` Phase 2 with jitter). `max_hp` is balanced to `68.0` (`2.0–4.0` skill damage).
- **Parabolic Leap / Sky Dive (`blubberbeard_skydive.gd`, `blubberbeard_skydive.png`):** Replaces `BELLY_CHARGE`. Blubberbeard squats and launches on a heavy parabolic arc straight onto the player's locked spot (`anchor_whirlwind_props.png` frame `7`), casting a ground shadow below and emitting mid-air afterimages + movement dust puffs along the flight arc (without an initial takeoff smoke burst) before slamming down with a shattered seabed crater AoE (`frame 6`).
- **Proportional Scale, Colliders & Debug Phase 2 (`blubberbeard_size_rig.gd`, `blubberbeard.tscn`, `boss_health_ui.tscn`):** Boss sprite (`pixel_size = 0.017`), `Body` cylinder collider (`1.25m`), contact `ChargeHitBox` (`1.0m`), and AoE damage zones scale dynamically via `boss_size_scale`, Phase 2 enrage (`1.1x`), and `SPIKY_HOLD` (`1.32x`), while `HurtBox` (`1.85m+`) always extends beyond `Body` and `ChargeHitBox` so melee players can fight close safely. In debug builds (`OS.is_debug_build()`), click `Debug: Phase 2 [F8]` in `BossHealthUI` or press `F8` to test Phase 2 directly without dealing attack damage.
- **Spiky Hold & Counter (`blubberbeard.gd`):** Replaces the old balloon flee evade and spike projectiles. Blubberbeard inflates huge (`1.32x`) bristling spines around his body for `spiky_hold_duration` (`~1.2s–1.35s`), dealing an initial radial burst AoE and punishing melee contact while puffed before exhaling. After `hits_before_counter` (`6` in `blubberbeard_room.tscn`, `counter_cooldown = 7.5`), vulnerable hits trigger `COUNTER_SHOCK` followed by an immediate Spiky Hold counter; `super_armor_during_attacks = true` keeps active attacks uninterruptible.
- **Escalating Barrel Barrage (`POWDER_BARREL`):** Throws escalating waves (`1 -> 2 -> 3` in Phase 1, `1 -> 2 -> [3..5]` simultaneous salvo in Phase 2). Initial waves follow the player's current position directly while subsequent/final barrels scatter randomly nearby.
- **Anchor Chain Whirlwind (`anchor_whirlwind_rig.gd`, `blubberbeard_anchor_whirlwind.png`, `anchor_whirlwind_props.png`):** Phase 2 attack telegraphing a cursed compass warning seal before swinging an iron chain + skull anchor + cleave arc `1–2` rotations around Blubberbeard (`tag = &"boss_whirlwind"`).
- **Venom Spit (`blubberbeard_venom_hazard.gd`, `blubberbeard_venom_spit_4dir.png`, `venom_glob_and_puddle.png`):** Phase 2 4-directional venom volley spitting glowing globs that splash into animated bubbling poison puddles (`tag = &"poison"` periodic damage).
- **Locked Room & Collapsing Bridge (`blubberbeard_room.gd`, `blubberbeard_arena.gd`):** Entering `blubberbeard_room.tscn` while Blubberbeard is alive immediately locks `Exits/LeftPath/SceneChangeTrigger`, raises a collapse barrier (`ExitBridge/ExitCollapseBarrier`), and drops the wooden exit bridge (`ExitBridge`) into the sea. Defeating Blubberbeard (`fight_finished`) unlocks the exit and restores the bridge; re-entering the room after defeat keeps the bridge intact. Phase 2 also shifts the room `WorldEnvironment` to a darker storm tone.

## Development Roadmap

For remaining combat/presentation gaps (Boss BGM, replacing synthesized placeholder SFX, and dedicated Phase 2/anchor sprite art) and the full roadmap, see `res://docs/plans/blubberbeard_development_plan.md`.
