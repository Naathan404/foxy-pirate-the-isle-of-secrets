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

The first `hits_before_evade` damaging hits show the hurt animation; the next hit makes
Blubberbeard exhale at the starting position, fly away in a small wrinkled balloon-like
form with a steam trail, and then stop and inhale to reinflate. The triggering hit deals
damage; he is immune through the entire defense. The counter resets when an evade starts.
Hits during the cooldown count toward the next evade, which can start on a subsequent hit
after the cooldown. `hits_before_evade` (default 2), `evade_speed` and `evade_cooldown`
are exposed on the `CaptainBlubberbeard` root node (`BlubberbeardBoss`). `evade_speed` is the initial horizontal launch speed;
air drag slows the boss, ground contact causes a small bounce and friction, and wall
collisions reflect the motion with reduced speed.

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

## Combat Upgrades & Collapsed Exit Bridge

- **Stats & Combat (`blubberbeard_data.tres`, `blubberbeard.gd`):** `max_hp` is tuned to `120.0` with faster movement (`move_speed = 5.2`), quicker charges (`13.5` Phase 1 / `18.0` Phase 2) with early-windup aim tracking and wall-impact AoE shockwaves, distance-weighted `smart_skill_selection`, lead-aimed `POWDER_BARREL` volleys, a close-range AoE burst + Phase 2 staggered second wave on `SPIKY_INFLATION`, a close-range `Anchor Slam` attack (`anchor_slam_*` exports) with ground telegraph, and `evade_drops_barrels` counter-traps. In `blubberbeard_room.tscn`, `hits_before_evade` is set to `5` (`evade_cooldown = 5.0`).
- **Locked Room & Collapsing Bridge (`blubberbeard_room.gd`, `blubberbeard_arena.gd`):** Entering `blubberbeard_room.tscn` while Blubberbeard is alive immediately locks `Exits/LeftPath/SceneChangeTrigger`, raises a collapse barrier (`ExitBridge/ExitCollapseBarrier`), and drops the wooden exit bridge (`ExitBridge`) into the sea. Defeating Blubberbeard (`fight_finished`) unlocks the exit and restores the bridge; re-entering the room after defeat keeps the bridge intact. Phase 2 also shifts the room `WorldEnvironment` to a darker storm tone.

## Development Roadmap

For remaining combat/presentation gaps (Boss BGM, replacing synthesized placeholder SFX, and dedicated Phase 2/anchor sprite art) and the full roadmap, see `res://docs/plans/blubberbeard_development_plan.md`.
