# Crab Spine export

Used by both `gameplay/enemies/crab/crab.tscn` and `elite_crab.tscn` (`EnemySpineVisual`;
EliteCrab scales its `Visual` by 1.5). `crab.skel38` is the original Spine 3.8.75 export; it
is converted for the Spine 4.3 runtime with:

```bash
python tools/spine/spine38_to_43.py assets/spine/enemies/Enemy_Crab/crab.skel38 assets/spine/enemies/Enemy_Crab/crab.spine-json
```

After a new export, rename the `.skel` to `.skel38`, convert again and run a Godot import.

| Spine clip | Crab | Elite Crab |
| --- | --- | --- |
| `idle` / `up_idle` | Idle (down / up) | Idle |
| `walk` | Walking down | Walking down |
| `walk_left` | Walking sideways (mirrored for right) | Walking sideways, and the charge run |
| `up_idle` | Walking up (no up walk clip) | Walking up |
| `attack` | Not used | Wind-up (from 0 s), egg throw, and the slam (from 0.6 s) |
| `up_attack` | Not used | Not used |

Size: `spine_pixel_size = 0.0032`, about 2 m wide and 1.85 m tall.
