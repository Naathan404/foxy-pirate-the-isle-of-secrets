class_name CrabPatrol
extends EnemyPatrol

## Crab-specific GDD rule: after surviving a hit, resume patrol on the other axis.

var _change_axis_after_hit: bool = false
var _chase_direction: Vector3 = Vector3.ZERO
var _segment_start: Vector3 = Vector3.ZERO
var _blocked_remaining: float = 0.0


func _enter() -> void:
	super()
	_chase_direction = Vector3.ZERO
	if _change_axis_after_hit:
		_change_to_orthogonal_axis()
		_change_axis_after_hit = false
	if not enemy.damaged.is_connected(_on_enemy_damaged):
		enemy.damaged.connect(_on_enemy_damaged)


func _exit() -> void:
	if enemy.damaged.is_connected(_on_enemy_damaged):
		enemy.damaged.disconnect(_on_enemy_damaged)
	super()


func _update(delta: float) -> void:
	var crab := enemy as Crab
	if crab == null:
		return
	_blocked_remaining = maxf(0.0, _blocked_remaining - maxf(delta, 0.0))
	var destination := Vector3.ZERO
	var has_destination := false
	var chasing_player := false
	var home_offset := crab.global_position - crab.home_position
	home_offset.y = 0.0
	if home_offset.length() > crab.effective_movement_radius():
		destination = crab.home_position
		has_destination = true
	elif crab.can_chase_target():
		destination = crab.target.global_position
		has_destination = true
		chasing_player = true
	if not has_destination:
		_chase_direction = Vector3.ZERO
		super(delta)
		return
	var offset := destination - crab.global_position
	offset.y = 0.0
	if offset.length() <= crab.chase_stop_distance or _blocked_remaining > 0.0:
		crab._set_horizontal_velocity(Vector3.ZERO)
		return
	var distance_on_axis := absf((crab.global_position - _segment_start).dot(_chase_direction))
	if (
		_chase_direction.is_zero_approx()
		or distance_on_axis >= crab.min_chase_segment_distance
		or offset.dot(_chase_direction) <= 0.1
	):
		_choose_chase_direction(offset)
	if not _direction_is_safe(_chase_direction):
		var alternate := _alternate_direction(offset, _chase_direction)
		if alternate.is_zero_approx() or not _direction_is_safe(alternate):
			crab._set_horizontal_velocity(Vector3.ZERO)
			_chase_direction = Vector3.ZERO
			_blocked_remaining = 0.3
			return
		_set_chase_direction(alternate)
	if absf(_chase_direction.x) > 0.0:
		crab.velocity.z = 0.0
	else:
		crab.velocity.x = 0.0
	var move_scale := crab.chase_speed_scale if chasing_player else speed_scale
	crab.move_in_direction(_chase_direction, delta, move_scale)
	crab.play_directional_animation(movement_animation)


func _choose_chase_direction(offset: Vector3) -> void:
	var next := Vector3.ZERO
	if absf(offset.x) >= absf(offset.z) and absf(offset.x) > 0.1:
		next = Vector3.RIGHT if offset.x > 0.0 else Vector3.LEFT
	elif absf(offset.z) > 0.1:
		next = Vector3.BACK if offset.z > 0.0 else Vector3.FORWARD
	if next != _chase_direction:
		_set_chase_direction(next)


func _set_chase_direction(direction: Vector3) -> void:
	_chase_direction = direction
	_segment_start = enemy.global_position
	if not direction.is_zero_approx():
		enemy.face_direction(direction)
		enemy._refresh_direction_checks()


func _alternate_direction(offset: Vector3, direction: Vector3) -> Vector3:
	if absf(direction.x) > 0.0 and absf(offset.z) > 0.1:
		return Vector3.BACK if offset.z > 0.0 else Vector3.FORWARD
	if absf(direction.z) > 0.0 and absf(offset.x) > 0.1:
		return Vector3.RIGHT if offset.x > 0.0 else Vector3.LEFT
	return Vector3.ZERO


func _direction_is_safe(direction: Vector3) -> bool:
	if direction.is_zero_approx():
		return false
	enemy.face_direction(direction)
	enemy._refresh_direction_checks()
	return not enemy.is_front_blocked() and enemy.is_ground_ahead()


func _on_enemy_damaged(_applied_hp: float) -> void:
	if enemy.hp.is_alive():
		_change_axis_after_hit = true
