class_name FlatTideController
extends Node3D

signal state_changed(new_state: State)
signal coverage_changed(value: float)
signal rising_warned(seconds_remaining: float)

enum State { LOW, RISING, HIGH, FALLING }

const SHOCKWAVE_DURATION := 0.3
const SHOCKWAVE_STRENGTH := 0.005
const SHOCKWAVE_COLOR := Color("78dfff")
const SHOCKWAVE_RADIUS_PIXELS := 110.0
# //NLVP sửa: Giữ mỗi pha có thời lượng hợp lệ.
const MIN_PHASE_DURATION_SECONDS := 0.1

## Nhân vật chịu ảnh hưởng của nước; gán node Foxy trong phòng.
@export var player: Player
## Danh sách các vùng nước do controller điều khiển.
@export var zones: Array[FlatTideZone] = []
# //NLVP sửa: Chạy lần lượt bao nhiêu vùng tùy thứ tự Inspector.
## Chạy từng vùng lần lượt theo thứ tự Zones.
@export var sequential_zones: bool = false
@export_group("Shared Timing")
## Thời gian giữ triều thấp, tính bằng giây.
@export_range(0.1, 120.0, 0.1) var low_duration: float = 12.0
## Thời gian nước dâng từ thấp lên cao; số lớn hơn làm nước dâng chậm hơn.
@export_range(0.1, 30.0, 0.1) var rise_duration: float = 4.0
## Thời gian giữ triều cao, tính bằng giây.
@export_range(0.1, 120.0, 0.1) var high_duration: float = 12.0
## Thời gian nước rút từ cao xuống thấp; số lớn hơn làm nước rút chậm hơn.
@export_range(0.1, 30.0, 0.1) var fall_duration: float = 4.0
@export_group("")
## Số giây báo trước khi nước bắt đầu dâng; đặt 0 để tắt cảnh báo.
@export_range(0.0, 20.0, 0.1) var warning_seconds: float = 3.0
## Số giây vệt cảnh báo mờ dần ngay trước lúc nước dâng.
@export_range(0.0, 3.0, 0.05) var warning_fade_duration: float = 0.5
## Hệ số tốc độ đi bộ trong nước: 1 là bình thường, 0.5 là còn một nửa.
@export_range(0.0, 1.0, 0.01) var flooded_move_multiplier: float = 0.8
## Hệ số quãng đường dash khi bắt đầu trong nước: 0.5 là còn một nửa.
@export_range(0.0, 1.0, 0.01) var flooded_dash_multiplier: float = 0.5
## Khoảng cách từ gốc nhân vật xuống chân để kiểm tra Foxy có đứng trong nước không.
@export_range(0.0, 2.0, 0.01) var player_ground_offset: float = 0.75
## Horizontal speed applied when an advancing wave reaches the player; 0 disables it.
@export_range(0.0, 25.0, 0.1, "suffix:m/s") var wave_knockback_speed: float = 10.0
@export_range(0.05, 2.0, 0.05, "suffix:s") var wave_knockback_duration: float = 0.65

var state: State = State.LOW
var coverage: float = 0.0
var _elapsed: float = 0.0
var _warned: bool = false
var _visual_time: float = 0.0
var _wave_hit_player: bool = false
var _wave_previous_wet: Dictionary[int, bool] = {}
# //NLVP sửa: Vùng đang chạy hoặc vừa kết thúc trước khoảng nghỉ.
var _active_zone_index := 0


func _ready() -> void:
	# //NLVP sửa: Sóng đầu chạy ngay; danh sách quyết định thứ tự các hướng.
	if sequential_zones:
		if zones.is_empty():
			push_warning("FlatTideController: hãy gán Zones để chạy lần lượt.")
			set_physics_process(false)
			return
		var assigned_zones: Array[FlatTideZone] = []
		for zone in zones:
			if not is_instance_valid(zone) or zone in assigned_zones:
				push_warning("FlatTideController: Zones không được trống hoặc trùng nhau.")
				set_physics_process(false)
				return
			assigned_zones.append(zone)
		state = State.RISING
		state_changed.emit(state)
	_apply_coverage()
	_update_player()


func _physics_process(delta: float) -> void:
	_visual_time += delta
	var remaining := delta
	while remaining > 0.0:
		var duration := _phase_duration()
		var step := minf(remaining, duration - _elapsed)
		_elapsed += step
		remaining -= step
		if _elapsed >= duration:
			_enter_state((int(state) + 1) % State.size() as State)
		_apply_coverage()
	_check_warning()
	_update_player()


func is_point_flooded(point: Vector3) -> bool:
	return get_flooded_zone(point) != null


func get_flooded_zone(point: Vector3) -> FlatTideZone:
	for zone in zones:
		if (
			is_instance_valid(zone)
			and _is_zone_active(zone)
			and zone.contains_flooded_point(point)
		):
			return zone
	return null


func _exit_tree() -> void:
	if is_instance_valid(player):
		player.environment_move_speed_multiplier = 1.0
		player.environment_dash_distance_multiplier = 1.0
		player.environment_is_water = false


func _phase_duration() -> float:
	# //NLVP sửa: Chế độ lần lượt dùng thời gian riêng trên từng vùng nước.
	if sequential_zones:
		var zone := zones[_active_zone_index]
		match state:
			State.LOW:
				return maxf(MIN_PHASE_DURATION_SECONDS, zone.rest_duration)
			State.RISING:
				return maxf(MIN_PHASE_DURATION_SECONDS, zone.rise_duration)
			State.HIGH:
				return maxf(MIN_PHASE_DURATION_SECONDS, zone.high_duration)
			_:
				return maxf(MIN_PHASE_DURATION_SECONDS, zone.fall_duration)
	match state:
		State.LOW:
			return maxf(MIN_PHASE_DURATION_SECONDS, low_duration)
		State.RISING:
			return maxf(MIN_PHASE_DURATION_SECONDS, rise_duration)
		State.HIGH:
			return maxf(MIN_PHASE_DURATION_SECONDS, high_duration)
		_:
			return maxf(MIN_PHASE_DURATION_SECONDS, fall_duration)


func _enter_state(next_state: State) -> void:
	# //NLVP sửa: Hết khoảng nghỉ mới chuyển sang vùng tiếp theo.
	if sequential_zones and state == State.LOW and next_state == State.RISING:
		_active_zone_index = (_active_zone_index + 1) % zones.size()
	state = next_state
	_elapsed = 0.0
	if state == State.LOW:
		_warned = false
	if state == State.RISING:
		_wave_hit_player = false
		_wave_previous_wet.clear()
	state_changed.emit(state)


func _apply_coverage() -> void:
	var ratio := clampf(_elapsed / _phase_duration(), 0.0, 1.0)
	ratio = ratio * ratio * (3.0 - 2.0 * ratio)
	match state:
		State.LOW:
			coverage = 0.0
		State.RISING:
			coverage = ratio
		State.HIGH:
			coverage = 1.0
		State.FALLING:
			coverage = 1.0 - ratio
	var warning := state == State.LOW and _warned
	var warning_strength := 1.0
	if warning and warning_fade_duration > 0.0:
		warning_strength = clampf((_phase_duration() - _elapsed) / warning_fade_duration, 0.0, 1.0)
	for zone in zones:
		if is_instance_valid(zone):
			# //NLVP sửa: Vùng chưa tới lượt luôn khô, chỉ báo trước cho vùng kế tiếp.
			var zone_warning := warning and _is_warning_zone(zone)
			if not _is_zone_active(zone):
				zone.set_coverage(0.0, zone_warning, _visual_time, warning_strength)
				continue
			var ground_point := Vector3.ZERO
			var was_wet := false
			var check_wave := state == State.RISING and not _wave_hit_player and is_instance_valid(player)
			if check_wave:
				ground_point = player.global_position + Vector3.DOWN * player_ground_offset
				was_wet = zone.is_point_in_advancing_wave(ground_point)
			zone.set_coverage(
				coverage, zone_warning, _visual_time, warning_strength,
				state == State.RISING, state == State.FALLING
			)
			if check_wave:
				var wet_now := zone.is_point_in_advancing_wave(ground_point)
				var previously_wet: bool = _wave_previous_wet.get(zone.get_instance_id(), false)
				_wave_previous_wet[zone.get_instance_id()] = wet_now
				if wet_now and (not was_wet or not previously_wet):
					_wave_hit_player = true
					player.apply_environment_knockback(
						zone.get_flow_direction(), wave_knockback_speed, wave_knockback_duration
					)
					if wave_knockback_speed > 0.0:
						get_node("/root/ShockwaveController").request_world(
							player.global_position + Vector3.UP,
							SHOCKWAVE_DURATION,
							SHOCKWAVE_STRENGTH,
							SHOCKWAVE_COLOR,
							SHOCKWAVE_RADIUS_PIXELS
						)
	coverage_changed.emit(coverage)


func _check_warning() -> void:
	if state != State.LOW or _warned or warning_seconds <= 0.0:
		return
	var remaining := _phase_duration() - _elapsed
	if remaining <= warning_seconds:
		_warned = true
		for zone in zones:
			if is_instance_valid(zone):
				zone.set_coverage(coverage, _is_warning_zone(zone), _visual_time)
		rising_warned.emit(remaining)


# //NLVP sửa: Dùng chung lịch cho nước, lực đẩy, dấu chân và spawn quái.
func _is_zone_active(zone: FlatTideZone) -> bool:
	return not sequential_zones or zone == zones[_active_zone_index]


# //NLVP sửa: Cảnh báo đúng vùng sắp chạy sau khoảng nghỉ.
func _is_warning_zone(zone: FlatTideZone) -> bool:
	if not sequential_zones:
		return true
	var next_index := (_active_zone_index + 1) % zones.size()
	return zone == zones[next_index]


func _update_player() -> void:
	if is_instance_valid(player):
		var flooded := is_point_flooded(
			player.global_position + Vector3.DOWN * player_ground_offset
		)
		player.environment_is_water = flooded
		player.environment_move_speed_multiplier = (flooded_move_multiplier if flooded else 1.0)
		player.environment_dash_distance_multiplier = flooded_dash_multiplier if flooded else 1.0
