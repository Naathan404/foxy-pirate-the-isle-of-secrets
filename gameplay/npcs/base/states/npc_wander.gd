class_name NpcWander
extends NpcState

## Generic patrol that works without an external navigation graph. Scenes can
## enable the two base raycasts to turn at walls and ledges.

var _random := RandomNumberGenerator.new()
var _moving := true
var _destination := Vector3.ZERO


func _enter() -> void:
	_random.randomize()
	_set_moving_phase()


func _update(delta: float) -> void:
	var behavior := npc.get_npc_data()
	if _moving:
		if npc.has_wander_bounds():
			_update_bounded_movement(delta, behavior.wander_speed_scale)
		else:
			_update_unbounded_movement(delta, behavior.wander_speed_scale)
		npc.play_directional_animation(&"walk")
	else:
		npc.stop_movement(delta)
		npc.play_directional_animation(&"idle")

	timer -= maxf(0.0, delta)
	if timer > 0.0:
		return
	if _moving:
		_set_resting_phase()
	else:
		_set_moving_phase()


func _set_moving_phase() -> void:
	_moving = true
	if npc.has_wander_bounds():
		_destination = _get_random_destination()
	var behavior := npc.get_npc_data()
	timer = _random.randf_range(
		minf(behavior.wander_move_duration_min, behavior.wander_move_duration_max),
		maxf(behavior.wander_move_duration_min, behavior.wander_move_duration_max)
	)


func _set_resting_phase() -> void:
	_moving = false
	var behavior := npc.get_npc_data()
	timer = _random.randf_range(
		minf(behavior.wander_rest_duration_min, behavior.wander_rest_duration_max),
		maxf(behavior.wander_rest_duration_min, behavior.wander_rest_duration_max)
	)


func _update_bounded_movement(delta: float, speed_scale: float) -> void:
	var direction := _destination - npc.global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.04:
		_set_resting_phase()
		return

	npc.move_in_direction(direction, delta, speed_scale)
	var behavior := npc.get_npc_data()
	if behavior.wander_turn_on_wall and npc.is_front_blocked():
		_set_moving_phase()
	elif behavior.wander_turn_at_ledge and not npc.is_ground_ahead():
		_set_moving_phase()


func _update_unbounded_movement(delta: float, speed_scale: float) -> void:
	npc.move_forward(delta, speed_scale)
	var behavior := npc.get_npc_data()
	if behavior.wander_turn_on_wall and npc.is_front_blocked():
		npc.turn_around()
	elif behavior.wander_turn_at_ledge and not npc.is_ground_ahead():
		npc.turn_around()


func _get_random_destination() -> Vector3:
	var angle := _random.randf_range(0.0, TAU)
	var radius := sqrt(_random.randf()) * npc.get_wander_radius()
	return npc.get_wander_origin() + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
