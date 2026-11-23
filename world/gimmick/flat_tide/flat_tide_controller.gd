class_name FlatTideController
extends Node3D
## Drives the shared tide cycle for its zones and the "tide surge" interaction: the advancing
## waterline knocks the player back once per rise (or carries them if they dash with the flow)
## and staggers enemies it sweeps over.

signal state_changed(new_state: State)
signal coverage_changed(value: float)
signal rising_warned(seconds_remaining: float)
## The player dashed with the flow as the wave arrived and rode it instead of being knocked.
signal wave_ridden(player: Player)
## An enemy was caught by the advancing wave and staggered.
signal enemy_swept(enemy: EnemyBase)

enum State { LOW, RISING, HIGH, FALLING }

const SHOCKWAVE_DURATION := 0.3
const SHOCKWAVE_STRENGTH := 0.005
const SHOCKWAVE_COLOR := Color("78dfff")
const SHOCKWAVE_RADIUS_PIXELS := 110.0
const RIDE_SHOCKWAVE_COLOR := Color("e8fff4")
const RIDE_SHOCKWAVE_RADIUS_PIXELS := 160.0
## Higher than ordinary hits so a sweep interrupts attacks, below charm grapple (60).
const ENEMY_SWEEP_STATE_PRIORITY := 55
const BOSS_GROUP := &"boss"
const ENEMY_GROUP := &"enemy"
## Share of the warning used to fade the screen overlay in.
const WARNING_FADE_IN_PROGRESS := 0.15
## Speed of the bands drifting inward on the overlay, relative to the pulse rate.
const WARNING_FLOW_SPEED_RATIO := 0.5
## Zones whose screen directions are this aligned (cosine) share one warning edge.
const WARNING_SAME_SIDE_DOT := 0.9

# //NLVP sửa: Giữ mỗi pha có thời lượng hợp lệ.
const MIN_PHASE_DURATION_SECONDS := 0.1

## Nhân vật chịu ảnh hưởng của nước; gán node Foxy trong phòng.
@export var player: Player
## Danh sách các vùng nước do controller điều khiển.
@export var zones: Array[FlatTideZone] = []
# //NLVP sửa: Chạy lần lượt bao nhiêu vùng tùy thứ tự Inspector.
## Chạy từng vùng lần lượt theo thứ tự Zones.
@export var sequential_zones: bool = false
## Let an encounter start each tide explicitly, holding LOW between waves.
@export var externally_advanced: bool = false
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
## Số giây cảnh báo trên màn hình mờ dần sau khi nước bắt đầu dâng.
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

@export_group("Warning Overlay")
## Viền đỏ nhấp nháy ở cạnh màn hình phía sóng sắp tràn vào, trong lúc báo trước.
@export var warning_overlay_enabled: bool = true
## Màu viền cảnh báo.
@export var warning_color: Color = Color(0.95, 0.1, 0.06, 1.0)
## Độ đậm tối đa của viền cảnh báo.
@export_range(0.0, 1.0, 0.01) var warning_overlay_strength: float = 0.75
## Độ rộng vùng sáng tính từ cạnh màn hình (1 là tới giữa màn hình).
@export_range(0.05, 1.0, 0.01) var warning_edge_width: float = 0.38
## Nhịp nhấp nháy lúc cảnh báo bắt đầu (lần mỗi giây); giữ thấp để dịu mắt.
@export_range(0.1, 4.0, 0.05, "suffix:Hz") var warning_pulse_start_hz: float = 1.0
## Nhịp nhấp nháy ngay trước khi nước dâng.
@export_range(0.1, 4.0, 0.05, "suffix:Hz") var warning_pulse_end_hz: float = 2.2
## Chỉ cảnh báo khi Foxy ở trong vùng có thể ngập hoặc cách vùng không quá khoảng này.
@export_range(0.0, 30.0, 0.5, "suffix:m") var warning_player_margin: float = 6.0

@export_group("Surge Ride")
## Dash xuôi dòng ngay lúc sóng tới để cưỡi sóng: không bị choáng, được đẩy nhanh theo dòng.
@export var ride_enabled: bool = true
## Dash xuôi dòng phải bắt đầu trong khoảng này trước khi sóng đuổi kịp (gồm cả thời gian dash).
@export_range(0.0, 2.0, 0.05, "suffix:s") var ride_window_seconds: float = 1.2
## Độ trùng hướng tối thiểu giữa hướng dash và dòng chảy (1 là trùng hoàn toàn).
@export_range(0.0, 1.0, 0.05) var ride_alignment: float = 0.5
## Tốc độ được sóng mang đi khi cưỡi sóng.
@export_range(0.0, 30.0, 0.5, "suffix:m/s") var ride_speed: float = 15.0
## Thời gian được sóng mang đi khi cưỡi sóng.
@export_range(0.05, 3.0, 0.05, "suffix:s") var ride_duration: float = 0.9

@export_group("Surge Sweep")
## Sóng đang dâng làm choáng và cuốn enemy nằm trên đường đi; boss không bị ảnh hưởng.
@export var sweep_enemies: bool = true
## Thời gian enemy bị choáng khi bị sóng cuốn.
@export_range(0.0, 5.0, 0.05, "suffix:s") var enemy_sweep_stun_seconds: float = 1.2
## Hệ số lực đẩy enemy so với lực đẩy khi trúng đòn thông thường của enemy đó.
@export_range(0.0, 5.0, 0.05) var enemy_sweep_knockback_multiplier: float = 2.0
## Khoảng từ gốc enemy xuống chân khi kiểm tra enemy có bị sóng chạm không.
@export_range(0.0, 2.0, 0.01, "suffix:m") var enemy_ground_offset: float = 0.0

var state: State = State.LOW
var coverage: float = 0.0
var _elapsed: float = 0.0
var _warned: bool = false
var _visual_time: float = 0.0
var _wave_hit_player: bool = false
var _wave_previous_wet: Dictionary[int, bool] = {}
var _swept_enemies: Dictionary[int, bool] = {}
var _last_dash_time: float = -INF
var _last_dash_direction: Vector3 = Vector3.ZERO
var _warning_overlay: FlatTideWarningOverlay

# //NLVP sửa: Vùng đang chạy hoặc vừa kết thúc trước khoảng nghỉ.
var _active_zone_index := 0
var _cycle_waiting := false


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
		state = State.LOW if externally_advanced else State.RISING
		if externally_advanced:
			_active_zone_index = zones.size() - 1
			_cycle_waiting = true
		state_changed.emit(state)
	if is_instance_valid(player) and not player.dash_started.is_connected(_on_player_dash_started):
		player.dash_started.connect(_on_player_dash_started)
	if warning_overlay_enabled:
		_warning_overlay = FlatTideWarningOverlay.new()
		_warning_overlay.name = "WarningOverlay"
		add_child(_warning_overlay)
		_warning_overlay.configure(warning_color, warning_edge_width)
	_apply_coverage()
	_update_player()


func _physics_process(delta: float) -> void:
	_visual_time += delta
	var remaining := delta
	while remaining > 0.0 and not _cycle_waiting:
		var duration := _phase_duration()
		var step := minf(remaining, duration - _elapsed)
		_elapsed += step
		remaining -= step
		if _elapsed >= duration:
			_enter_state((int(state) + 1) % State.size() as State)
		_apply_coverage()
	_check_warning()
	_update_warning_overlay(delta)
	_update_player()


func is_point_flooded(point: Vector3) -> bool:
	return get_flooded_zone(point) != null


## Start exactly one tide; after falling it stays dry until requested again.
func request_cycle() -> bool:
	if not externally_advanced or state != State.LOW or not _cycle_waiting:
		return false
	_cycle_waiting = false
	_enter_state(State.RISING)
	return true


## Finish a controlled tide immediately so a cleared encounter can advance or end.
func finish_cycle() -> void:
	if not externally_advanced:
		return
	_enter_state(State.LOW)
	_apply_coverage()
	_update_warning_overlay(0.0)
	_update_player()


func get_flooded_zone(point: Vector3) -> FlatTideZone:
	for zone in zones:
		if is_instance_valid(zone) and _is_zone_active(zone) and zone.contains_flooded_point(point):
			return zone
	return null


func _exit_tree() -> void:
	if is_instance_valid(player):
		player.environment_move_speed_multiplier = 1.0
		player.environment_dash_distance_multiplier = 1.0
		player.environment_is_water = false
		if player.dash_started.is_connected(_on_player_dash_started):
			player.dash_started.disconnect(_on_player_dash_started)


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
		_cycle_waiting = externally_advanced
	if state == State.RISING:
		_wave_hit_player = false
		_wave_previous_wet.clear()
		_swept_enemies.clear()
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
	var rising := state == State.RISING
	var enemies: Array[EnemyBase] = []
	if rising and sweep_enemies:
		enemies = _sweep_candidates()
	for zone in zones:
		if not is_instance_valid(zone):
			continue
		if not _is_zone_active(zone):
			zone.set_coverage(0.0, _visual_time)
			continue
		var check_wave := rising and not _wave_hit_player and is_instance_valid(player)
		var ground_point := Vector3.ZERO
		var was_wet := false
		if check_wave:
			ground_point = player.global_position + Vector3.DOWN * player_ground_offset
			was_wet = zone.is_point_in_advancing_wave(ground_point)
		var enemies_wet_before: Array[bool] = []
		for enemy: EnemyBase in enemies:
			enemies_wet_before.append(zone.is_point_in_advancing_wave(_enemy_ground(enemy)))
		zone.set_coverage(coverage, _visual_time, rising, state == State.FALLING)
		if check_wave:
			var wet_now := zone.is_point_in_advancing_wave(ground_point)
			var previously_wet: bool = _wave_previous_wet.get(zone.get_instance_id(), false)
			_wave_previous_wet[zone.get_instance_id()] = wet_now
			if wet_now and (not was_wet or not previously_wet):
				_wave_hit_player = true
				_hit_player(zone.get_flow_direction())
		for index in range(enemies.size()):
			var enemy: EnemyBase = enemies[index]
			# Overlapping zones must not sweep the same enemy twice in one rise.
			if enemies_wet_before[index] or _swept_enemies.has(enemy.get_instance_id()):
				continue
			if zone.is_point_in_advancing_wave(_enemy_ground(enemy)):
				_sweep_enemy(enemy, zone.get_flow_direction())
	coverage_changed.emit(coverage)


func _hit_player(flow: Vector3) -> void:
	if _is_riding(flow):
		if player.apply_environment_push(flow, ride_speed, ride_duration):
			_request_shockwave(RIDE_SHOCKWAVE_COLOR, RIDE_SHOCKWAVE_RADIUS_PIXELS)
			wave_ridden.emit(player)
		return
	player.apply_environment_knockback(flow, wave_knockback_speed, wave_knockback_duration)
	if wave_knockback_speed > 0.0:
		_request_shockwave(SHOCKWAVE_COLOR, SHOCKWAVE_RADIUS_PIXELS)


func _is_riding(flow: Vector3) -> bool:
	if not ride_enabled or ride_speed <= 0.0 or player.dead:
		return false
	if _visual_time - _last_dash_time > ride_window_seconds:
		return false
	return _last_dash_direction.dot(flow) >= ride_alignment


func _on_player_dash_started() -> void:
	if not is_instance_valid(player):
		return
	var direction := player.last_facing_direction
	direction.y = 0.0
	_last_dash_direction = direction.normalized() if not direction.is_zero_approx() else direction
	_last_dash_time = _visual_time


func _request_shockwave(color: Color, radius_pixels: float) -> void:
	var shockwave := get_node_or_null("/root/ShockwaveController")
	if shockwave == null:
		return
	shockwave.request_world(
		player.global_position + Vector3.UP,
		SHOCKWAVE_DURATION,
		SHOCKWAVE_STRENGTH,
		color,
		radius_pixels
	)


## Living, non-boss enemies that this rise has not swept yet.
func _sweep_candidates() -> Array[EnemyBase]:
	var result: Array[EnemyBase] = []
	if not is_inside_tree():
		return result
	for node in get_tree().get_nodes_in_group(ENEMY_GROUP):
		var enemy := node as EnemyBase
		if enemy == null or enemy.dead or enemy.is_in_group(BOSS_GROUP):
			continue
		if _swept_enemies.has(enemy.get_instance_id()):
			continue
		result.append(enemy)
	return result


func _enemy_ground(enemy: EnemyBase) -> Vector3:
	return enemy.global_position + Vector3.DOWN * enemy_ground_offset


## Uses the same stun/knockback path as the charm grapple, so the enemy's own resistances apply.
func _sweep_enemy(enemy: EnemyBase, flow: Vector3) -> void:
	_swept_enemies[enemy.get_instance_id()] = true
	enemy.pending_hit_direction = flow
	enemy.pending_knockback_multiplier = enemy_sweep_knockback_multiplier
	enemy.pending_charm_stun_seconds = maxf(
		enemy.pending_charm_stun_seconds, enemy_sweep_stun_seconds
	)
	if not enemy.request_state(&"hit", ENEMY_SWEEP_STATE_PRIORITY):
		enemy.pending_charm_stun_seconds = 0.0
		enemy.pending_knockback_multiplier = 1.0
		return
	enemy_swept.emit(enemy)


## 0 when the warning starts, 1 when the water begins to rise.
func _warning_progress() -> float:
	if state != State.LOW or not _warned or warning_seconds <= 0.0:
		return 0.0
	var remaining := _phase_duration() - _elapsed
	return clampf(1.0 - remaining / warning_seconds, 0.0, 1.0)


func _check_warning() -> void:
	if _cycle_waiting or state != State.LOW or _warned or warning_seconds <= 0.0:
		return
	var remaining := _phase_duration() - _elapsed
	if remaining <= warning_seconds:
		_warned = true
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


## 0..1 strength of the screen warning: fades in after the warning starts and out once the
## water is already rising. `_warned` stays set until the next low tide begins.
func _warning_overlay_amount() -> float:
	if not _warned:
		return 0.0
	if state == State.LOW:
		return smoothstep(0.0, WARNING_FADE_IN_PROGRESS, _warning_progress())
	if state == State.RISING and warning_fade_duration > 0.0:
		return clampf(1.0 - _elapsed / warning_fade_duration, 0.0, 1.0)
	return 0.0


func _update_warning_overlay(delta: float) -> void:
	if not is_instance_valid(_warning_overlay):
		return
	var amount := _warning_overlay_amount()
	var directions := PackedVector2Array()
	var strengths := PackedFloat32Array()
	if amount > 0.0:
		_collect_warning_directions(directions, strengths)
	if directions.is_empty():
		_warning_overlay.hide_warning()
		return
	for index in range(strengths.size()):
		strengths[index] *= amount * warning_overlay_strength
	var progress := 1.0 if state == State.RISING else _warning_progress()
	var pulse_hz := lerpf(warning_pulse_start_hz, warning_pulse_end_hz, progress)
	_warning_overlay.show_warning(
		directions, strengths, pulse_hz, pulse_hz * WARNING_FLOW_SPEED_RATIO, delta
	)


## One screen direction (y down) toward the sea side of each zone near the player, with a
## strength that grows as the player gets closer. Zones whose water comes from the same side
## share one edge glow. Empty when the player is far from every zone or there is no camera.
func _collect_warning_directions(
	directions: PackedVector2Array, strengths: PackedFloat32Array
) -> void:
	if not is_instance_valid(player) or player.dead:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null or camera.is_position_behind(player.global_position):
		return
	var origin := player.global_position
	for zone in zones:
		if not is_instance_valid(zone):
			continue
		if state == State.LOW and not _is_warning_zone(zone):
			continue
		if state == State.RISING and not _is_zone_active(zone):
			continue
		var distance := zone.get_distance_to_area(origin)
		if distance > warning_player_margin:
			continue
		var weight := 1.0 - distance / maxf(warning_player_margin, 1.0)
		var sea_point := origin - zone.get_flow_direction()
		if camera.is_position_behind(sea_point):
			continue
		var screen := camera.unproject_position(sea_point) - camera.unproject_position(origin)
		if screen.is_zero_approx():
			continue
		screen = screen.normalized()
		var merged := false
		for index in range(directions.size()):
			if directions[index].dot(screen) >= WARNING_SAME_SIDE_DOT:
				strengths[index] = maxf(strengths[index], weight)
				merged = true
				break
		if not merged:
			directions.append(screen)
			strengths.append(weight)


func _update_player() -> void:
	if is_instance_valid(player):
		var flooded := is_point_flooded(
			player.global_position + Vector3.DOWN * player_ground_offset
		)
		player.environment_is_water = flooded
		player.environment_move_speed_multiplier = (flooded_move_multiplier if flooded else 1.0)
		player.environment_dash_distance_multiplier = flooded_dash_multiplier if flooded else 1.0
