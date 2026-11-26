class_name BarrelInkSplash
extends Node3D
## Ink splash where a Barrel blob lands or hits: droplets burst out and, on a floor, a stain
## spreads and fades. Removes itself when done.

## Surfaces whose normal points this far up count as floor and get a stain.
const FLOOR_NORMAL_Y := 0.7
const STAIN_LIFT_METERS := 0.03
## Any range works; it only varies the stain shape between splashes.
const STAIN_SEED_RANGE := 100.0
const STAIN_START_SCALE := 0.35

@export_range(0.05, 1.0, 0.01, "suffix:s") var stain_spread_seconds: float = 0.12
@export_range(0.0, 5.0, 0.05, "suffix:s") var stain_hold_seconds: float = 0.9
@export_range(0.05, 3.0, 0.05, "suffix:s") var stain_fade_seconds: float = 0.6

@onready var _droplets: GPUParticles3D = $Droplets
@onready var _stain: MeshInstance3D = $Stain


func play(surface_normal: Vector3) -> void:
	_droplets.emitting = true
	var on_floor := surface_normal.y > FLOOR_NORMAL_Y
	_stain.visible = on_floor
	var lifetime := _droplets.lifetime
	if on_floor:
		_stain.position.y = STAIN_LIFT_METERS
		_stain.rotation.y = randf() * TAU
		# Each splash owns its material because several fade at once.
		var material := _stain.material_override.duplicate() as ShaderMaterial
		_stain.material_override = material
		material.set_shader_parameter(&"seed", randf() * STAIN_SEED_RANGE)
		var final_scale := _stain.scale
		_stain.scale = final_scale * STAIN_START_SCALE
		var tween := create_tween()
		var spread := tween.tween_property(_stain, "scale", final_scale, stain_spread_seconds)
		spread.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_interval(stain_hold_seconds)
		tween.tween_property(material, ^"shader_parameter/opacity", 0.0, stain_fade_seconds)
		lifetime = maxf(lifetime, stain_spread_seconds + stain_hold_seconds + stain_fade_seconds)
	create_tween().tween_callback(queue_free).set_delay(lifetime)
