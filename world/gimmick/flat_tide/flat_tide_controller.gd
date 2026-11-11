class_name FlatTideController
extends Node3D

signal state_changed(new_state: State)
signal coverage_changed(value: float)
signal rising_warned(seconds_remaining: float)

enum State { LOW, RISING, HIGH, FALLING }

## Nhân vật chịu ảnh hưởng của nước; gán node Foxy trong phòng.
@export var player: Player
## Danh sách các vùng nước cùng chạy theo chu kỳ thủy triều này.
@export var zones: Array[FlatTideZone] = []
## Thời gian giữ triều thấp, tính bằng giây.
@export_range(0.1, 120.0, 0.1) var low_duration: float = 12.0
## Thời gian nước dâng từ thấp lên cao; số lớn hơn làm nước dâng chậm hơn.
@export_range(0.1, 30.0, 0.1) var rise_duration: float = 4.0
## Thời gian giữ triều cao, tính bằng giây.
@export_range(0.1, 120.0, 0.1) var high_duration: float = 12.0
## Thời gian nước rút từ cao xuống thấp; số lớn hơn làm nước rút chậm hơn.
@export_range(0.1, 30.0, 0.1) var fall_duration: float = 4.0
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

var state: State = State.LOW
var coverage: float = 0.0
var _elapsed: float = 0.0
var _warned: bool = false
var _visual_time: float = 0.0


func _ready() -> void:
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
		if is_instance_valid(zone) and zone.contains_flooded_point(point):
			return zone
	return null


func _exit_tree() -> void:
	if is_instance_valid(player):
		player.environment_move_speed_multiplier = 1.0
		player.environment_dash_distance_multiplier = 1.0
		player.environment_is_water = false


func _phase_duration() -> float:
	match state:
		State.LOW:
			return maxf(0.1, low_duration)
		State.RISING:
			return maxf(0.1, rise_duration)
		State.HIGH:
			return maxf(0.1, high_duration)
		_:
			return maxf(0.1, fall_duration)


func _enter_state(next_state: State) -> void:
	state = next_state
	_elapsed = 0.0
	if state == State.LOW:
		_warned = false
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
			zone.set_coverage(coverage, warning, _visual_time, warning_strength)
	coverage_changed.emit(coverage)


func _check_warning() -> void:
	if state != State.LOW or _warned or warning_seconds <= 0.0:
		return
	var remaining := _phase_duration() - _elapsed
	if remaining <= warning_seconds:
		_warned = true
		for zone in zones:
			if is_instance_valid(zone):
				zone.set_coverage(coverage, true, _visual_time)
		rising_warned.emit(remaining)


func _update_player() -> void:
	if is_instance_valid(player):
		var flooded := is_point_flooded(
			player.global_position + Vector3.DOWN * player_ground_offset
		)
		player.environment_is_water = flooded
		player.environment_move_speed_multiplier = (flooded_move_multiplier if flooded else 1.0)
		player.environment_dash_distance_multiplier = flooded_dash_multiplier if flooded else 1.0
