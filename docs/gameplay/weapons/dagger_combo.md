# Dagger melee combo

## Behavior and controls

Equip the dagger in game. Click LMB for melee, Shift for dash, and RMB for the
existing Chaos-powered throw.

Each click starts one swing or buffers **one** follow-up. Holding LMB does not auto-combo.
Additional presses while the slot is full neither add attacks nor refresh its lifetime.
The next swing begins after the current recovery completes. Fresh input after the
finisher starts a new chain. Direction is locked for each swing; input when queuing
the next swing selects its direction. Damage remains on the XZ plane in all eight
movement directions, independent of camera-facing sprite selection.

| Stage | Windup | Active | Recovery | Damage | Swing |
| --- | --- | --- | --- | --- | --- |
| 1 | 0.02 s | 0.23 s | 0.09 s | base × 1 | forward arc |
| 2 | 0.02 s | 0.23 s | 0.09 s | base × 1 | reverse arc |
| 3 | 0.02 s | 0.23 s | 0.09 s | base × 1 | forward arc |
| 4 | 0.35 s | 0.19 s | 0.24 s | base × 2 | orange thrust finisher |

The continuation window is 0.22 seconds **after recovery**; input buffer is 0.32 s.
Stages 1 and 3 share the first step resource. The finisher uses a longer forward step
and a straight thrust. Steps use the existing `move_and_slide()` path so walls block them.

Dash can cancel after 45% of recovery for stages 1–3, and 75% for stage 4.
Windup and active cannot be cancelled by ordinary dash input. Attack never interrupts
dash; a recent buffered attack can begin after dash finishes. Dash, damage, death,
fall interruption and weapon changes reset combo state. Inventory pauses an ongoing
swing and clears queued gameplay input.

## Architecture

- `AttackData.combo_steps` is an optional array of `MeleeComboStep` resources.
  Weapons with no combo keep the original single-attack path. Secondary attacks keep
  their existing costs, Chaos requirement, projectile behavior and feedback.
- `WeaponController` owns phase clocks, forge-adjusted timing, combo index, continuation
  window and a single buffered request. `attack_started(context)` lets the Player state
  restart the directional animation and step without leaving/reentering the FSM state.
- `DaggerAttack` follows the actor, rotates a narrow radial hitbox through the authored
  arc, and subsamples the sweep every eight degrees. Immediate physics shape samples
  use `HitBox`'s existing per-target reservation and damage/charm/Chaos signals.
  HitBox closes before recovery. Its existing overlap callbacks share that reservation.
- Damage is authored once in AttackData, multiplied per stage, then passed through
  existing forge and charm modifiers. Damage tags remain `normal` / melee; Chaos
  generation remains the Player's existing per-enemy successful-damage rule.
- `MeleeSlashVFX` consumes the swing progress and contains no damage logic. It uses
  the existing dagger energy shader, a procedural arc and small impact sparks.
  Effects finish fading independently of the attack node.
- The existing hitstop autoload now also supports local stops. Melee pauses source/
  first-target combat updates and AnimationPlayer using a real-time deadline. It does
  not change `Engine.time_scale`, so UI/audio/other actors continue. Subsequent hits
  in the same swing cannot repeatedly stop or shake the camera. Global hitstop used
  by other existing effects remains available. Pause/cancel/scene teardown restores speed.
- Enemies retain their Hit/Recovery FSM and flash. Per-hit knockback multipliers go
  through DamageContext; `EnemyData.knockback_resistance = 1`, zero base knockback,
  and boss group membership prevent physical recoil. Repeated valid hits refresh Hit
  reaction, without replacing the enemy behavior states.

## Tuning

Open `data/weapon/weapon_dagger.tres` → Normal Attack → Combo Steps. The four stages use three embedded
resources expose timing, damage/knockback multipliers, movement, step, swing angles,
reach, slash width/color, hitstop, shake and audio pitch. Tune the continuation/input
windows on Normal Attack. Forge attack speed still scales phase duration.

Use resource **Make Unique** when tuning one weapon instance. Leave `animation_prefix`
on a step empty to reuse AttackData's existing directional animation set; a future set
must provide valid non-looping `<prefix>_down`, `_up`, `_side` clips. No other weapon
has been implemented as part of this change.

## Assets and limits

The fallback sprite reuses one directional attack set. Spine plays `Attack_1`,
`Attack_2`, `Attack_1`, then `Attack_3` for the four stages.

Swing/hit audio reuses `dagger_throw.wav` and `dagger_hit.wav`, with stage-specific pitch
and volume through AudioManager. Distinct melee whoosh/finisher recordings can replace
these later. Swing audio plays on active start; impact audio/shake/hitstop play only on
confirmed positive damage, once per swing. Impact particles are capped at eight targets.
Immediate shape queries support up to 64 overlapping areas per radial sample.

## Validation and manual checklist

The combo order and finisher animation are checked by `test/dagger_combo_order_test.gd`.

- Click four times at a comfortable rhythm; verify the fourth hit is the heavy orange thrust.
- Spam LMB and hold LMB separately: no skipped stages, duplicate damage or endless attacks.
- Wait past the continuation window: the next attack starts at stage 1.
- Attack in all eight directions, including left-facing sprites and diagonals.
- Hit two close enemies in one swing: each loses HP once; feedback stays restrained.
- Miss: slash/whoosh appear, but no hit sound, impact shake or hitstop.
- Compare finisher damage, recoil, sparks and recovery against the first two swings.
- Press Shift during windup/active, then during late recovery; only the latter cancels.
- Press LMB during dash; dash completes before a buffered attack starts.
- Attack into the wall: no teleport through collision or delayed forward surge.
- Open inventory mid-combo and resume: no frozen animation or stale queued attack.
- Take damage/die mid-combo: active hitbox closes and the next chain resets.
- Fill Chaos, use RMB, and verify the throw/return, costs and charm effects still work.
- Set an enemy's knockback resistance to 1 and verify damage/flash without physical recoil.
