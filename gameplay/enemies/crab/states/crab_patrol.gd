class_name CrabPatrol
extends EnemyPatrol

## Crabs walk sideways or diagonally, never straight up or down the screen. After surviving a
## hit, a crab resumes patrol on the other of those two headings. A crab with a claw attack
## closes in beside Foxy, since its claw swings sideways, then pinches.

## A target within this slope of the horizontal (tan 22.5 degrees) is walked to sideways.
const SIDEWAYS_SLOPE_LIMIT := 0.4142
## A depth gap this small is not worth a diagonal step.
const DEPTH_DEAD_ZONE_METERS := 0.35
## How close to its spot beside Foxy the crab must get before it stops walking.
const ATTACK_SPOT_TOLERANCE_METERS := 0.25

## Off for a crab that attacks another way (the elite charges).
@export var use_claw_attack: bool = true
## Sideways distance from Foxy the crab pinches from.
@export_range(0.5, 5.0, 0.05, "suffix:m") var attack_spacing_meters: float = 1.7
## How far beside the spot, sideways or in depth, Foxy may stand and still be pinched.
@export_range(0.1, 2.0, 0.05, "suffix:m") var attack_tolerance_meters: float = 0.55
@export_range(0.0, 10.0, 0.05, "suffix:s") var attack_cooldown_seconds: float = 1.0

var _change_axis_after_hit: bool = false
var _chase_direction: Vector3 = Vector3.ZERO
var _segment_start: Vector3 = Vector3.ZERO
var _blocked_remaining: float = 0.0
var _attack_cooldown_remaining: float = 0.0
var _contact_damage_on: bool = false


func _enter() -> void:
	# A room may place a crab facing up or down.
	enemy.face_direction(to_crab_direction(enemy.last_facing_direction))
	super()
	_chase_direction = Vector3.ZERO
	if _change_axis_after_hit:
		_change_to_orthogonal_axis()
		_change_axis_after_hit = false
	_contact_damage_on = use_contact_damage
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
	_attack_cooldown_remaining = maxf(0.0, _attack_cooldown_remaining - maxf(delta, 0.0))
	var stop_distance := crab.chase_stop_distance
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
		if _has_claw_attack():
			# Bumping into Foxy on the way would spend the hit: the crab turns away from Foxy
			# after hurting it, so it pinches instead.
			_set_contact_damage(false)
			var spot := _attack_spot(crab)
			if _is_at_attack_spot(spot) and _attack_cooldown_remaining <= 0.0:
				request_state(&"attack")
				return
			destination = spot
			stop_distance = ATTACK_SPOT_TOLERANCE_METERS
	if not chasing_player:
		_set_contact_damage(use_contact_damage)
	if not has_destination:
		_chase_direction = Vector3.ZERO
		super(delta)
		return
	var offset := destination - crab.global_position
	offset.y = 0.0
	if offset.length() <= stop_distance or _blocked_remaining > 0.0:
		crab._set_horizontal_velocity(Vector3.ZERO)
		if chasing_player:
			crab.play_directional_animation(&"idle")
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
	var move_scale := crab.chase_speed_scale if chasing_player else speed_scale
	crab.move_in_direction(_chase_direction, delta, move_scale)
	crab.play_directional_animation(movement_animation)


func start_attack_cooldown() -> void:
	_attack_cooldown_remaining = attack_cooldown_seconds


func _set_contact_damage(enabled: bool) -> void:
	if enabled == _contact_damage_on:
		return
	_contact_damage_on = enabled
	if enabled:
		enemy._start_contact_damage()
	else:
		enemy._stop_contact_damage()


func _has_claw_attack() -> bool:
	return use_claw_attack and fsm.states.has("attack")


## Beside Foxy, on the side the crab is already on.
func _attack_spot(crab: Crab) -> Vector3:
	var target_position := crab.target.global_position
	var side := -1.0 if crab.global_position.x < target_position.x else 1.0
	return target_position + Vector3(side * attack_spacing_meters, 0.0, 0.0)


func _is_at_attack_spot(spot: Vector3) -> bool:
	var offset := spot - enemy.global_position
	return absf(offset.x) <= attack_tolerance_meters and absf(offset.z) <= attack_tolerance_meters


## `direction` turned into a crab heading: unchanged unless it points straight up or down,
## which becomes the diagonal towards `side`.
static func to_crab_direction(direction: Vector3, side: float = 1.0) -> Vector3:
	if absf(direction.x) > absf(direction.z) * SIDEWAYS_SLOPE_LIMIT:
		return Vector3(direction.x, 0.0, direction.z).normalized()
	return Vector3(1.0 if side >= 0.0 else -1.0, 0.0, signf(direction.z)).normalized()


func _choose_chase_direction(offset: Vector3) -> void:
	var next := Vector3.ZERO
	var depth_limit := maxf(DEPTH_DEAD_ZONE_METERS, absf(offset.x) * SIDEWAYS_SLOPE_LIMIT)
	if absf(offset.z) > depth_limit:
		next = Vector3(_choose_side(offset), 0.0, signf(offset.z)).normalized()
	elif absf(offset.x) > 0.1:
		next = Vector3(signf(offset.x), 0.0, 0.0)
	if not next.is_equal_approx(_chase_direction):
		_set_chase_direction(next)


## Left (-1) or right (+1) for a diagonal step. Almost straight above or below the target the
## side alternates, so the crab zigzags there.
func _choose_side(offset: Vector3) -> float:
	var crab := enemy as Crab
	if absf(offset.x) > crab.min_chase_segment_distance:
		return signf(offset.x)
	if absf(_chase_direction.x) > 0.0 and absf(_chase_direction.z) > 0.0:
		return -signf(_chase_direction.x)
	return -1.0 if offset.x < 0.0 else 1.0


func _set_chase_direction(direction: Vector3) -> void:
	_chase_direction = direction
	_segment_start = enemy.global_position
	if direction.is_zero_approx():
		return
	# Carry the current speed into the new heading: easing between two diagonals would
	# otherwise drift straight up or down for a moment.
	var speed := Vector2(enemy.velocity.x, enemy.velocity.z).length()
	enemy._set_horizontal_velocity(direction * speed)
	enemy.face_direction(direction)
	enemy._refresh_direction_checks()


## The other ways of closing in when `direction` is blocked: sideways, then the mirrored
## diagonal.
func _alternate_direction(offset: Vector3, direction: Vector3) -> Vector3:
	var candidates: Array[Vector3] = []
	if absf(offset.x) > 0.1:
		candidates.append(Vector3(signf(offset.x), 0.0, 0.0))
	if absf(direction.z) > 0.0:
		candidates.append(Vector3(-direction.x, 0.0, direction.z))
	for candidate in candidates:
		if not candidate.is_equal_approx(direction) and _direction_is_safe(candidate):
			return candidate
	return Vector3.ZERO


func _direction_is_safe(direction: Vector3) -> bool:
	if direction.is_zero_approx():
		return false
	enemy.face_direction(direction)
	enemy._refresh_direction_checks()
	return not enemy.is_front_blocked() and enemy.is_ground_ahead()


## Replaces the shared left/right <-> up/down swap with sideways <-> diagonal.
func _change_to_orthogonal_axis() -> void:
	var facing := enemy.last_facing_direction
	var side := signf(facing.x) if absf(facing.x) > 0.0 else 1.0
	if absf(facing.z) > 0.1:
		enemy.face_direction(Vector3(side, 0.0, 0.0))
		return
	var depth := -1.0 if _random.randi_range(0, 1) == 0 else 1.0
	enemy.face_direction(Vector3(side, 0.0, depth).normalized())


func _on_enemy_damaged(_applied_hp: float) -> void:
	if enemy.hp.is_alive():
		_change_axis_after_hit = true
