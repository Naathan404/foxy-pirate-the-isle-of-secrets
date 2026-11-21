@tool
class_name FlatTideZone
extends MeshInstance3D
## One area of a flat tide. The waterline (`_shore_x`) is the single source of truth: gameplay
## checks it on the CPU and the shader places the water's ground contact on the same line.
## The water is a single sheet hugging the ground, with a travelling crest while it rises.

enum FlowDirection { NEGATIVE_X, POSITIVE_X, NEGATIVE_Z, POSITIVE_Z }

const DEFAULT_MATERIAL := preload("res://world/gimmick/flat_tide/flat_tide_volume_material.tres")
const SURFACE_MESH := preload("res://world/gimmick/flat_tide/flat_tide_surface_mesh.gd")
const DEBUG_MESH := preload("res://world/gimmick/flat_tide/flat_tide_debug_mesh.gd")
const MIN_SIZE := 0.1
const MIN_DEPTH := 0.02
const MIN_SEGMENTS := 2
const MIN_COVERAGE_SPAN := 0.001
const MIN_WAVE_LENGTH := 0.1
const MIN_LENGTH := 0.001
const DEBUG_HEIGHT_OFFSET := 0.03
## Matches GROUND_LIFT in the shader: dry rows sit just above the ground.
const GROUND_LIFT := 0.02
## Coverage ramps that fade the travelling crest in after the wave starts and out near full.
const SURGE_IN_END := 0.06
const SURGE_OUT_START := 0.85
## Coverage after which the shoreline settles inside the zone (see `_shore_x`).
const SETTLE_START := 0.85
## Margin added around the sheet bounds so culling never clips animated vertices.
const CULL_MARGIN := 1.0
## Largest spacing between sheet columns across the flow, so the crest height follows the
## per-pixel waterline closely even on maps that set few `surface_segments_z`.
const MAX_ACROSS_SPACING := 0.5
## Sampling step of the debug shoreline drawn with `debug_in_game`.
const DEBUG_SHORE_STEP := 0.25

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
		update_configuration_warnings()
## Mức triều chung mà vùng ngập hết phạm vi; đặt lớn hơn Start Coverage.
@export_range(0.0, 1.0, 0.01) var full_coverage: float = 1.0:
	set(value):
		full_coverage = value
		_update_editor_preview()
		update_configuration_warnings()
## Chênh lệch độ cao cho phép với đáy vùng nước khi xác định một điểm có bị ngập.
@export_range(0.0, 2.0, 0.01) var floor_tolerance: float = 0.6

@export_group("Water volume")
## Trần chiều cao hiển thị của nước tính từ nền. Rest Height và Crest Height bị giới hạn bởi
## giá trị này; các map cũ đặt 2-2.75 m vẫn dùng được mà không cần sửa.
@export_range(0.02, 3.0, 0.01, "suffix:m") var volume_depth: float = 2.75:
	set(value):
		volume_depth = maxf(value, MIN_DEPTH)
		_request_rebuild()
		update_configuration_warnings()
## Số hàng của tấm nước theo hướng dòng chảy; hàng dồn về phía mép nước để đỉnh sóng mịn.
@export_range(2, 80, 1) var surface_segments_x: int = 24:
	set(value):
		surface_segments_x = maxi(value, MIN_SEGMENTS)
		_request_rebuild()
## Số đoạn chia ngang dòng chảy (tối thiểu mỗi 0,5 m một đoạn). Mép nước luôn được cắt mượt theo
## từng pixel; giá trị này chỉ ảnh hưởng độ mịn của đỉnh sóng.
@export_range(2, 80, 1) var surface_segments_z: int = 24:
	set(value):
		surface_segments_z = maxi(value, MIN_SEGMENTS)
		_request_rebuild()
## Material chỉnh màu, độ đục, bọt và vân nước; tạo bản sao nếu muốn vùng có màu riêng.
@export var water_material: ShaderMaterial = DEFAULT_MATERIAL:
	set(value):
		water_material = value
		_request_rebuild()
## Thứ tự vẽ nước trong suốt; tăng lên để nước phủ phần nhân vật nằm dưới mặt nước.
@export_range(-128, 126, 1) var water_render_priority: int = 1:
	set(value):
		water_render_priority = value
		_request_rebuild()

@export_group("Tide shape")
## Độ cao mặt nước nông phía sau mép sóng khi triều đã phủ.
@export_range(0.02, 1.0, 0.01, "suffix:m") var rest_height: float = 0.16
## Độ cao đỉnh sóng di chuyển cùng mép nước khi đang dâng; 0 để tắt đỉnh sóng.
@export_range(0.0, 2.0, 0.01, "suffix:m") var crest_height: float = 0.55:
	set(value):
		crest_height = value
		update_configuration_warnings()
## Khoảng từ mép nước chạm đất đến đỉnh sóng; nhỏ hơn làm mặt sóng dốc hơn.
@export_range(0.1, 4.0, 0.05, "suffix:m") var crest_rise_length: float = 0.9
## Độ dài phần sóng hạ dần phía sau đỉnh về mực nước nông.
@export_range(0.1, 10.0, 0.1, "suffix:m") var crest_tail_length: float = 3.2
## Khoảng nước từ mép (chạm đất) dâng lên tới Rest Height.
@export_range(0.05, 5.0, 0.05, "suffix:m") var rest_ramp_length: float = 1.2
## Độ dài làm mờ ở phía biển; nước như đến từ ngoài khung thay vì bắt đầu ở cạnh thẳng.
@export_range(0.0, 10.0, 0.1, "suffix:m") var source_fade_length: float = 2.5
## Độ dài làm mờ và hạ thấp ở hai cạnh bên vùng, để không thấy thành hộp.
@export_range(0.0, 10.0, 0.1, "suffix:m") var side_fade_length: float = 1.5

@export_group("Waves")
## Biên độ lớp sóng chính làm mép nước tiến lùi theo phương ngang.
@export_range(0.0, 2.0, 0.01, "suffix:m") var shore_wave_amplitude: float = 0.55
## Bước sóng của lớp sóng chính dọc theo mép nước; lớn hơn tạo các đường cong rộng hơn.
@export_range(0.1, 30.0, 0.1, "suffix:m") var shore_wave_length: float = 5.0
## Tốc độ chuyển động của lớp sóng chính ở mép nước.
@export_range(0.0, 5.0, 0.05) var shore_wave_speed: float = 1.1
## Biên độ lớp sóng phụ thêm chi tiết cho mép nước.
@export_range(0.0, 1.0, 0.01, "suffix:m") var shore_detail_amplitude: float = 0.18
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
## Hiện trực tiếp mặt nước trong viewport khi chỉnh scene; không ảnh hưởng lúc chơi.
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
var _surge: float = 0.0
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


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if full_coverage <= start_coverage:
		warnings.append("Full Coverage phải lớn hơn Start Coverage, nếu không vùng ngập tức thì.")
	if crest_height > volume_depth:
		warnings.append(
			"Crest Height lớn hơn Volume Depth; đỉnh sóng sẽ bị giới hạn ở Volume Depth."
		)
	return warnings


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
	var sheet := SURFACE_MESH.build(_flow_size().y, surface_segments_x, _across_segments())
	# Sheet rows are placed by the shader, so the bounds cover the whole zone.
	var bounds := AABB(
		Vector3(-size.x * 0.5, 0.0, -size.y * 0.5), Vector3(size.x, _max_visual_height(), size.y)
	)
	var target := _preview_mesh if editor_preview else self as MeshInstance3D
	target.mesh = sheet
	target.custom_aabb = bounds
	target.material_override = _material
	target.extra_cull_margin = CULL_MARGIN
	target.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if editor_preview:
		_update_editor_preview()
		return
	_sync_material()


func _update_editor_preview() -> void:
	if Engine.is_editor_hint() and is_node_ready() and show_editor_preview and _material != null:
		set_coverage(editor_preview_coverage, _visual_time)


## The rising warning is a screen overlay owned by FlatTideController, not part of the water.
func set_coverage(
	coverage: float, animation_time: float = 0.0, rising: bool = false, falling: bool = false
) -> void:
	_fill = clampf(
		(coverage - start_coverage) / maxf(MIN_COVERAGE_SPAN, full_coverage - start_coverage),
		0.0,
		1.0
	)
	_visual_time = animation_time
	_rising = rising
	_falling = falling
	_surge = 0.0
	if _rising:
		_surge = (
			smoothstep(0.0, SURGE_IN_END, _fill) * (1.0 - smoothstep(SURGE_OUT_START, 1.0, _fill))
		)
	_sync_material()
	if debug_in_game and show_debug_area and not Engine.is_editor_hint():
		_rebuild_debug()


func _sync_material() -> void:
	if _material == null:
		return
	var flow_size := _flow_size()
	var heights := _visual_heights()
	var values := {
		"zone_size": flow_size,
		"flow_direction": flow_direction,
		"fill": _fill,
		"tide_time": _visual_time,
		"tide_rising": 1.0 if _rising else 0.0,
		"tide_falling": 1.0 if _falling else 0.0,
		"surge": _surge,
		"rest_height": heights.x,
		"crest_height": heights.y,
		"crest_rise_length": crest_rise_length,
		"crest_tail_length": crest_tail_length,
		"rest_ramp_length": rest_ramp_length,
		"side_fade_length": side_fade_length,
		"source_fade_length": source_fade_length,
		"shore_wave_amplitude": shore_wave_amplitude,
		"shore_wave_length": maxf(MIN_WAVE_LENGTH, shore_wave_length),
		"shore_wave_speed": shore_wave_speed,
		"shore_detail_amplitude": shore_detail_amplitude,
		"shore_detail_length": maxf(MIN_WAVE_LENGTH, shore_detail_length),
		"shore_detail_speed": shore_detail_speed,
		"surface_wave_height": surface_wave_height,
		"surface_wave_length": maxf(MIN_WAVE_LENGTH, surface_wave_length),
		"surface_wave_speed": surface_wave_speed,
		"surface_detail_height": surface_detail_height,
		"surface_detail_length": maxf(MIN_WAVE_LENGTH, surface_detail_length),
		"surface_detail_speed": surface_detail_speed,
	}
	for key: String in values:
		_material.set_shader_parameter(key, values[key])


func _across_segments() -> int:
	return maxi(surface_segments_z, ceili(_flow_size().y / MAX_ACROSS_SPACING))


## x = rest height, y = crest height, both capped by the legacy Volume Depth.
func _visual_heights() -> Vector2:
	return Vector2(minf(rest_height, volume_depth), minf(crest_height, volume_depth))


func _max_visual_height() -> float:
	var heights := _visual_heights()
	return heights.x + heights.y + surface_wave_height + surface_detail_height


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


## True while the tide is rising and this point is already behind the advancing waterline.
## The visible contact line is drawn exactly on `_shore_x`, so the push matches the visual.
func is_point_in_advancing_wave(point: Vector3) -> bool:
	return _rising and contains_flooded_point(point)


## Horizontal distance from a world point to this zone's full floodable area; 0 when inside.
func get_distance_to_area(point: Vector3) -> float:
	var local := to_local(point)
	var outside := Vector2(
		maxf(0.0, absf(local.x) - size.x * 0.5), maxf(0.0, absf(local.z) - size.y * 0.5)
	)
	return outside.length()


## Travelling crest strength in [0, 1]; 0 while the water is calm or receding.
func get_surge_strength() -> float:
	return _surge


## Waterline in canonical flow space. The shader cuts the visible edge per pixel on this exact
## curve, so gameplay and the drawn contact line match everywhere along the shore.
func _shore_x(local_z: float) -> float:
	var flow_size := _flow_size()
	var half_width := flow_size.x * 0.5
	# Near full coverage the line pulls inside the zone by the wave reach so it stays wavy
	# instead of flattening against the zone edge. Mirrored by shore_position() in the shader.
	var settle := smoothstep(SETTLE_START, 1.0, _fill)
	var envelope := maxf(sin(PI * _fill), settle)
	var wave := (
		shore_wave_amplitude
		* sin(
			(
				TAU * local_z / maxf(MIN_WAVE_LENGTH, shore_wave_length)
				+ _visual_time * shore_wave_speed
			)
		)
	)
	wave += (
		shore_detail_amplitude
		* sin(
			(
				TAU * local_z / maxf(MIN_WAVE_LENGTH, shore_detail_length)
				- _visual_time * shore_detail_speed
			)
		)
	)
	var line := half_width - flow_size.x * _fill + _shore_reach() * settle + envelope * wave
	return clampf(line, -half_width, half_width)


func _shore_reach() -> float:
	return absf(shore_wave_amplitude) + absf(shore_detail_amplitude)


## Height above the zone floor of the visible water at a canonical point; mirrors the shader.
func _sheet_height(x: float, z: float) -> float:
	if _fill <= 0.0:
		return GROUND_LIFT
	var d := x - _shore_x(z)
	if d <= 0.0:
		return GROUND_LIFT
	var heights := _visual_heights()
	var body := smoothstep(0.0, maxf(rest_ramp_length, MIN_LENGTH), d)
	var rise := smoothstep(0.0, maxf(crest_rise_length, MIN_LENGTH), d)
	var tail := (
		1.0
		- smoothstep(crest_rise_length, crest_rise_length + maxf(crest_tail_length, MIN_LENGTH), d)
	)
	var height := heights.x * body + heights.y * _surge * rise * tail
	var wave := sin(
		(
			TAU * (x + z) / maxf(MIN_WAVE_LENGTH, surface_wave_length)
			+ _visual_time * surface_wave_speed
		)
	)
	var detail := sin(
		(
			TAU * (x - z) / maxf(MIN_WAVE_LENGTH, surface_detail_length)
			- _visual_time * surface_detail_speed
		)
	)
	height += (surface_wave_height * wave + surface_detail_height * detail) * body
	var side_distance := _flow_size().y * 0.5 - absf(z)
	height *= smoothstep(0.0, maxf(side_fade_length, MIN_LENGTH), side_distance)
	return maxf(GROUND_LIFT, height)


## Height of the animated water surface at this horizontal world position.
func get_surface_height_at(point: Vector3) -> float:
	var local := _to_flow(to_local(point))
	local.y = _sheet_height(local.x, local.z)
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
			var samples := maxi(MIN_SEGMENTS, ceili(flow_size.y / DEBUG_SHORE_STEP))
			for index in range(samples + 1):
				var z := lerpf(-flow_size.y * 0.5, flow_size.y * 0.5, float(index) / samples)
				shoreline.append(_from_flow(Vector3(_shore_x(z), DEBUG_HEIGHT_OFFSET, z)))
		_debug_mesh.mesh = DEBUG_MESH.build(
			size,
			_max_visual_height(),
			debug_color,
			DEBUG_HEIGHT_OFFSET,
			active_debug_color,
			shoreline,
			_from_flow(Vector3(_flow_size().x * 0.5, DEBUG_HEIGHT_OFFSET, -_flow_size().y * 0.5)),
			_from_flow(Vector3(_flow_size().x * 0.5, DEBUG_HEIGHT_OFFSET, _flow_size().y * 0.5))
		)
