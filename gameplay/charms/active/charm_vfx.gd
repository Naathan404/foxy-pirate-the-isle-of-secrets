class_name CharmVfx
extends Node3D
## Self-contained presentation; collision and damage remain owned by the skill execution.

enum Style { IMPACT, STREAM, VORTEX, ANCHOR, CHARGE, TARGET, FROST_FRACTURE, FROST_PRIMER }

const HEAVY_HITSTOP_SECONDS := 0.08
const HEAVY_SHAKE_PIXELS := 8.0
const HEAVY_SHAKE_SECONDS := 0.18
const GOLD := Color(1.0, 0.62, 0.16)
const SHADOW := Color(0.65, 0.32, 1.0)
const TIDE := Color(0.18, 0.85, 1.0)

@export var style: Style = Style.IMPACT
@export var tint: Color = GOLD
@export_range(0.05, 10.0, 0.01) var lifetime: float = 0.3
@export var sustained: bool = false

var _age: float = 0.0
var _material: ShaderMaterial
var _flash_material: ShaderMaterial

@onready var _surface: MeshInstance3D = $Surface
@onready var _flash: MeshInstance3D = $Flash


static func spawn(
	parent: Node3D,
	at: Vector3,
	color: Color,
	radius: float,
	seconds: float = 0.3,
	effect_style: Style = Style.IMPACT
) -> CharmVfx:
	var scene := load("res://gameplay/charms/active/charm_vfx.tscn") as PackedScene
	var effect := scene.instantiate() as CharmVfx
	effect.style = effect_style
	effect.tint = color
	effect.lifetime = seconds
	parent.add_child(effect)
	effect.global_position = at
	effect.scale = Vector3.ONE * maxf(0.01, radius)
	return effect


static func heavy_impact(parent: Node3D, at: Vector3, color: Color) -> void:
	spawn(parent, at + Vector3.UP * 0.5, color, 1.35)
	parent.get_node("/root/HitstopController").request(HEAVY_HITSTOP_SECONDS)
	parent.get_node("/root/ScreenShakeController").request(HEAVY_SHAKE_PIXELS, HEAVY_SHAKE_SECONDS)
	parent.get_node("/root/AudioManager").play_sfx_3d(
		preload("res://assets/audio/combat/dagger_hit.wav"), at, -7.0
	)


static func streak(
	parent: Node3D,
	from: Vector3,
	to: Vector3,
	color: Color,
	width: float = 0.4,
	seconds: float = 0.2
) -> CharmVfx:
	var effect := spawn(parent, from, color, 1.0, seconds, Style.STREAM)
	effect.set_endpoints(from, to, width)
	return effect


func _ready() -> void:
	_material = _surface.material_override.duplicate() as ShaderMaterial
	_surface.material_override = _material
	_material.set_shader_parameter("style", style)
	_material.set_shader_parameter("tint", tint)
	_flash_material = _flash.material_override.duplicate() as ShaderMaterial
	_flash.material_override = _flash_material
	_flash_material.set_shader_parameter("tint", tint)
	_flash.visible = style == Style.IMPACT
	_update_materials()


func _process(delta: float) -> void:
	_age += maxf(0.0, delta)
	_update_materials()
	if not sustained and _age >= lifetime:
		queue_free()


func set_radius(radius: float) -> void:
	scale = Vector3.ONE * maxf(0.01, radius)


func set_endpoints(from: Vector3, to: Vector3, width: float) -> void:
	var direction := to - from
	if direction.length_squared() < 0.0001:
		hide()
		return
	show()
	global_position = (from + to) * 0.5
	var along := direction.normalized()
	var camera := get_viewport().get_camera_3d()
	var toward_camera := camera.global_basis.z if is_instance_valid(camera) else Vector3.UP
	var across := toward_camera.cross(along).normalized()
	if across.is_zero_approx():
		var axis := Vector3.UP if absf(along.y) < 0.95 else Vector3.RIGHT
		across = axis.cross(along).normalized()
	global_basis = Basis(along, across, along.cross(across)).orthonormalized()
	_surface.rotation = Vector3.ZERO
	_surface.position = Vector3.ZERO
	_surface.scale = Vector3(direction.length() * 0.5, width * 0.5, 1.0)


func _update_materials() -> void:
	var progress := clampf(_age / lifetime, 0.0, 1.0)
	if sustained and style != Style.FROST_PRIMER:
		progress = 0.2
	_material.set_shader_parameter("progress", progress)
	_material.set_shader_parameter("phase", _age)
	_flash_material.set_shader_parameter("progress", minf(1.0, progress * 2.5))
	var camera := get_viewport().get_camera_3d()
	if _flash.visible and is_instance_valid(camera):
		_flash.global_basis = camera.global_basis.orthonormalized() * Basis.from_scale(scale)
