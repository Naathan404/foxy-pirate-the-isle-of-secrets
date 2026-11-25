# Foxy Spine export

`Foxy_full_skin_Test_U_Run (1).skel38` is the original Spine 3.8.75 binary export from the artist, kept as the conversion source. Its extension stops Godot from importing it. The game runs on spine-godot (Spine 4.3 runtime, `bin/`), which cannot read 3.8 files, so the export is converted to `foxy.spine-json`:

```bash
python tools/spine/spine38_to_43.py "assets/spine/foxy_anim_spine/Foxy_full_skin_Test_U_Run (1).skel38" assets/spine/foxy_anim_spine/foxy.spine-json
```

Run the conversion again after each new export from the artist, then run a Godot import. The atlas and all 12 PNG pages are used unchanged.

`foxy_skeleton.tres` is the resource used by Foxy. Current gameplay mappings use G1 idle, D/S/U run, D/G1/U dash, and the three G1 dagger attacks. The sprite animations remain for actions without a matching Spine clip.

The player fallback, HUD portraits and Abyssal Whirlpool use this same character. The bake scripts `scripts/art/bake_foxy_gameplay.gd` and `scripts/art/bake_whirlpool_cast.gd` were written for the removed SpineBridge addon and must be ported to `SpineSprite3D` before the next rebake. The gameplay atlas uses the frame indices in `foxy.tscn`. Its standing pose sets a height of 3 world units and a foot baseline of −0.5 in player visual space.
