extends Node3D
## One finite shockwave per clustered volley impact; owns its particles and materials.

@export_range(0.1, 2.0, 0.05) var duration: float = 0.55

var _age: float = 0.0
var _strength: float = 0.0
var _started: bool = false

@onready var _ring: MeshInstance3D = $Ring
@onready var _echo: MeshInstance3D = $Echo
@onready var _flash: MeshInstance3D = $Flash
@onready var _particles: GPUParticles3D = $Particles


func _ready() -> void:
	set_process(false)
	_ring.hide()
	_echo.hide()
	_flash.hide()


func burst(strength: float) -> void:
	_strength = clampf(strength, 0.0, 1.0)
	_age = 0.0
	_started = true
	_particles.amount = 28 + roundi(_strength * 24.0)
	_particles.restart()
	_particles.emitting = true
	set_process(true)
	_update_visuals()


func _process(delta: float) -> void:
	if not _started:
		return
	_age += delta
	if _age >= duration:
		queue_free()
		return
	_update_visuals()


func _update_visuals() -> void:
	var power: float = lerpf(0.65, 1.0, _strength)
	for index in 2:
		var ring: MeshInstance3D = _ring if index == 0 else _echo
		var time := clampf((_age - index * 0.055) / (duration - 0.055), 0.0, 1.0)
		var expansion := 1.0 - pow(1.0 - time, 3.0)
		ring.visible = _age >= index * 0.055
		ring.scale = Vector3.ONE * lerpf(0.08, power * (1.0 + index * 0.15), expansion)
		var material := ring.material_override as ShaderMaterial
		material.set_shader_parameter("opacity", pow(1.0 - time, 2.0) * power)
	var flash_time := clampf(_age / 0.13, 0.0, 1.0)
	_flash.visible = flash_time < 1.0
	_flash.scale = Vector3.ONE * power * lerpf(0.35, 1.25, flash_time)
	(_flash.material_override as ShaderMaterial).set_shader_parameter(
		"opacity", pow(1.0 - flash_time, 2.0)
	)
