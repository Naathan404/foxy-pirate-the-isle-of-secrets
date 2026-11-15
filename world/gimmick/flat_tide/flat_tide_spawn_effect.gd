extends Node3D
## A short splash and two expanding ripples at a newly exposed spawn point.

@export_range(0.1, 3.0, 0.05) var duration: float = 0.85
@export_range(1.0, 2.0, 0.05) var elite_scale: float = 1.3

@onready var _ripple: MeshInstance3D = $Ripple
@onready var _second_ripple: MeshInstance3D = $SecondRipple
@onready var _droplets: GPUParticles3D = $Droplets


func play(is_elite: bool = false) -> void:
	if is_elite:
		scale *= elite_scale
		_droplets.amount = 30
	# Each ripple owns its material because multiple enemies can spawn at once.
	var first := _ripple.material_override.duplicate() as ShaderMaterial
	var second := _second_ripple.material_override.duplicate() as ShaderMaterial
	_ripple.material_override = first
	_second_ripple.material_override = second
	_droplets.restart()
	_droplets.emitting = true
	var tween := create_tween()
	tween.tween_property(first, "shader_parameter/progress", 1.0, duration)
	tween.parallel().tween_property(second, "shader_parameter/progress", 1.0, duration * 0.72).set_delay(duration * 0.18)
	tween.tween_callback(queue_free)
