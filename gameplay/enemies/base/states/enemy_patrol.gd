class_name EnemyPatrol
extends EnemyState

## Reusable straight-line Patrol state. Enemy scenes can add this state, omit it,
## or configure its movement, ray checks, and animation.

@export var turn_on_wall: bool = true
@export var turn_at_ledge: bool = true
@export_range(0.0, 10.0, 0.1) var speed_scale: float = 1.0
@export var movement_animation: StringName = &"run"

@export_group("Random Pause")
## Disabled keeps the original continuous patrol behavior.
@export var use_random_pauses: bool = false
@export_range(0.05, 60.0, 0.05, "suffix:s") var move_duration_min: float = 1.0
@export_range(0.05, 60.0, 0.05, "suffix:s") var move_duration_max: float = 3.0
@export_range(0.05, 60.0, 0.05, "suffix:s") var pause_duration_min: float = 0.5
@export_range(0.05, 60.0, 0.05, "suffix:s") var pause_duration_max: float = 2.0
## Leave empty to retain the current visual while stopped.
@export var pause_animation: StringName = &"idle"

@export_group("Random Axis Change")
## Alternates movement between the horizontal (left/right) and vertical (up/down) axes.
@export var use_random_axis_changes: bool = false
@export_range(0.05, 60.0, 0.05, "suffix:s") var axis_change_duration_min: float = 1.5
@export_range(0.05, 60.0, 0.05, "suffix:s") var axis_change_duration_max: float = 4.0

var _random := RandomNumberGenerator.new()
var _is_moving: bool = true
var _phase_remaining: float = 0.0
var _axis_change_remaining: float = 0.0


func _enter() -> void:
	_random.randomize()
	_set_moving_phase()
	_reset_axis_change_timer()


func _update(delta: float) -> void:
	if _is_moving:
		_update_random_axis_change(delta)
		enemy.move_forward(delta, speed_scale)
		enemy.play_directional_animation(movement_animation)
		if turn_on_wall and enemy.is_front_blocked():
			enemy.turn_around()
		elif turn_at_ledge and not enemy.is_ground_ahead():
			enemy.turn_around()
	else:
		enemy.stop_movement(delta)
		if not pause_animation.is_empty():
			enemy.play_directional_animation(pause_animation)

	if use_random_pauses:
		_update_random_phase(delta)


func _set_moving_phase() -> void:
	_is_moving = true
	_phase_remaining = _random_duration(move_duration_min, move_duration_max)


func _set_paused_phase() -> void:
	_is_moving = false
	_phase_remaining = _random_duration(pause_duration_min, pause_duration_max)


func _update_random_phase(delta: float) -> void:
	_phase_remaining -= maxf(0.0, delta)
	if _phase_remaining > 0.0001:
		return
	if _is_moving:
		_set_paused_phase()
	else:
		_set_moving_phase()


func _random_duration(minimum: float, maximum: float) -> float:
	return _random.randf_range(minf(minimum, maximum), maxf(minimum, maximum))


func _reset_axis_change_timer() -> void:
	_axis_change_remaining = _random_duration(axis_change_duration_min, axis_change_duration_max)


func _update_random_axis_change(delta: float) -> void:
	if not use_random_axis_changes:
		return
	_axis_change_remaining -= maxf(0.0, delta)
	if _axis_change_remaining > 0.0001:
		return
	_change_to_orthogonal_axis()
	_reset_axis_change_timer()


func _change_to_orthogonal_axis() -> void:
	var facing := enemy.last_facing_direction
	if absf(facing.x) >= absf(facing.z):
		enemy.face_direction(Vector3.FORWARD if _random.randi_range(0, 1) == 0 else Vector3.BACK)
		return
	enemy.face_direction(Vector3.LEFT if _random.randi_range(0, 1) == 0 else Vector3.RIGHT)
