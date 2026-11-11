@tool
class_name FlatTideZone
extends MeshInstance3D

const DEFAULT_MATERIAL := preload("res://world/gimmick/flat_tide/flat_tide_volume_material.tres")
const VOLUME_MESH := preload("res://world/gimmick/flat_tide/flat_tide_volume_mesh.gd")
const DEBUG_MESH := preload("res://world/gimmick/flat_tide/flat_tide_debug_mesh.gd")
const MIN_SIZE := 0.1
const MIN_DEPTH := 0.02
const MIN_SEGMENTS := 2
const MIN_COVERAGE_SPAN := 0.001
const MIN_WAVE_LENGTH := 0.1
const DEBUG_HEIGHT_OFFSET := 0.03

enum FlowDirection { NEGATIVE_X, POSITIVE_X, NEGATIVE_Z, POSITIVE_Z }

@export_group("Area")
## Hướng nước tiến vào, theo trục cục bộ của vùng.
@export var flow_direction: FlowDirection = FlowDirection.NEGATIVE_X:
	set(value):
		flow_direction = value
		_request_rebuild()
## Kích thước tối đa của vùng nước trên mặt đất: X theo trục X, Y theo trục Z.
## Nước tiến từ phía X dương sang X âm trong tọa độ của vùng.
@export var size: Vector2 = Vector2(12.0, 12.0):
	set(value):
		size = Vector2(maxf(value.x, MIN_SIZE), maxf(value.y, MIN_SIZE))
		_request_rebuild()
## Mức triều chung từ 0 đến 1 mà vùng này bắt đầu ngập; số lớn làm nước đến muộn hơn.
@export_range(0.0, 1.0, 0.01) var start_coverage: float = 0.0:
	set(value):
		start_coverage = value
		_update_editor_preview()
## Mức triều chung mà vùng ngập hết phạm vi; đặt lớn hơn Start Coverage.
@export_range(0.0, 1.0, 0.01) var full_coverage: float = 1.0:
	set(value):
		full_coverage = value
		_update_editor_preview()
## Chênh lệch độ cao cho phép với đáy vùng nước khi xác định một điểm có bị ngập.
@export_range(0.0, 2.0, 0.01) var floor_tolerance: float = 0.6

@export_group("Water volume")
## Độ dày khối nước từ đáy đến mặt nước; tăng lên sẽ làm các mặt bên cao hơn.
@export_range(0.02, 3.0, 0.01, "suffix:m") var volume_depth: float = 2.75:
	set(value):
		volume_depth = maxf(value, MIN_DEPTH)
		_request_rebuild()
## Số đoạn chia mesh theo X; tăng để mặt sóng mịn hơn nhưng tốn thêm xử lý.
@export_range(2, 80, 1) var surface_segments_x: int = 24:
	set(value):
		surface_segments_x = maxi(value, MIN_SEGMENTS)
		_request_rebuild()
## Số đoạn chia mesh theo Z; tăng để mép sóng cong mượt hơn nhưng tốn thêm xử lý.
@export_range(2, 80, 1) var surface_segments_z: int = 24:
	set(value):
		surface_segments_z = maxi(value, MIN_SEGMENTS)
		_request_rebuild()
## Material chỉnh màu, độ đục, bọt và vân sáng; tạo bản sao nếu muốn vùng có màu riêng.
@export var water_material: ShaderMaterial = DEFAULT_MATERIAL:
	set(value):
		water_material = value
		_request_rebuild()
## Thứ tự vẽ nước trong suốt; tăng lên để nước phủ phần nhân vật nằm dưới mặt nước.
@export_range(-128, 126, 1) var water_render_priority: int = 1:
	set(value):
		water_render_priority = value
		_request_rebuild()

@export_group("Waves")
## Biên độ lớp sóng chính làm mép nước tiến lùi theo phương ngang.
@export_range(0.0, 2.0, 0.01, "suffix:m") var shore_wave_amplitude: float = 0.3
## Bước sóng của lớp sóng chính dọc theo mép nước; lớn hơn tạo các đường cong rộng hơn.
@export_range(0.1, 30.0, 0.1, "suffix:m") var shore_wave_length: float = 5.0
## Tốc độ chuyển động của lớp sóng chính ở mép nước.
@export_range(0.0, 5.0, 0.05) var shore_wave_speed: float = 1.1
## Biên độ lớp sóng phụ thêm chi tiết cho mép nước.
@export_range(0.0, 1.0, 0.01, "suffix:m") var shore_detail_amplitude: float = 0.08
## Bước sóng của lớp chi tiết ở mép nước; nhỏ hơn tạo nhiều gợn hơn.
@export_range(0.1, 30.0, 0.1, "suffix:m") var shore_detail_length: float = 2.4
## Tốc độ chuyển động của lớp chi tiết ở mép nước.
@export_range(0.0, 5.0, 0.05) var shore_detail_speed: float = 0.7
## Độ cao nhấp nhô của lớp sóng chính trên mặt nước.
@export_range(0.0, 0.3, 0.005, "suffix:m") var surface_wave_height: float = 0.035
## Bước sóng của lớp sóng chính trên mặt nước.
@export_range(0.1, 30.0, 0.1, "suffix:m") var surface_wave_length: float = 4.0
## Tốc độ chuyển động của lớp sóng chính trên mặt nước.
@export_range(0.0, 5.0, 0.05) var surface_wave_speed: float = 1.2
## Độ cao nhấp nhô của lớp sóng phụ trên mặt nước.
@export_range(0.0, 0.2, 0.005, "suffix:m") var surface_detail_height: float = 0.015
## Bước sóng của lớp chi tiết trên mặt nước.
@export_range(0.1, 30.0, 0.1, "suffix:m") var surface_detail_length: float = 2.5
## Tốc độ chuyển động của lớp chi tiết trên mặt nước.
@export_range(0.0, 5.0, 0.05) var surface_detail_speed: float = 0.8
## Chiều rộng vệt cảnh báo ở mép biển trước khi nước dâng; không làm vùng đó bị ngập.
@export_range(0.0, 4.0, 0.05, "suffix:m") var warning_width: float = 1.0

@export_group("Debug area")
## Hiện khung toàn bộ phạm vi có thể ngập trong editor; tắt để ẩn mọi đường debug.
@export var show_debug_area: bool = true:
	set(value):
		show_debug_area = value
		_request_rebuild()
## Hiện khung phạm vi và đường viền vùng đang ngập trong lúc chơi.
@export var debug_in_game: bool = false:
	set(value):
		debug_in_game = value
		_request_rebuild()
## Màu khung biểu thị toàn bộ phạm vi tối đa của vùng nước.
@export var debug_color: Color = Color(0.1, 0.9, 1.0, 0.9):
	set(value):
		debug_color = value
		_request_rebuild()
## Màu đường viền vùng đang ngập khi bật Debug In Game.
@export var active_debug_color: Color = Color(1.0, 0.75, 0.1, 1.0):
	set(value):
		active_debug_color = value
		_request_rebuild()

@export_group("Editor preview")
## Hiện trực tiếp khối nước trong viewport khi chỉnh scene; không ảnh hưởng lúc chơi.
@export var show_editor_preview: bool = true:
	set(value):
		show_editor_preview = value
		_request_rebuild()
## Mức triều chung để xem trước: 0 là triều thấp, 1 là triều cao.
@export_range(0.0, 1.0, 0.01) var editor_preview_coverage: float = 1.0:
	set(value):
		editor_preview_coverage = clampf(value, 0.0, 1.0)
		_update_editor_preview()
## Cho sóng chuyển động trong editor để xem trước hình dáng mặt nước.
@export var animate_editor_preview: bool = true

var _material: ShaderMaterial
var _fill: float = 0.0
var _visual_time: float = 0.0
var _rising: bool = false
var _falling: bool = false
var _debug_mesh: MeshInstance3D
var _preview_mesh: MeshInstance3D


func _ready() -> void:
	_ensure_debug()


func _process(_delta: float) -> void:
	# A script reloaded on an already-open editor scene does not get _ready again.
	if Engine.is_editor_hint():
		_ensure_debug()
		if show_editor_preview:
			if animate_editor_preview:
				_visual_time += _delta
			_update_editor_preview()
		return
	set_process(false)


func _ensure_debug() -> void:
	if is_instance_valid(_debug_mesh) and is_instance_valid(_preview_mesh):
		return
	_debug_mesh = get_node_or_null("TideAreaDebug") as MeshInstance3D
	if not is_instance_valid(_debug_mesh):
		_debug_mesh = MeshInstance3D.new()
		_debug_mesh.name = "TideAreaDebug"
		add_child(_debug_mesh, false, Node.INTERNAL_MODE_BACK)
	_preview_mesh = get_node_or_null("TideWaterPreview") as MeshInstance3D
	if not is_instance_valid(_preview_mesh):
		_preview_mesh = MeshInstance3D.new()
		_preview_mesh.name = "TideWaterPreview"
		_preview_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_preview_mesh, false, Node.INTERNAL_MODE_BACK)
	_rebuild()


func _request_rebuild() -> void:
	if is_inside_tree() and is_node_ready():
		call_deferred("_refresh_helpers")


func _refresh_helpers() -> void:
	if not is_instance_valid(_debug_mesh) or not is_instance_valid(_preview_mesh):
		_ensure_debug()
	else:
		_rebuild()


func _rebuild() -> void:
	if not is_instance_valid(_debug_mesh) or not is_instance_valid(_preview_mesh):
		return
	_rebuild_debug()
	var editor_preview := Engine.is_editor_hint()
	_preview_mesh.visible = editor_preview and show_editor_preview
	if editor_preview:
		set_process(show_editor_preview)
		if not show_editor_preview:
			_preview_mesh.mesh = null
			_material = null
			return
	if water_material == null or water_material.shader == null:
		push_warning("FlatTideZone needs a water ShaderMaterial.")
		if editor_preview:
			_preview_mesh.mesh = null
		else:
			mesh = null
		return
	_material = water_material.duplicate() as ShaderMaterial
	_material.render_priority = water_render_priority
	var volume := VOLUME_MESH.build(_flow_size(), volume_depth, surface_segments_x, surface_segments_z)
	var bounds := AABB(Vector3(-size.x * 0.5, 0.0, -size.y * 0.5), Vector3(size.x, volume_depth, size.y))
	if editor_preview:
		_preview_mesh.mesh = volume
		_preview_mesh.custom_aabb = bounds
		_preview_mesh.material_override = _material
		_preview_mesh.extra_cull_margin = 2.0 + surface_wave_height + surface_detail_height
		_update_editor_preview()
		return
	mesh = volume
	custom_aabb = bounds
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 2.0 + surface_wave_height + surface_detail_height
	_sync_material(false)


func _update_editor_preview() -> void:
	if Engine.is_editor_hint() and is_node_ready() and show_editor_preview and _material != null:
		set_coverage(editor_preview_coverage, false, _visual_time)


func set_coverage(
	coverage: float, warning: bool, animation_time: float = 0.0, warning_strength: float = 1.0,
	rising: bool = false, falling: bool = false
) -> void:
	_fill = clampf(
		(coverage - start_coverage) / maxf(MIN_COVERAGE_SPAN, full_coverage - start_coverage),
		0.0,
		1.0
	)
	_visual_time = animation_time
	_rising = rising
	_falling = falling
	_sync_material(warning, warning_strength)
	if debug_in_game and show_debug_area and not Engine.is_editor_hint():
		_rebuild_debug()


func _sync_material(warning: bool, warning_strength: float = 1.0) -> void:
	if _material == null:
		return
	_material.set_shader_parameter("zone_size", _flow_size())
	_material.set_shader_parameter("flow_direction", flow_direction)
	_material.set_shader_parameter("fill", _fill)
	_material.set_shader_parameter(
		"warning", clampf(warning_strength, 0.0, 1.0) if warning else 0.0
	)
	_material.set_shader_parameter("warning_width", warning_width)
	_material.set_shader_parameter("tide_time", _visual_time)
	_material.set_shader_parameter("tide_rising", 1.0 if _rising else 0.0)
	_material.set_shader_parameter("tide_falling", 1.0 if _falling else 0.0)
	_material.set_shader_parameter("shore_wave_amplitude", shore_wave_amplitude)
	_material.set_shader_parameter("shore_wave_length", maxf(MIN_WAVE_LENGTH, shore_wave_length))
	_material.set_shader_parameter("shore_wave_speed", shore_wave_speed)
	_material.set_shader_parameter("shore_detail_amplitude", shore_detail_amplitude)
	_material.set_shader_parameter(
		"shore_detail_length", maxf(MIN_WAVE_LENGTH, shore_detail_length)
	)
	_material.set_shader_parameter("shore_detail_speed", shore_detail_speed)
	_material.set_shader_parameter("surface_wave_height", surface_wave_height)
	_material.set_shader_parameter(
		"surface_wave_length", maxf(MIN_WAVE_LENGTH, surface_wave_length)
	)
	_material.set_shader_parameter("surface_wave_speed", surface_wave_speed)
	_material.set_shader_parameter("surface_detail_height", surface_detail_height)
	_material.set_shader_parameter(
		"surface_detail_length", maxf(MIN_WAVE_LENGTH, surface_detail_length)
	)
	_material.set_shader_parameter("surface_detail_speed", surface_detail_speed)


func contains_flooded_point(point: Vector3) -> bool:
	if _fill <= 0.0:
		return false
	var local := _to_flow(to_local(point))
	var flow_size := _flow_size()
	if absf(local.y) > floor_tolerance:
		return false
	if absf(local.z) > flow_size.y * 0.5 or local.x > flow_size.x * 0.5:
		return false
	return local.x >= _shore_x(local.z)


## Ground-level leading edge of the advancing visual wave, including its sloping foot.
func is_point_in_advancing_wave(point: Vector3) -> bool:
	if not _rising or _fill <= 0.0:
		return false
	var local := _to_flow(to_local(point))
	var flow_size := _flow_size()
	if absf(local.y) > floor_tolerance or absf(local.z) > flow_size.y * 0.5:
		return false
	if local.x < -flow_size.x * 0.5 - 2.0 or local.x > flow_size.x * 0.5:
		return false
	var segment := (local.z / flow_size.y + 0.5) * surface_segments_z
	var first := clampi(floori(segment), 0, surface_segments_z - 1)
	var z0 := lerpf(-flow_size.y * 0.5, flow_size.y * 0.5, float(first) / surface_segments_z)
	var z1 := lerpf(-flow_size.y * 0.5, flow_size.y * 0.5, float(first + 1) / surface_segments_z)
	var front := lerpf(_wave_foot_at_vertex(z0), _wave_foot_at_vertex(z1), clampf(segment - first, 0.0, 1.0))
	return local.x >= front


func _wave_foot_at_vertex(z: float) -> float:
	var flow_size := _flow_size()
	var front := _shore_at_vertex(z)
	var width := maxf(0.0, flow_size.x * 0.5 - front)
	var motion := smoothstep(0.0, 0.08, _fill) * (1.0 - smoothstep(0.88, 1.0, _fill))
	var slope := 4.2
	var resting := 0.55
	if _material:
		var slope_override: Variant = _material.get_shader_parameter("shore_slope")
		var resting_override: Variant = _material.get_shader_parameter("resting_slope")
		if slope_override != null:
			slope = float(slope_override)
		if resting_override != null:
			resting = float(resting_override)
	var surge := minf(lerpf(resting, slope, motion), width * 0.9)
	return maxf(-flow_size.x * 0.5 - resting * (1.0 - motion), front - surge)


func _shore_x(local_z: float) -> float:
	# Match the straight segments joining the shader-displaced mesh vertices.
	var flow_size := _flow_size()
	var segment := (local_z / flow_size.y + 0.5) * surface_segments_z
	var first := clampi(floori(segment), 0, surface_segments_z - 1)
	var z0 := lerpf(-flow_size.y * 0.5, flow_size.y * 0.5, float(first) / surface_segments_z)
	var z1 := lerpf(-flow_size.y * 0.5, flow_size.y * 0.5, float(first + 1) / surface_segments_z)
	return lerpf(_shore_at_vertex(z0), _shore_at_vertex(z1), clampf(segment - first, 0.0, 1.0))


func _shore_at_vertex(local_z: float) -> float:
	var flow_size := _flow_size()
	var half_width := flow_size.x * 0.5
	var wave := shore_wave_amplitude * sin(PI * _fill)
	wave *= sin(
		TAU * local_z / maxf(MIN_WAVE_LENGTH, shore_wave_length) + _visual_time * shore_wave_speed
	)
	wave += (
		shore_detail_amplitude
		* sin(PI * _fill)
		* sin(
			(
				TAU * local_z / maxf(MIN_WAVE_LENGTH, shore_detail_length)
				- _visual_time * shore_detail_speed
			)
		)
	)
	return clampf(half_width - flow_size.x * _fill + wave, -half_width, half_width)


## Height of the animated water surface at this horizontal world position.
func get_surface_height_at(point: Vector3) -> float:
	var local := _to_flow(to_local(point))
	var wave := sin(
		(
			TAU * (local.x + local.z) / maxf(MIN_WAVE_LENGTH, surface_wave_length)
			+ _visual_time * surface_wave_speed
		)
	)
	var detail := sin(
		(
			TAU * (local.x - local.z) / maxf(MIN_WAVE_LENGTH, surface_detail_length)
			- _visual_time * surface_detail_speed
		)
	)
	local.y = volume_depth + surface_wave_height * wave + surface_detail_height * detail
	return to_global(_from_flow(local)).y


func _flow_size() -> Vector2:
	return Vector2(size.y, size.x) if flow_direction >= FlowDirection.NEGATIVE_Z else size


func _from_flow(point: Vector3) -> Vector3:
	match flow_direction:
		FlowDirection.POSITIVE_X:
			return Vector3(-point.x, point.y, -point.z)
		FlowDirection.NEGATIVE_Z:
			return Vector3(-point.z, point.y, point.x)
		FlowDirection.POSITIVE_Z:
			return Vector3(point.z, point.y, -point.x)
	return point


func _to_flow(point: Vector3) -> Vector3:
	match flow_direction:
		FlowDirection.POSITIVE_X:
			return Vector3(-point.x, point.y, -point.z)
		FlowDirection.NEGATIVE_Z:
			return Vector3(point.z, point.y, -point.x)
		FlowDirection.POSITIVE_Z:
			return Vector3(-point.z, point.y, point.x)
	return point


func get_flow_direction() -> Vector3:
	var direction := global_transform.basis * _from_flow(Vector3.LEFT)
	direction.y = 0.0
	return direction.normalized()


func _rebuild_debug() -> void:
	if not is_instance_valid(_debug_mesh):
		return
	_debug_mesh.visible = show_debug_area and (Engine.is_editor_hint() or debug_in_game)
	if _debug_mesh.visible:
		var shoreline := PackedVector3Array()
		if not Engine.is_editor_hint() and _fill > 0.0:
			var flow_size := _flow_size()
			for index in range(surface_segments_z + 1):
				var z := lerpf(-flow_size.y * 0.5, flow_size.y * 0.5, float(index) / surface_segments_z)
				shoreline.append(_from_flow(Vector3(_shore_at_vertex(z), DEBUG_HEIGHT_OFFSET, z)))
		_debug_mesh.mesh = DEBUG_MESH.build(
			size, volume_depth, debug_color, DEBUG_HEIGHT_OFFSET, active_debug_color, shoreline,
			_from_flow(Vector3(_flow_size().x * 0.5, DEBUG_HEIGHT_OFFSET, -_flow_size().y * 0.5)),
			_from_flow(Vector3(_flow_size().x * 0.5, DEBUG_HEIGHT_OFFSET, _flow_size().y * 0.5))
		)
