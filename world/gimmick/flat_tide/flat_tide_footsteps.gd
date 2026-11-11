extends Node3D

const FOOTPRINT_SHADER := preload("res://world/gimmick/flat_tide/water_footprint.gdshader")
const MIN_DELTA := 0.001
const FOOTPRINT_PRIORITY_OFFSET := 1

## Controller dùng để xác định vùng nước và cao độ mặt sóng.
@export var controller: FlatTideController
## Nhân vật tạo dấu chân nước; gán node Foxy.
@export var player: Player
## Quãng đường giữa hai dấu chân; giảm để dấu xuất hiện dày hơn.
@export_range(0.3, 2.0, 0.05) var step_distance: float = 0.8
## Thời gian một dấu chân và vòng gợn tồn tại, tính bằng giây.
@export_range(0.1, 2.0, 0.05) var mark_lifetime: float = 0.75
## Độ lệch dấu chân trái và phải sang hai bên hướng di chuyển.
@export_range(0.0, 0.5, 0.01) var step_width: float = 0.16
## Tốc độ di chuyển tối thiểu để tạo dấu chân, tính theo đơn vị/giây.
@export_range(0.0, 5.0, 0.05) var minimum_speed: float = 0.7
## Kích thước vùng hiển thị của mỗi dấu chân và vòng gợn.
@export_range(0.1, 4.0, 0.05) var footprint_size: float = 1.25
## Số dấu chân tối đa được tái sử dụng đồng thời.
@export_range(1, 64, 1) var max_marks: int = 16
## Khoảng nâng dấu chân lên trên mặt nước để tránh bị che hoặc nhấp nháy.
@export_range(0.0, 0.3, 0.005) var surface_clearance: float = 0.035
## Quãng dịch chuyển tối đa trong một frame; lớn hơn sẽ xem là dịch chuyển tức thời.
@export_range(0.1, 10.0, 0.1) var max_step_displacement: float = 2.0

var _marks: Array[MeshInstance3D] = []
var _ages: Array[float] = []
var _mark_zones: Array[FlatTideZone] = []
var _next_mark: int = 0
var _distance_since_step: float = 0.0
var _step_side: float = 1.0
var _was_walking_in_water: bool = false
var _previous_position: Vector3


func _ready() -> void:
	if not is_instance_valid(player) or not is_instance_valid(controller):
		set_physics_process(false)
		return
	_previous_position = player.global_position
	for index in range(max_marks):
		var mark := MeshInstance3D.new()
		mark.name = "WaterStep%d" % index
		var plane := PlaneMesh.new()
		plane.size = Vector2.ONE * footprint_size
		var material := ShaderMaterial.new()
		material.shader = FOOTPRINT_SHADER
		plane.material = material
		mark.mesh = plane
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mark)
		mark.top_level = true
		mark.hide()
		_marks.append(mark)
		_ages.append(mark_lifetime)
		_mark_zones.append(null)


func _physics_process(delta: float) -> void:
	_update_marks(delta)
	if not is_instance_valid(player) or not is_instance_valid(controller):
		return
	var displacement := player.global_position - _previous_position
	_previous_position = player.global_position
	displacement.y = 0.0
	var speed := displacement.length() / maxf(delta, MIN_DELTA)
	if player.dead or not player.is_on_floor() or not player.environment_is_water:
		_reset_steps()
		return
	if speed < minimum_speed or displacement.length() > max_step_displacement:
		if displacement.length() > max_step_displacement:
			_reset_steps()
		return
	var direction := displacement.normalized()
	var foot := player.global_position + Vector3.DOWN * controller.player_ground_offset
	if not _was_walking_in_water:
		_was_walking_in_water = true
		_distance_since_step = step_distance
	_distance_since_step += displacement.length()
	if _distance_since_step < step_distance:
		return
	_distance_since_step = fmod(_distance_since_step, step_distance)
	var side := direction.cross(Vector3.UP) * step_width * _step_side
	var mark_position := foot + side
	var zone := controller.get_flooded_zone(mark_position)
	if zone != null:
		_emit_mark(mark_position, direction, zone)
	_step_side = -_step_side


func _update_marks(delta: float) -> void:
	for index in range(_marks.size()):
		var mark := _marks[index]
		if not mark.visible:
			continue
		var zone := _mark_zones[index]
		if not is_instance_valid(zone):
			mark.hide()
			continue
		var ground_point := Vector3(
			mark.global_position.x, zone.global_position.y, mark.global_position.z
		)
		if not zone.contains_flooded_point(ground_point):
			mark.hide()
			continue
		mark.global_position.y = zone.get_surface_height_at(ground_point) + surface_clearance
		_ages[index] += delta
		if _ages[index] >= mark_lifetime:
			mark.hide()
		else:
			(mark.mesh.material as ShaderMaterial).set_shader_parameter(
				"progress", _ages[index] / mark_lifetime
			)


func _emit_mark(point: Vector3, direction: Vector3, zone: FlatTideZone) -> void:
	var mark := _marks[_next_mark]
	(mark.mesh.material as ShaderMaterial).render_priority = (
		zone.water_render_priority + FOOTPRINT_PRIORITY_OFFSET
	)
	_ages[_next_mark] = 0.0
	_mark_zones[_next_mark] = zone
	mark.global_position = Vector3(
		point.x, zone.get_surface_height_at(point) + surface_clearance, point.z
	)
	mark.rotation.y = atan2(direction.x, direction.z)
	(mark.mesh.material as ShaderMaterial).set_shader_parameter("progress", 0.0)
	mark.show()
	_next_mark = (_next_mark + 1) % _marks.size()


func _reset_steps() -> void:
	_was_walking_in_water = false
	_distance_since_step = 0.0
	_step_side = 1.0
