class_name EliteCrabCharge
extends EnemyState

enum AttackPhase { TELEGRAPH, CHARGE, SLAM }

@export_range(0.05, 3.0, 0.01, "suffix:s") var telegraph_duration: float = 0.55
@export_range(0.05, 5.0, 0.01, "suffix:s") var charge_duration: float = 0.75
@export_range(0.1, 10.0, 0.1) var charge_speed_scale: float = 3.2
@export_range(0.05, 2.0, 0.01, "suffix:s") var slam_active_duration: float = 0.18
@export_range(0.1, 3.0, 0.01, "suffix:m") var arrival_distance: float = 0.4

var _phase: AttackPhase = AttackPhase.TELEGRAPH
var _locked_target_position: Vector3 = Vector3.ZERO
var _charge_direction: Vector3 = Vector3.FORWARD


func _enter() -> void:
	if not enemy.has_target():
		_return_to_patrol()
		return
	_locked_target_position = enemy.target.global_position
	_locked_target_position.y = enemy.global_position.y
	_charge_direction = _get_next_charge_direction()
	if _charge_direction.is_zero_approx():
		_charge_direction = _cardinal_fallback(enemy.last_facing_direction)
	enemy.face_direction(_charge_direction)
	_phase = AttackPhase.TELEGRAPH
	timer = telegraph_duration
	enemy.stop_movement()
	_get_feedback().begin_telegraph()


func _exit() -> void:
	enemy.end_active_attack()
	_get_feedback().end_telegraph()


func _update(delta: float) -> void:
	match _phase:
		AttackPhase.TELEGRAPH:
			_update_telegraph(delta)
		AttackPhase.CHARGE:
			_update_charge(delta)
		AttackPhase.SLAM:
			_update_slam(delta)


func _update_telegraph(delta: float) -> void:
	enemy.stop_movement(delta)
	if _timer_finished(delta):
		_phase = AttackPhase.CHARGE
		timer = _get_charge_timeout()
		enemy.play_directional_animation(&"run", true)
		_get_feedback().end_telegraph()


func _update_charge(delta: float) -> void:
	if _has_reached_locked_target() or _timer_finished(delta):
		_begin_slam()
		return
	var next_direction := _get_next_charge_direction()
	if next_direction.is_zero_approx():
		_begin_slam()
		return
	if next_direction != _charge_direction:
		_turn_charge_corner(next_direction)
	if enemy.is_front_blocked() or not enemy.is_ground_ahead():
		_abandon_charge()
		return
	enemy.move_in_direction(_charge_direction, delta, charge_speed_scale)


func _begin_slam() -> void:
	_phase = AttackPhase.SLAM
	timer = slam_active_duration
	enemy.stop_movement()
	enemy.play_directional_animation(&"hit", true)
	enemy.begin_active_attack(1, &"elite_crab_slam")


func _update_slam(delta: float) -> void:
	enemy.stop_movement(delta)
	if _timer_finished(delta):
		_return_to_patrol()


func _return_to_patrol() -> void:
	var patrol := get_node_or_null("../Patrol") as EliteCrabPatrol
	if patrol != null:
		patrol.start_charge_cooldown()
	request_state(&"patrol")


func _abandon_charge() -> void:
	enemy.stop_movement()
	enemy.turn_around()
	var patrol := get_node_or_null("../Patrol") as EliteCrabPatrol
	if patrol != null:
		patrol.start_unreachable_target_cooldown()
	request_state(&"patrol")


func _get_next_charge_direction() -> Vector3:
	var route := get_cardinal_route(
		enemy.global_position, _locked_target_position, arrival_distance
	)
	return route.front() if not route.is_empty() else Vector3.ZERO


func _has_reached_locked_target() -> bool:
	var offset := _locked_target_position - enemy.global_position
	return absf(offset.x) <= arrival_distance and absf(offset.z) <= arrival_distance


func _turn_charge_corner(next_direction: Vector3) -> void:
	# Cancel the old-axis velocity so the turn is an L corner, never a diagonal drift.
	if absf(next_direction.x) > 0.0:
		enemy.velocity.z = 0.0
	else:
		enemy.velocity.x = 0.0
	_charge_direction = next_direction
	enemy.face_direction(_charge_direction)
	enemy._refresh_direction_checks()


func _get_charge_timeout() -> float:
	var route_distance := (
		absf(_locked_target_position.x - enemy.global_position.x)
		+ absf(_locked_target_position.z - enemy.global_position.z)
	)
	var charge_speed := 0.0
	if enemy.data != null:
		charge_speed = enemy.data.move_speed * charge_speed_scale
	# Covers acceleration from rest and allows the second leg of the L-shaped charge.
	return maxf(charge_duration, route_distance / maxf(0.01, charge_speed) + 0.4)


func _timer_finished(delta: float) -> bool:
	return timer <= 0.0 or update_timer(delta)


static func get_cardinal_route(
	from: Vector3, to: Vector3, arrival_tolerance: float = 0.0
) -> Array[Vector3]:
	var route: Array[Vector3] = []
	var offset := to - from
	# The vertical leg is deliberately first; the horizontal leg finishes the approach.
	if absf(offset.z) > arrival_tolerance:
		route.append(Vector3.BACK if offset.z > 0.0 else Vector3.FORWARD)
	if absf(offset.x) > arrival_tolerance:
		route.append(Vector3.RIGHT if offset.x > 0.0 else Vector3.LEFT)
	return route


static func _cardinal_fallback(direction: Vector3) -> Vector3:
	if absf(direction.z) > 0.0:
		return Vector3.BACK if direction.z > 0.0 else Vector3.FORWARD
	return Vector3.RIGHT if direction.x >= 0.0 else Vector3.LEFT


func _get_feedback() -> EliteFeedback:
	return enemy.get_node_or_null("EliteFeedback") as EliteFeedback
