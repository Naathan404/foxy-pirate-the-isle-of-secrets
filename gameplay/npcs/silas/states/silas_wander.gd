class_name SilasWander
extends NpcState

## Slow, bounded wandering around the currently selected Hub hideout.

var _random := RandomNumberGenerator.new()
var _moving := true
var _destination := Vector3.ZERO


func _enter() -> void:
	_random.randomize()
	var silas := npc as SilasNpc
	if silas == null:
		push_error("SilasWander must be used by SilasNpc")
		return
	_begin_moving(silas)


func _update(delta: float) -> void:
	var silas := npc as SilasNpc
	if silas == null:
		return
	var data := silas.get_silas_data()
	if data == null:
		return

	if _moving:
		_update_movement(silas, data, delta)
	else:
		silas.stop_movement(delta)
		silas.play_directional_animation(&"idle")

	timer -= maxf(0.0, delta)
	if timer > 0.0:
		return
	if _moving:
		_begin_resting(data)
	else:
		_begin_moving(silas)


func _update_movement(silas: SilasNpc, data: SilasNpcData, delta: float) -> void:
	var anchor_offset := silas.global_position - silas.get_wander_anchor()
	anchor_offset.y = 0.0
	if anchor_offset.length() >= data.wander_radius:
		# Never keep a target beyond the hideout circle. The small sampling margin
		# below leaves room for CharacterBody3D deceleration at the boundary.
		_destination = silas.get_wander_anchor()

	var direction := _destination - silas.global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.04:
		_begin_resting(data)
		return

	silas.move_in_direction(direction, delta)
	silas.play_directional_animation(&"walk")
	if silas.is_front_blocked() or not silas.is_ground_ahead():
		_begin_moving(silas)


func _begin_moving(silas: SilasNpc) -> void:
	var data := silas.get_silas_data()
	if data == null:
		return
	_moving = true
	_destination = _random_destination(silas, data)
	timer = _random.randf_range(
		minf(data.wander_move_duration_min, data.wander_move_duration_max),
		maxf(data.wander_move_duration_min, data.wander_move_duration_max)
	)


func _begin_resting(data: SilasNpcData) -> void:
	_moving = false
	timer = _random.randf_range(
		minf(data.wander_rest_duration_min, data.wander_rest_duration_max),
		maxf(data.wander_rest_duration_min, data.wander_rest_duration_max)
	)


func _random_destination(silas: SilasNpc, data: SilasNpcData) -> Vector3:
	var angle := _random.randf_range(0.0, TAU)
	var safe_radius := maxf(0.0, data.wander_radius - 0.25)
	var radius := sqrt(_random.randf()) * safe_radius
	return silas.get_wander_anchor() + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
