# Captain Blubberbeard

Open `res://world/tests/boss/blubberbeard_test.tscn` to play the standalone encounter.
The main Coral Valley route also leads from Stage 5 through a marked gate to
`res://world/coral_valley/scenes/stages/blubberbeard_room.tscn`. The fight begins when a
player enters `activation_range`. The `fight_started`, `phase_changed` and `fight_finished`
signals are available for other encounter progression.

Edit `res://data/bosses/blubberbeard_data.tres` to tune HP, phase thresholds, skill order,
damage and timing. The `Behavior` node also exposes charge acceleration and recovery
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
`res://assets/sprites/enemies/blubberbeard/blubberbeard_placeholder.png`. The synthesized
impact sound and simple warning/projectile meshes are also placeholders.

`Feedback` exposes `intensity` for screen shake and flash. The charge, roar and explosion
audio clips are synthesized placeholders; the arena's existing AudioManager owns playback.
It also widens the player camera during the fight and restores its original field of view
on defeat or when leaving the scene. Current tuning is 100 HP for the boss, with barrel,
charge and spike damage of 2, 3 and 1.5 against Foxy's default 8 HP; all remain editable.
The built-in image generation tool created
`res://assets/sprites/enemies/blubberbeard/powder_explosion_placeholder.png` with this prompt:
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
