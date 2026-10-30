class_name MushroomWander
extends NpcState

## Mushroom-specific wandering. Its tuning belongs to MushroomNpc rather than
## BaseNpc so stationary NPCs do not carry patrol configuration.

var _random := RandomNumberGenerator.new()
var _moving := true
var _destination := Vector3.ZERO


func _enter() -> void:
	_random.randomize()
	var mushroom := npc as MushroomNpc
	if mushroom == null:
		push_error("MushroomWander must be used by MushroomNpc")
		return
	var behavior := mushroom.get_mushroom_data()
	if behavior == null:
		push_error("MushroomWander requires MushroomNpcData")
		return
	_set_moving_phase(mushroom, behavior)


func _update(delta: float) -> void:
	var mushroom := npc as MushroomNpc
	if mushroom == null:
		return
	var behavior := mushroom.get_mushroom_data()
	if behavior == null:
		return
	if _moving:
		if _has_bounds(behavior):
			_update_bounded_movement(mushroom, behavior, delta)
		else:
			_update_unbounded_movement(mushroom, behavior, delta)
		mushroom.play_directional_animation(&"walk")
	else:
		mushroom.stop_movement(delta)
		mushroom.play_directional_animation(&"idle")

	timer -= maxf(0.0, delta)
	if timer > 0.0:
		return
	if _moving:
		_set_resting_phase(behavior)
	else:
		_set_moving_phase(mushroom, behavior)


func _set_moving_phase(mushroom: MushroomNpc, behavior: MushroomNpcData) -> void:
	_moving = true
	if _has_bounds(behavior):
		_destination = _get_random_destination(mushroom, behavior)
	timer = _random.randf_range(
		minf(behavior.wander_move_duration_min, behavior.wander_move_duration_max),
		maxf(behavior.wander_move_duration_min, behavior.wander_move_duration_max)
	)


func _set_resting_phase(behavior: MushroomNpcData) -> void:
	_moving = false
	timer = _random.randf_range(
		minf(behavior.wander_rest_duration_min, behavior.wander_rest_duration_max),
		maxf(behavior.wander_rest_duration_min, behavior.wander_rest_duration_max)
	)


func _update_bounded_movement(
	mushroom: MushroomNpc, behavior: MushroomNpcData, delta: float
) -> void:
	var direction := _destination - mushroom.global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.04:
		_set_resting_phase(behavior)
		return

	mushroom.move_in_direction(direction, delta, behavior.wander_speed_scale)
	if behavior.wander_turn_on_wall and mushroom.is_front_blocked():
		_set_moving_phase(mushroom, behavior)
	elif behavior.wander_turn_at_ledge and not mushroom.is_ground_ahead():
		_set_moving_phase(mushroom, behavior)


func _update_unbounded_movement(
	mushroom: MushroomNpc, behavior: MushroomNpcData, delta: float
) -> void:
	mushroom.move_forward(delta, behavior.wander_speed_scale)
	if behavior.wander_turn_on_wall and mushroom.is_front_blocked():
		mushroom.turn_around()
	elif behavior.wander_turn_at_ledge and not mushroom.is_ground_ahead():
		mushroom.turn_around()


func _has_bounds(behavior: MushroomNpcData) -> bool:
	return behavior.wander_radius > 0.0


func _get_random_destination(
	mushroom: MushroomNpc, behavior: MushroomNpcData
) -> Vector3:
	var angle := _random.randf_range(0.0, TAU)
	var random_radius := sqrt(_random.randf()) * behavior.wander_radius
	return mushroom.get_initial_world_position() + Vector3(
		cos(angle) * random_radius, 0.0, sin(angle) * random_radius
	)
