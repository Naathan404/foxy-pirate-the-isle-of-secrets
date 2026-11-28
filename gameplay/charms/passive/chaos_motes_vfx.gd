class_name ChaosMotesVfx
extends Node3D
## Embers of Chaos that burst off a struck enemy and curve into Foxy, shrinking as she takes
## them in. Presentation only: Chaos is added by ChaosCollectorEffect the moment the hit lands.
## Built in code, so it needs no scene; it frees itself once the last ember arrives.

const SHADER: Shader = preload("res://gameplay/charms/passive/chaos_mote.gdshader")
const MOTE_COUNT := 6
const MOTE_SIZE_METERS := 0.75
## Height on the target the embers leave from, and on Foxy they fly to.
const SOURCE_HEIGHT_METERS := 0.9
const TARGET_HEIGHT_METERS := 1.1
const FLIGHT_SECONDS := 0.42
## Each ember leaves a little after the one before.
const STAGGER_SECONDS := 0.035
## How far the embers scatter before they turn back to Foxy.
const SCATTER_METERS := 1.1
const ARC_HEIGHT_METERS := 1.0
const TRAIL_SHARE := 0.55
## How far behind its ember, in flight progress, the trailing spark follows.
const TRAIL_LAG := 0.1
## Share of the flight over which an ember shrinks into Foxy.
const ABSORB_SHARE := 0.25

var _target: Node3D
var _source := Vector3.ZERO
var _last_destination := Vector3.ZERO
var _controls: Array[Vector3] = []
var _motes: Array[MeshInstance3D] = []
var _trails: Array[MeshInstance3D] = []
var _age: float = 0.0


static func spawn(parent: Node, from: Node3D, to: Node3D, color: Color) -> ChaosMotesVfx:
	var vfx := ChaosMotesVfx.new()
	vfx._target = to
	vfx._source = from.global_position + Vector3.UP * SOURCE_HEIGHT_METERS
	vfx._last_destination = to.global_position + Vector3.UP * TARGET_HEIGHT_METERS
	parent.add_child(vfx)
	vfx._build(color)
	return vfx


func _ready() -> void:
	# Embers are placed by hand every frame; interpolating them would smear their start.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _process(delta: float) -> void:
	_age += maxf(0.0, delta)
	if is_instance_valid(_target):
		_last_destination = (
			_target.get_global_transform_interpolated().origin + Vector3.UP * TARGET_HEIGHT_METERS
		)
	var finished := true
	for index in _motes.size():
		var progress := (_age - index * STAGGER_SECONDS) / FLIGHT_SECONDS
		if progress < 1.0 + TRAIL_LAG:
			finished = false
		_place(_motes[index], index, progress, 1.0)
		_place(_trails[index], index, progress - TRAIL_LAG, TRAIL_SHARE)
	if finished:
		queue_free()


func _build(color: Color) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * MOTE_SIZE_METERS
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("tint", color)
	var toward := _last_destination - _source
	var side := toward.cross(Vector3.UP).normalized()
	if side.is_zero_approx():
		side = Vector3.RIGHT
	for index in MOTE_COUNT:
		# Fan the curves out evenly to both sides, with a little chance in the reach.
		var spread := float(index) / maxf(1.0, MOTE_COUNT - 1.0) * 2.0 - 1.0
		_controls.append(
			_source
			+ side * spread * SCATTER_METERS * randf_range(0.8, 1.2)
			+ Vector3.UP * ARC_HEIGHT_METERS * randf_range(0.6, 1.3)
			- toward.normalized() * SCATTER_METERS * 0.4
		)
		_motes.append(_make_ember(quad, material))
		_trails.append(_make_ember(quad, material))


func _make_ember(quad: QuadMesh, material: ShaderMaterial) -> MeshInstance3D:
	var ember := MeshInstance3D.new()
	ember.mesh = quad
	ember.material_override = material
	ember.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ember.visible = false
	add_child(ember)
	return ember


func _place(ember: MeshInstance3D, index: int, progress: float, size: float) -> void:
	ember.visible = progress >= 0.0 and progress < 1.0
	if not ember.visible:
		return
	# Slow to leave the enemy, fast into Foxy.
	var t := progress * progress * (2.0 - progress)
	var first := _source.lerp(_controls[index], t)
	var second := _controls[index].lerp(_last_destination, t)
	ember.global_position = first.lerp(second, t)
	var grow := minf(1.0, progress * 5.0 + 0.4)
	var absorb := minf(1.0, (1.0 - progress) / ABSORB_SHARE)
	ember.scale = Vector3.ONE * size * grow * maxf(0.15, absorb)
