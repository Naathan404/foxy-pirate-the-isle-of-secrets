class_name BoundedFollowCamera3D
extends Camera3D

@export_group("Movement Bob")
@export var movement_bob_enabled: bool = true
@export_range(0.0, 0.5, 0.005) var bob_horizontal_amplitude: float = 0.035
@export_range(0.0, 0.5, 0.005) var bob_vertical_amplitude: float = 0.06
@export_range(0.1, 8.0, 0.1) var bob_cycles_per_second: float = 2.4
@export_range(0.1, 30.0, 0.1) var bob_blend_speed: float = 9.0
@export_range(0.0, 5.0, 0.1) var bob_minimum_speed: float = 0.5

@export_group("Dash Follow")
@export var dash_follow_enabled: bool = true
@export_range(0.0, 0.3, 0.01, "suffix:s") var dash_hold_duration: float = 0.08
@export_range(1.0, 30.0, 0.5) var dash_catch_up_speed: float = 10.0
@export_range(0.1, 10.0, 0.1) var dash_max_lag_distance: float = 3.0
@export_range(0.001, 0.5, 0.001) var dash_settle_distance: float = 0.02

## Temporary world-space framing offset; still clamped by camera bounds.
var combat_focus_offset: Vector3 = Vector3.ZERO
var _follow_offset: Vector3
var _bounds: CameraBounds3D
var _player: Player
var _dialogue_override := false
var _bob_phase: float = 0.0
var _bob_weight: float = 0.0
var _dash_follow_active := false
var _dash_hold_remaining := 0.0
var _dash_camera_position := Vector3.ZERO
var _cinematic_tween: Tween


func _ready() -> void:
	_follow_offset = position
	process_priority = 100
	_player = get_parent() as Player
	if is_instance_valid(_player):
		_player.dash_started.connect(_on_dash_started)
	if is_instance_valid(_player) and is_instance_valid(_player.get_parent()):
		_bounds = _player.get_parent().get_node_or_null("CameraBounds") as CameraBounds3D


func _process(delta: float) -> void:
	if not _dialogue_override:
		# A boundary clamp changes a child camera's local position. Rebuild the
		# desired follow offset each frame so it follows when Foxy moves back.
		position = _follow_offset + _get_movement_bob(delta)
		var follow_position := _update_dash_follow(global_position, delta)
		global_position = follow_position + combat_focus_offset
	set_bounded_global_position(global_position)


func _on_dash_started() -> void:
	if not dash_follow_enabled or _dialogue_override:
		return
	# Capture the displayed camera position before dash movement; combat focus is
	# applied separately so cinematic framing can continue during the delay.
	_dash_camera_position = global_position - combat_focus_offset
	_dash_hold_remaining = dash_hold_duration
	_dash_follow_active = true


func _update_dash_follow(target: Vector3, delta: float) -> Vector3:
	if not dash_follow_enabled or not _dash_follow_active:
		_dash_follow_active = false
		return target
	var horizontal_lag := (
		Vector3(_dash_camera_position.x - target.x, 0.0, _dash_camera_position.z - target.z)
		. limit_length(dash_max_lag_distance)
	)
	_dash_camera_position = target + horizontal_lag
	var catch_up_delta := maxf(0.0, delta - _dash_hold_remaining)
	_dash_hold_remaining = maxf(0.0, _dash_hold_remaining - delta)
	if catch_up_delta > 0.0:
		var blend := 1.0 - exp(-dash_catch_up_speed * catch_up_delta)
		_dash_camera_position = _dash_camera_position.lerp(target, blend)
	if (
		_dash_hold_remaining <= 0.0
		and _dash_camera_position.distance_to(target) <= dash_settle_distance
	):
		_dash_follow_active = false
		return target
	return _dash_camera_position


func _reset_dash_follow() -> void:
	_dash_follow_active = false
	_dash_hold_remaining = 0.0


func _get_movement_bob(delta: float) -> Vector3:
	var speed := 0.0
	if (
		movement_bob_enabled
		and is_instance_valid(_player)
		and is_instance_valid(_player.fsm)
		and _player.data != null
		and not _player.dead
		and not _player.is_gameplay_input_blocked()
		and not _player.environment_is_water
		and _player.is_on_floor()
		and _player.fsm.current_state == _player.fsm.states.get("run")
		and not _player.move_direction.is_zero_approx()
	):
		var movement := _player.get_real_velocity()
		movement.y = 0.0
		speed = movement.length()

	var speed_ratio := 0.0
	if speed > bob_minimum_speed and _player.data.move_speed > 0.0:
		speed_ratio = clampf(speed / _player.data.move_speed, 0.0, 1.0)
		_bob_phase = fposmod(_bob_phase + TAU * bob_cycles_per_second * speed_ratio * delta, TAU)
	var blend := 1.0 - exp(-bob_blend_speed * delta)
	_bob_weight = lerpf(_bob_weight, speed_ratio, blend)
	return (
		Vector3(
			sin(_bob_phase) * bob_horizontal_amplitude,
			cos(_bob_phase * 2.0) * bob_vertical_amplitude,
			0.0
		)
		* _bob_weight
	)


func snap_to_follow() -> void:
	_dialogue_override = false
	_reset_dash_follow()
	_bob_weight = 0.0
	position = _follow_offset
	set_bounded_global_position(global_position)
	reset_physics_interpolation()


func begin_dialogue_override() -> void:
	_dialogue_override = true
	_reset_dash_follow()
	_bob_weight = 0.0


func end_dialogue_override() -> void:
	_dialogue_override = false
	_reset_dash_follow()
	_bob_weight = 0.0
	position = _follow_offset
	set_bounded_global_position(global_position)


func play_focus_cinematic(
	world_target: Vector3,
	target_fov: float,
	restore_fov: float,
	in_seconds: float,
	hold_seconds: float,
	out_seconds: float
) -> void:
	if _cinematic_tween != null and _cinematic_tween.is_valid():
		_cinematic_tween.kill()
	begin_dialogue_override()
	_cinematic_tween = create_tween()
	_cinematic_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_cinematic_tween.tween_property(self, "fov", target_fov, maxf(0.05, in_seconds))
	_cinematic_tween.parallel().tween_method(
		set_bounded_global_position,
		global_position,
		get_target_follow_position(world_target),
		maxf(0.05, in_seconds)
	)
	_cinematic_tween.tween_interval(maxf(0.0, hold_seconds))
	_cinematic_tween.tween_callback(restore_cinematic.bind(restore_fov, out_seconds))


func restore_cinematic(restore_fov: float, duration_seconds: float = 0.0) -> void:
	if _cinematic_tween != null and _cinematic_tween.is_valid():
		_cinematic_tween.kill()
	if duration_seconds <= 0.0 or not is_inside_tree():
		fov = restore_fov
		end_dialogue_override()
		return
	var return_from := global_position
	_cinematic_tween = create_tween().set_parallel(true)
	_cinematic_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cinematic_tween.tween_property(self, "fov", restore_fov, duration_seconds)
	_cinematic_tween.tween_method(
		func(progress: float) -> void:
			var dest := get_follow_world_position()
			set_bounded_global_position(return_from.lerp(dest, progress)),
		0.0,
		1.0,
		duration_seconds
	)
	_cinematic_tween.set_parallel(false)
	_cinematic_tween.tween_callback(end_dialogue_override)


func get_follow_world_position() -> Vector3:
	if is_instance_valid(_player):
		return _player.global_position + _follow_offset
	return global_position


func get_target_follow_position(world_target: Vector3) -> Vector3:
	return world_target + _follow_offset


func set_bounded_global_position(desired_position: Vector3) -> void:
	if is_instance_valid(_bounds):
		global_position = _bounds.clamp_camera_position(self, desired_position)
	else:
		global_position = desired_position
