# Barrel Spine export

`barrel_mimic.skel38` is the original Spine 3.8.75 binary export, kept as the conversion
source. Its extension stops Godot from importing it. spine-godot (Spine 4.3 runtime) cannot
read 3.8 files, so the export is converted to `barrel_mimic.spine-json`:

```bash
python tools/spine/spine38_to_43.py assets/spine/enemies/Enemy_Barrel/barrel_mimic.skel38 assets/spine/enemies/Enemy_Barrel/barrel_mimic.spine-json
```

After each new export from the artist, rename the new `.skel` to `.skel38`, run the
conversion again, then run a Godot import. The atlas and PNG are used unchanged.

`barrel_skeleton.tres` is the resource used by `gameplay/enemies/barrel/barrel.tscn`
(`EnemySpineVisual`). Clips and their gameplay use:

| Spine clip | Used for |
| --- | --- |
| `idle` | Idle, lid closed (loops) |
| `pop_up` | `charge`: the lid flips open before a burst |
| `shoot` / `shoot_up` | Each shot (`shoot_up` when facing up on screen) |
| `attack` / `attack_up` | Not used yet (full closed-to-open-to-shoot cycle) |

There are no hit or death clips; the visual keeps the current pose under the flash and fade.

`barrel_Projectiles.png` is the ink-blob bullet (`barrel_bullet.tscn`). Its head points to +x;
the bullet turns it to lead along its flight on screen.

Size: `spine_pixel_size = 0.004` on the Barrel `Visual` (about 2 m with the lid closed, Foxy's
height with the lid open). EliteBarrel scales its `Visual` by 2.
