class_name EliteCrabCharge
extends EnemyState

enum AttackPhase { TELEGRAPH, CHARGE, SLAM }

@export_range(0.05, 3.0, 0.01, "suffix:s") var telegraph_duration: float = 0.55
@export_range(0.05, 5.0, 0.01, "suffix:s") var charge_duration: float = 0.75
@export_range(0.1, 10.0, 0.1) var charge_speed_scale: float = 3.2
@export_range(0.1, 3.0, 0.01, "suffix:m") var arrival_distance: float = 0.4

@export_group("Slam")
## Time from the start of the slam until the claw meets the ground, as drawn.
@export_range(0.0, 1.0, 0.01, "suffix:s") var slam_impact_delay: float = 0.1
@export_range(0.05, 2.0, 0.01, "suffix:s") var slam_active_duration: float = 0.18
## How long the crab stays down after the hit, so the slam reads and can be punished.
@export_range(0.0, 3.0, 0.01, "suffix:s") var slam_recovery_duration: float = 0.45
@export
var slam_impact_scene: PackedScene = preload("res://gameplay/enemies/crab/crab_slam_impact.tscn")
## Bone of the artwork where the claw meets the ground.
@export var slam_impact_bone: String = "fx_impact"
## Sideways distance to the hit when the artwork has no such bone (sprite sheet).
@export_range(0.0, 6.0, 0.05, "suffix:m") var slam_reach_meters: float = 1.8
@export_range(0.5, 3.0, 0.05) var slam_impact_scale: float = 1.5

@export_group("Impact Feel")
@export_range(0.0, 14.0, 0.5, "suffix:px") var slam_shake_pixels: float = 14.0
@export_range(0.0, 0.3, 0.01, "suffix:s") var slam_shake_seconds: float = 0.3
## A second, weaker jolt that lets the ground keep ringing after the hit.
@export_range(0.0, 14.0, 0.5, "suffix:px") var aftershock_shake_pixels: float = 8.0
@export_range(0.0, 1.0, 0.01, "suffix:s") var aftershock_delay: float = 0.2
@export_range(0.0, 0.08, 0.005, "suffix:s") var slam_hitstop_seconds: float = 0.07
@export_range(0.0, 14.0, 0.5, "suffix:px") var windup_shake_pixels: float = 2.0
## Each heavy step of the charge shakes the screen a little.
@export_range(0.0, 14.0, 0.5, "suffix:px") var charge_step_shake_pixels: float = 3.5
@export_range(0.05, 1.0, 0.01, "suffix:s") var charge_step_interval: float = 0.17
@export_group("")

var _phase: AttackPhase = AttackPhase.TELEGRAPH
var _locked_target_position: Vector3 = Vector3.ZERO
var _waypoints: Array[Vector3] = []
var _charge_direction: Vector3 = Vector3.RIGHT
var _impact_side: float = 1.0
var _step_remaining: float = 0.0
var _slam_elapsed: float = 0.0
var _has_impacted: bool = false
var _has_aftershocked: bool = false
var _slam_hitbox_transform: Transform3D = Transform3D.IDENTITY


func _enter() -> void:
	_slam_hitbox_transform = enemy.active_hitbox.transform
	enemy._stop_contact_damage()
	if not enemy.has_target():
		_return_to_patrol()
		return
	_locked_target_position = enemy.target.global_position
	_locked_target_position.y = enemy.global_position.y
	var facing_side := -1.0 if enemy.last_facing_direction.x < 0.0 else 1.0
	_waypoints = get_crab_route(
		enemy.global_position, _locked_target_position, arrival_distance, facing_side
	)
	_charge_direction = _leg_direction()
	if _charge_direction.is_zero_approx():
		_charge_direction = Vector3(facing_side, 0.0, 0.0)
	enemy.face_direction(_charge_direction)
	_phase = AttackPhase.TELEGRAPH
	timer = telegraph_duration
	enemy.stop_movement()
	if not enemy.play_directional_animation(&"windup", true):
		enemy.play_directional_animation(&"idle", true)
	_get_feedback().begin_telegraph()
	_shake(windup_shake_pixels, telegraph_duration)


func _exit() -> void:
	enemy.end_active_attack()
	enemy.active_hitbox.transform = _slam_hitbox_transform
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
		_step_remaining = 0.0
		if not enemy.play_directional_animation(&"charge_run", true):
			enemy.play_directional_animation(&"run", true)
		_get_feedback().end_telegraph()


func _update_charge(delta: float) -> void:
	if _has_reached_locked_target() or _timer_finished(delta):
		_begin_slam()
		return
	if _is_leg_finished():
		_waypoints.pop_front()
		if _waypoints.is_empty():
			_begin_slam()
			return
		_turn_charge_corner(_leg_direction())
	if enemy.is_front_blocked() or not enemy.is_ground_ahead():
		_abandon_charge()
		return
	_step_remaining -= maxf(0.0, delta)
	if _step_remaining <= 0.0:
		_step_remaining = charge_step_interval
		_shake(charge_step_shake_pixels, charge_step_interval)
	enemy.move_in_direction(_charge_direction, delta, charge_speed_scale)


func _begin_slam() -> void:
	_phase = AttackPhase.SLAM
	timer = slam_impact_delay + slam_active_duration + slam_recovery_duration
	_slam_elapsed = 0.0
	_has_impacted = false
	_has_aftershocked = false
	enemy.stop_movement()
	enemy._set_horizontal_velocity(Vector3.ZERO)
	_impact_side = -1.0 if enemy.last_facing_direction.x < 0.0 else 1.0
	if enemy.has_target():
		var to_target := enemy.target.global_position.x - enemy.global_position.x
		_impact_side = -1.0 if to_target < 0.0 else 1.0
	enemy.face_direction(Vector3(_impact_side, 0.0, 0.0))
	if not enemy.play_directional_animation(&"slam", true):
		enemy.play_directional_animation(&"hit", true)


func _update_slam(delta: float) -> void:
	enemy.stop_movement(delta)
	_slam_elapsed += maxf(0.0, delta)
	if not _has_impacted and _slam_elapsed >= slam_impact_delay:
		_impact()
	if _slam_elapsed >= slam_impact_delay + slam_active_duration:
		enemy.end_active_attack()
	if not _has_aftershocked and _slam_elapsed >= slam_impact_delay + aftershock_delay:
		_has_aftershocked = true
		_shake(aftershock_shake_pixels, slam_shake_seconds)
	if _timer_finished(delta):
		_return_to_patrol()


## The claw meets the ground: damage, shake, a short freeze and the cracked ground together.
func _impact() -> void:
	_has_impacted = true
	var fallback := Vector3(_impact_side * slam_reach_meters, 0.0, 0.0)
	var offset := CrabSlamImpact.get_claw_offset(enemy, slam_impact_bone, fallback)
	enemy.active_hitbox.global_position = enemy.global_position + offset
	enemy.begin_active_attack(1, &"elite_crab_slam")
	# Sample at the impact frame; Area3D overlaps otherwise lag behind the moved hitbox.
	enemy.active_hitbox.sample_shape()
	_shake(slam_shake_pixels, slam_shake_seconds)
	if slam_hitstop_seconds > 0.0:
		enemy.get_node("/root/HitstopController").request(slam_hitstop_seconds)
	var effect := CrabSlamImpact.spawn_at_claw(slam_impact_scene, enemy, slam_impact_bone, fallback)
	if effect != null:
		effect.scale = Vector3.ONE * slam_impact_scale


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


## Exact heading of the current leg: sideways or a 45 degree diagonal.
func _leg_direction() -> Vector3:
	if _waypoints.is_empty():
		return Vector3.ZERO
	var offset := _waypoints.front() - enemy.global_position as Vector3
	if absf(offset.z) <= arrival_distance:
		return Vector3(signf(offset.x), 0.0, 0.0)
	var side := signf(offset.x) if absf(offset.x) > 0.01 else 1.0
	return Vector3(side, 0.0, signf(offset.z)).normalized()


func _is_leg_finished() -> bool:
	var remaining := _waypoints.front() - enemy.global_position as Vector3
	remaining.y = 0.0
	return remaining.dot(_charge_direction) <= arrival_distance * 0.5


func _has_reached_locked_target() -> bool:
	var offset := _locked_target_position - enemy.global_position
	return absf(offset.x) <= arrival_distance and absf(offset.z) <= arrival_distance


func _turn_charge_corner(next_direction: Vector3) -> void:
	# Keep the speed but drop the old heading, so a corner never drifts straight up or down.
	var speed := Vector2(enemy.velocity.x, enemy.velocity.z).length()
	enemy._set_horizontal_velocity(next_direction * speed)
	_charge_direction = next_direction
	enemy.face_direction(_charge_direction)
	enemy._refresh_direction_checks()


func _get_charge_timeout() -> float:
	var route_distance := 0.0
	var previous := enemy.global_position
	for waypoint in _waypoints:
		route_distance += Vector2(waypoint.x - previous.x, waypoint.z - previous.z).length()
		previous = waypoint
	var charge_speed := 0.0
	if enemy.data != null:
		charge_speed = enemy.data.move_speed * charge_speed_scale
	# Covers acceleration from rest and the second leg of a bent charge.
	return maxf(charge_duration, route_distance / maxf(0.01, charge_speed) + 0.4)


func _timer_finished(delta: float) -> bool:
	return timer <= 0.0 or update_timer(delta)


func _shake(pixels: float, duration_seconds: float) -> void:
	enemy.get_node("/root/ScreenShakeController").request(pixels, duration_seconds)


## Waypoints of a charge made only of sideways and 45 degree diagonal legs. A target mostly
## to the side takes a diagonal then a sideways leg; one mostly above or below takes two
## opposite diagonals, the first towards `preferred_side` when it is straight ahead.
static func get_crab_route(
	from: Vector3, to: Vector3, arrival_tolerance: float = 0.0, preferred_side: float = 1.0
) -> Array[Vector3]:
	var offset := to - from
	var width := absf(offset.x)
	var depth := absf(offset.z)
	var route: Array[Vector3] = []
	if depth <= arrival_tolerance:
		if width > arrival_tolerance:
			route.append(Vector3(to.x, from.y, from.z))
		return route
	var side := signf(offset.x) if width > 0.01 else signf(preferred_side)
	if width >= depth:
		route.append(Vector3(from.x + side * depth, from.y, to.z))
		if width - depth > arrival_tolerance:
			route.append(Vector3(to.x, from.y, to.z))
		return route
	var first_leg := (depth + width) * 0.5
	var second_leg := (depth - width) * 0.5
	var corner := from + Vector3(side * first_leg, 0.0, signf(offset.z) * first_leg)
	route.append(corner)
	if second_leg > arrival_tolerance:
		route.append(Vector3(to.x, from.y, to.z))
	return route


func _get_feedback() -> EliteFeedback:
	return enemy.get_node_or_null("EliteFeedback") as EliteFeedback
