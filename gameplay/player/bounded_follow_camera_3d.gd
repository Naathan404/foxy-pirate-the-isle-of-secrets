class_name BoundedFollowCamera3D
extends Camera3D

@export_group("Movement Bob")
@export var movement_bob_enabled: bool = true
@export_range(0.0, 0.5, 0.005) var bob_horizontal_amplitude: float = 0.035
@export_range(0.0, 0.5, 0.005) var bob_vertical_amplitude: float = 0.06
@export_range(0.1, 8.0, 0.1) var bob_cycles_per_second: float = 2.4
@export_range(0.1, 30.0, 0.1) var bob_blend_speed: float = 9.0
@export_range(0.0, 5.0, 0.1) var bob_minimum_speed: float = 0.5

var _follow_offset: Vector3
var _bounds: CameraBounds3D
var _player: Player
var _dialogue_override := false
var _bob_phase: float = 0.0
var _bob_weight: float = 0.0


func _ready() -> void:
	_follow_offset = position
	process_priority = 100
	_player = get_parent() as Player
	if is_instance_valid(_player) and is_instance_valid(_player.get_parent()):
		_bounds = _player.get_parent().get_node_or_null("CameraBounds") as CameraBounds3D


func _process(delta: float) -> void:
	if not _dialogue_override:
		# A boundary clamp changes a child camera's local position. Rebuild the
		# desired follow offset each frame so it follows when Foxy moves back.
		position = _follow_offset + _get_movement_bob(delta)
	set_bounded_global_position(global_position)


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
		_bob_phase = fposmod(
			_bob_phase + TAU * bob_cycles_per_second * speed_ratio * delta, TAU
		)
	var blend := 1.0 - exp(-bob_blend_speed * delta)
	_bob_weight = lerpf(_bob_weight, speed_ratio, blend)
	return Vector3(
		sin(_bob_phase) * bob_horizontal_amplitude,
		cos(_bob_phase * 2.0) * bob_vertical_amplitude,
		0.0
	) * _bob_weight


func snap_to_follow() -> void:
	_dialogue_override = false
	_bob_weight = 0.0
	position = _follow_offset
	set_bounded_global_position(global_position)
	reset_physics_interpolation()


func begin_dialogue_override() -> void:
	_dialogue_override = true
	_bob_weight = 0.0


func end_dialogue_override() -> void:
	_dialogue_override = false
	_bob_weight = 0.0
	position = _follow_offset
	set_bounded_global_position(global_position)


func set_bounded_global_position(desired_position: Vector3) -> void:
	if is_instance_valid(_bounds):
		global_position = _bounds.clamp_camera_position(self, desired_position)
	else:
		global_position = desired_position
