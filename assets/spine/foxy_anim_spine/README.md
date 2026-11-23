# Foxy Spine export

`Foxy_full_skin_Test_U_Run (1).skel` is the original Spine 3.8.75 export from the artist. The installed SpineBridge 3.8 provider requires the 3.8.99 version label. `Foxy_full_skin_Test_U_Run (1)_compat.skel` changes only that label; keep the original export for future re-exports. The atlas and all 12 PNG pages remain unchanged.

`foxy_skeleton.tres` is the resource used by Foxy. Current gameplay mappings use G1 idle, D/S/U run, D/G1/U dash, and the three G1 dagger attacks. The sprite animations remain for actions without a matching Spine clip.

The player fallback, HUD portraits and Abyssal Whirlpool use this same character. To rebuild the player atlas and HUD, run Godot with a renderer and `--script res://scripts/art/bake_foxy_gameplay.gd`. For Whirlpool, use `--script res://scripts/art/bake_whirlpool_cast.gd`. Run a Godot import after baking. The gameplay atlas uses the frame indices in `foxy.tscn`. Its standing pose sets a height of 3 world units and a foot baseline of −0.5 in player visual space.
