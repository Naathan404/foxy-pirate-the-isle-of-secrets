class_name TideGrappleAttack
extends Node3D
## Raycast mỏ neo, gây sát thương rồi chọn bên bị kéo theo loại mục tiêu.

signal grapple_resolved(result: StringName, target: Node)
signal flight_phase_changed(phase: StringName, seconds: float)
signal completed

enum FlightPhase { INACTIVE, OUTBOUND, LATCHED, RETURNING }

const HAND_HEIGHT: Vector3 = Vector3(0.0, 0.6, 0.0)
const CONTACT_SECONDS: float = 0.16

const RESULT_MISS: StringName = &"miss"
const RESULT_TARGET_PULLED: StringName = &"target_pulled"
const RESULT_ACTOR_PULLED_LARGE: StringName = &"actor_pulled_large"
const RESULT_ACTOR_PULLED_BOSS: StringName = &"actor_pulled_boss"
const RESULT_ACTOR_PULLED_TERRAIN: StringName = &"actor_pulled_terrain"
const RESULT_TARGET_HIT: StringName = &"target_hit"

@export var raycast: RayCast3D

var context: AttackContext
var range_units: float = 4.0
var pull_stop_distance: float = 1.0
var pull_speed_units_per_second: float = 16.0
var stun_seconds: float = 1.0
var hook_speed_units_per_second: float = 24.0
var return_speed_units_per_second: float = 28.0

var _phase: FlightPhase = FlightPhase.INACTIVE
var _phase_elapsed: float = 0.0
var _phase_seconds: float = 0.1
var _flight_start: Vector3
var _destination: Vector3
var _hook_position: Vector3
var _pending_collider: Object
var _target: Node3D
var _target_offset: Vector3
var _contact_hit: bool = false

@onready var _visual: TideGrappleVisual = $TideGrappleVisual


func _ready() -> void:
	set_physics_process(false)


func validate() -> bool:
	return is_instance_valid(raycast)


func activate() -> bool:
	if not validate() or context == null or not is_instance_valid(context.actor):
		return false
	if context.direction.is_zero_approx() or context.damage_hp <= 0 or range_units <= 0.0:
		return false
	look_at(global_position + context.direction, Vector3.UP)
	if context.actor is CollisionObject3D:
		raycast.add_exception(context.actor as CollisionObject3D)
	raycast.position = HAND_HEIGHT
	raycast.target_position = Vector3(0.0, 0.0, -range_units)
	raycast.enabled = true
	raycast.force_raycast_update()
	_destination = global_position + context.direction.normalized() * range_units + HAND_HEIGHT
	_pending_collider = null
	_target = null
	if raycast.is_colliding():
		_pending_collider = raycast.get_collider()
		_destination = raycast.get_collision_point()
		_target = _get_damage_target(_pending_collider) as Node3D
		if is_instance_valid(_target):
			_target_offset = _destination - _target.global_position
	_flight_start = _hand_position()
	_hook_position = _flight_start
	_contact_hit = false
	_enter_phase(
		FlightPhase.OUTBOUND,
		&"active",
		_flight_start.distance_to(_destination) / maxf(0.01, hook_speed_units_per_second)
	)
	_visual.set_flight(_flight_start, _hook_position, context.direction, 0, 0.0, 0.2)
	set_physics_process(true)
	return true


func _physics_process(delta: float) -> void:
	if context == null or not is_instance_valid(context.actor) or bool(context.actor.get("dead")):
		cancel()
		return
	_phase_elapsed += maxf(0.0, delta)
	var progress := clampf(_phase_elapsed / _phase_seconds, 0.0, 1.0)
	match _phase:
		FlightPhase.OUTBOUND:
			_destination = _target_position()
			_hook_position = _flight_start.lerp(_destination, progress)
			_visual.set_flight(
				_hand_position(), _hook_position, context.direction, 0, progress, 0.2
			)
			if progress >= 1.0:
				_arrive()
		FlightPhase.LATCHED:
			_hook_position = _target_position()
			_visual.set_flight(
				_hand_position(),
				_hook_position,
				context.direction,
				1,
				minf(1.0, _phase_elapsed / CONTACT_SECONDS),
				0.05
			)
			var separation := _hook_position - HAND_HEIGHT - context.actor.global_position
			if is_instance_valid(_target):
				separation = _target.global_position - context.actor.global_position
			separation.y = 0.0
			if (
				progress >= 1.0
				or (
					_phase_elapsed >= CONTACT_SECONDS
					and separation.length() <= pull_stop_distance + 0.1
				)
			):
				_begin_return()
		FlightPhase.RETURNING:
			_hook_position = _flight_start.lerp(_hand_position(), progress)
			_visual.set_flight(
				_hand_position(),
				_hook_position,
				context.direction,
				1 if _contact_hit else 2,
				1.0 if _contact_hit else progress,
				0.1 if _contact_hit else 1.0
			)
			if progress >= 1.0:
				_phase = FlightPhase.INACTIVE
				set_physics_process(false)
				completed.emit()
				queue_free()


func cancel() -> void:
	_phase = FlightPhase.INACTIVE
	set_physics_process(false)
	queue_free()


func _hand_position() -> Vector3:
	return context.actor.global_position + HAND_HEIGHT + context.direction.normalized() * 0.4


func _target_position() -> Vector3:
	if is_instance_valid(_target):
		_destination = _target.global_position + _target_offset
		# Wide hurtboxes can overlap the hand after a pull. Keep the visible hook
		# in front of the grip rather than dragging it through Foxy's body.
		if _phase == FlightPhase.LATCHED:
			var forward := context.direction.normalized()
			var ahead := (_destination - _hand_position()).dot(forward)
			_destination += forward * maxf(0.0, 0.65 - ahead)
	return _destination


func _enter_phase(phase: FlightPhase, animation: StringName, seconds: float) -> void:
	_phase = phase
	_phase_elapsed = 0.0
	_phase_seconds = maxf(0.07, seconds)
	flight_phase_changed.emit(animation, _phase_seconds)


func _arrive() -> void:
	var collider := _pending_collider if is_instance_valid(_pending_collider) else null
	if is_instance_valid(_target) and _target is EnemyBase and (_target as EnemyBase).dead:
		collider = null
	if collider is HurtBox and not is_instance_valid(_target):
		collider = null
	_contact_hit = collider != null
	resolve_hit(collider, _hook_position - HAND_HEIGHT)
	if not _contact_hit:
		_begin_return()
		return
	var distance := _hand_position().distance_to(_hook_position)
	var pull_seconds := maxf(
		CONTACT_SECONDS, (distance - pull_stop_distance) / maxf(0.01, pull_speed_units_per_second)
	)
	_enter_phase(FlightPhase.LATCHED, &"latch", pull_seconds)
	_visual.set_flight(_hand_position(), _hook_position, context.direction, 1, 0.0, 0.05)


func _begin_return() -> void:
	_flight_start = _hook_position
	_enter_phase(
		FlightPhase.RETURNING,
		&"retract" if _contact_hit else &"miss",
		_hook_position.distance_to(_hand_position()) / maxf(0.01, return_speed_units_per_second)
	)


func resolve_hit(collider: Object, hit_position: Vector3) -> StringName:
	if collider == null or context == null or not is_instance_valid(context.actor):
		grapple_resolved.emit(RESULT_MISS, null)
		return RESULT_MISS
	get_node("/root/ScreenShakeController").request(3.5, 0.12)
	var target := _get_damage_target(collider)
	if target == null:
		var terrain_result := _pull_actor(hit_position, RESULT_ACTOR_PULLED_TERRAIN)
		grapple_resolved.emit(terrain_result, collider as Node)
		return terrain_result
	_apply_damage(collider, target)
	var result := _resolve_target_pull(target)
	grapple_resolved.emit(result, target)
	return result


func _get_damage_target(collider: Object) -> Node:
	if collider is HurtBox:
		var hurtbox := collider as HurtBox
		return hurtbox.actor if is_instance_valid(hurtbox.actor) else null
	if collider is Node and (collider as Node).has_method("receive_damage"):
		return collider as Node
	return null


func _apply_damage(collider: Object, target: Node) -> void:
	var damage := context.create_damage_context()
	var applied_hp := 0.0
	if collider is HurtBox:
		applied_hp = (collider as HurtBox).take_damage(damage)
	elif target.has_method("receive_damage"):
		applied_hp = float(target.call("receive_damage", damage))
	if applied_hp > 0:
		get_node("/root/AudioManager").play_sfx_3d(
			preload("res://assets/audio/combat/bow_impact.wav"), _hook_position, -8.0
		)
		context.damage_applied.emit(damage, target, applied_hp)
		get_node("/root/HitstopController").request_local(context.actor, target as Node3D, 0.06)
		CharmVfx.spawn(get_parent(), _hook_position, CharmVfx.TIDE, 0.9)
		CharmFeel.shake(self, 5.0, 0.14)
		CharmFeel.flash(self, CharmVfx.TIDE, 0.07, 0.12)


func _resolve_target_pull(target: Node) -> StringName:
	if not target is Node3D:
		return RESULT_TARGET_HIT
	if target.has_method("apply_charm_grapple"):
		return (
			target.call(
				"apply_charm_grapple",
				context.actor,
				pull_stop_distance,
				pull_speed_units_per_second,
				stun_seconds
			)
			as StringName
		)
	return RESULT_TARGET_HIT


func _pull_actor(target_position: Vector3, result: StringName) -> StringName:
	if not context.actor.has_method("apply_charm_grapple_pull"):
		return RESULT_MISS
	var pulled := bool(
		context.actor.call(
			"apply_charm_grapple_pull",
			target_position,
			pull_stop_distance,
			pull_speed_units_per_second
		)
	)
	return result if pulled else RESULT_MISS
