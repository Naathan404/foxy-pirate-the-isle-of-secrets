# Hermit crab Spine export

Used by `gameplay/enemies/hermit_crab/hermit_crab.tscn` and `elite_hermit_crab.tscn`
(`EnemySpineVisual`; EliteHermitCrab scales its `Visual` by 1.5). The art is a side view facing
right and is mirrored from the enemy's facing on screen. `crab_charge_side_adjusted.skel38`
is the original Spine 3.8.75 export; it is converted for the Spine 4.3 runtime with:

```bash
python tools/spine/spine38_to_43.py assets/spine/enemies/Enemy_HermitCarb/crab_charge_side_adjusted.skel38 assets/spine/enemies/Enemy_HermitCarb/crab_charge_side_adjusted.spine-json
```

After a new export, rename the `.skel` to `.skel38`, convert again and run a Godot import.

| Spine clip | Used for |
| --- | --- |
| `idle` | Idle and the pause before a dash |
| `walk` | Patrol |
| `windup` | `charge`: the wind-up before a dash |
| `charge_run` | `attack`: the dash |
| `stunned` | `hit` |
| `charge`, `charge_hit` | Not used |

Size: `spine_pixel_size = 0.0032` (about 2.1 m wide, 1.9 m tall) with `lift_meters = 0.125`,
because the legs reach below the skeleton root.
