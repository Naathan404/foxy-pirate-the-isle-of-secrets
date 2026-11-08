# Harpoon prototype

Harpoon is a melee weapon with a narrow forward rectangle and a gold lightning
theme. The prototype is granted in `Foxy/WeaponController.collection`, with
`blueprint_unlocked` and `owned` enabled like the other prototype weapons. It
does not change the default equipped weapon. Production crafting can use the
existing collection flags; no NPC, shop, or crafting implementation is added.

## Controls and initial balance

Equip Harpoon from inventory's equipment tab. LMB performs a thrust in the mouse
direction; RMB requires full CP and starts Lightning Pierce.

| Setting | Thrust | Lightning Pierce |
| --- | --- | --- |
| Damage before forge/critical/charm | 1.25 | 4.0 |
| Startup | 0.09 s | 0.18 s |
| Active | 0.075 s | 0.22 s |
| Recovery | 0.165 s | 0.28 s |
| Range / travel | 2.6 | 5.5 |
| Hitbox width before forge | 0.42 | 0.62 |
| Stagger multiplier | 1 | 2 |

Weapon base stagger is 24; CP gain is 5 per confirmed enemy hit before Forge.
Stats live in `data/weapon/weapon_harpoon.tres` and execution scene exports.
Existing damage, critical, timing, range, melee-hitbox, stagger, CP gain and
secondary skill Forge modifiers apply through `WeaponController` snapshots.

## Pierce lifecycle

1. Startup locks direction and draws a narrow rectangular gold ground telegraph.
   The player is vulnerable and a hit can cancel the attack. Existing secondary
   payment rules apply: full CP is spent when the attack is accepted.
2. Active movement covers the forged distance over the forged active duration.
   Enemy body collision is ignored; world collision remains. Substeps of at most
   0.18 units sample the HitBox, retaining one hit per enemy for the whole pass.
   Incoming damage and direct hit reactions are ignored only during this phase.
3. A wall, missing ground ahead, cancellation or completion ends the movement.
   The original collision mask and horizontal velocity are restored, invulnerability
   ends, and ordinary recovery follows. Scene teardown also releases these changes.

Thrust and pierce check world occlusion before applying damage. VFX reuse existing
hit feedback with a gold palette, a finite particle emitter, and a finishing ribbon.
The long skill does not freeze the shooter when it hits an enemy.

## Temporary artwork and replacement

- Character sheet: `assets/sprites/foxy/harpoon_placeholder/foxy_harpoon_sheet.png`.
- Weapon/skill icon: `assets/sprites/items/equipment/harpoon_placeholder/harpoon.png`.
- Animation library: `gameplay/player/harpoon_animations.tres`.
- Attack scenes: `gameplay/weapons/attack scenes/harpoon_thrust.tscn` and
  `harpoon_pierce.tscn`, with their matching scripts.
- VFX: `gameplay/weapons/harpoon_thrust_vfx.tscn`, `.gd`, and `harpoon_lane.gdshader`.

Both raster assets were generated with the built-in imagegen tool using the
existing Foxy bow sheet as a character/style reference for the character sheet.
The delivered character sheet is 1254 x 1254 with transparent alpha. Generated
spacing is uneven, so AtlasTexture regions and margins align each pose inside a
448 x 448 virtual frame without editing the source PNG. The back/side/front thrust
poses and side dash poses supply six directional clips in the `harpoon` library.
Left uses the existing side flip. Idle/run continue using the existing Foxy art.

Replace the PNGs and AtlasTexture regions when final art arrives. Keep the clip
names `harpoon/thrust_down`, `_side`, `_up`, and `harpoon/pierce_down`, `_side`,
`_up`. Their normalized animation timeline reserves 0-0.5 for startup, 0.5-0.75
for active, and 0.75-1 for recovery. `AttackData.phase_driven_animation` makes
these poses follow actual forged durations instead of a fixed clip speed.

## Verification

Lint/format and Godot parse checks cover the changed scripts. Existing attack
step, mouse attack, player state, float combat and Charm event regressions passed.
A disposable runtime review outside the project exercised the real Harpoon:

- Thrust hit the near enemy for 1.25 and left the farther enemy untouched.
- Pierce hit two enemies once each for 4.0, traveled 5.5, rejected incoming damage
  during active, and restored collision mask 5 after completion.
- A wall stopped the actor at about 2.90 travel, protected the enemy behind it,
  and restored the mask.
- A startup hit applied damage and cancelled the attack without leaving immunity.
- Missing ground stopped the dash at about 0.92 travel on a short platform.
- Cancelling during active changed the mask from 1 back to 5 and removed immunity.

A temporary Compatibility render also checked the down/side/up extended poses and
their foot alignment. Original PNGs remain untouched by the atlas setup.

No test files or CI entries are added to the project. Final visual feel still
needs gameplay review. The environment reports pre-existing certificate and
asset-case/UID warnings; editor import also reports unavailable user cache/settings.

## Generation prompts

Built-in imagegen, transparent background enabled; the bow sheet is a style
reference, not an edit target. The original sprite assets are preserved.

### Character sheet

```text
Use case: illustration-story. Generate a production-use temporary pixel-art CHARACTER ANIMATION SPRITESHEET for a Godot pirate action game. Use the reference image ONLY as the visual identity/style reference: same small orange fox pirate, white muzzle, navy tricorne with yellow trim and simple white skull, red scarf/jacket, navy pants. Replace the bow entirely with a slender LONG GOLDEN HARPOON, a pointed lightning-shaped spear tip with a tiny backward barb, dark grip. Crisp dark pixel outlines, limited palette, readable shapes, no gradients on the character. This is a NEW asset, do not reproduce the reference's bow poses.
Layout is CRITICAL: square 1024 x 1024 transparent PNG, exactly FOUR equal columns and FOUR equal rows, each cell 256 x 256 pixels, 16 separate sprites total. No grid lines, captions, letters, labels, shadows on a floor, or decorative background. Keep every sprite wholly inside its cell with transparent padding. Same fox body scale in all cells, approximately 128 pixels tall, feet at local y=218, body centered near local x=120. Do not enlarge the fox in action frames. Each row is an animation ordered left to right: 1 anticipation/pull harpoon back, 2 sharp thrust extension, 3 extended thrust follow-through, 4 recover to ready stance.
ROW 1: front/down-facing fox, harpoon thrusts toward bottom of sheet, slightly top-down foreshortening.
ROW 2: RIGHT-facing fox, harpoon points right. Long narrow forward thrust, not swinging or throwing. Keep tip inside local x=246.
ROW 3: back/up-facing fox, harpoon thrusts toward top, back of hat visible.
ROW 4: RIGHT-facing stronger dash-thrust: crouched windup, explosive forward lunge, streamlined extended pose, braking recovery. Tiny gold lightning streak accents only in this row, not obscuring the fox. This row still has feet aligned to the same baseline; actual world movement will be handled by the game.
The weapon stays in both hands, not a bow, not a sword, not a gun. Preserve same outfit and proportions in every frame. Transparent background with genuine alpha. Nothing may straddle cell boundaries.
```

### Weapon icon

```text
Use case: illustration-story. Asset type: transparent pixel-art weapon inventory icon for a pirate action RPG. A SINGLE slender golden HARPOON, diagonal lower-left grip to upper-right point, matching a cheerful dark-outlined pixel-art pirate game. Long dark navy/brown grip and shaft, bright golden metal bindings, narrow spearhead shaped like a lightning bolt with one small backward-facing barb. Strong readable silhouette, crisp stepped pixel edges, limited palette of navy, ochre, golden yellow and pale cream highlight. Entire weapon fits inside the square canvas with at least 12 percent transparent padding on every side. No character, no hands, no background, no frame, no text, no watermark, no cast shadow. True transparent alpha. Placeholder game sprite, clean simple pixel art rather than painterly illustration.
```
