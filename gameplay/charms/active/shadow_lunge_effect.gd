class_name ShadowLungeEffect
extends CharmEffect
## Move Foxy and resolve the first contact in the same physics step.

const HEIGHT := Vector3.UP * 0.65
const CONTACT_MASK := (
	CombatLayers.PLAYER_BODY_MASK | CombatLayers.ENEMY_HURTBOX | CombatLayers.PLAYER_BOUNDARY
)

var _remaining := 0.0
var _speed := 0.0
var _direction := Vector3.BACK
var _start := Vector3.ZERO
var _trail: CharmVfx


func activate(context: CharmActivationContext) -> bool:
	if not context.is_valid() or not actor is CharacterBody3D or not _begin_cast_lock():
		return false
	_direction = (
		context.target_position - actor.global_position if context.has_target else context.direction
	)
	_direction.y = 0.0
	_direction = _direction.normalized() if not _direction.is_zero_approx() else Vector3.BACK
	_remaining = definition.get_param_float(&"dash_distance_units")
	var seconds := definition.get_param_float(&"travel_seconds")
	_speed = _remaining / seconds
	_start = actor.global_position + HEIGHT
	_trail = CharmVfx.streak(actor.get_parent(), _start, _start, CharmVfx.SHADOW, 0.9, seconds)
	_trail.sustained = true
	CharmVfx.spawn(actor.get_parent(), actor.global_position, CharmVfx.SHADOW, 0.9)
	_play_cast_animation(&"active", _direction, seconds)
	set_physics_process(true)
	return true


func _physics_process(delta: float) -> void:
	if _remaining <= 0.0 or delta <= 0.0:
		return
	var distance := minf(_remaining, _speed * delta)
	var body := actor as CharacterBody3D
	var start := actor.global_position + HEIGHT
	var padding := definition.get_param_float(&"wall_padding")
	var query := PhysicsRayQueryParameters3D.create(
		start, start + _direction * (distance + padding), CONTACT_MASK
	)
	query.exclude = [body.get_rid()]
	query.hit_from_inside = true
	query.collide_with_areas = true
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
	var collider: Object = hit.get("collider")
	if collider != null:
		distance = clampf(start.distance_to(hit.position) - padding, 0.0, distance)
	var collision := body.move_and_collide(_direction * distance) if distance > 0.0 else null
	if collision != null:
		collider = collision.get_collider()
	_trail.set_endpoints(_start, actor.global_position + HEIGHT, 0.9)
	_remaining -= distance
	if collider == null and _remaining > 0.001:
		return
	var target := collider as Node3D
	if collider is HurtBox:
		target = (collider as HurtBox).actor as Node3D
	if is_instance_valid(target) and target.has_method("receive_damage"):
		var amount := _get_base_damage() * definition.get_param_float(&"damage_multiplier")
		if _damage_target(target, amount, actor.global_position, 1.6) > 0.0:
			CharmVfx.heavy_impact(actor.get_parent(), target.global_position, CharmVfx.SHADOW)
	_finish()


func _finish() -> void:
	_remaining = 0.0
	set_physics_process(false)
	_end_cast_lock()
	if is_instance_valid(_trail):
		_trail.queue_free()
	_trail = null
	_play_cast_animation(&"recover", _direction, 0.1, true)


func cancel_active() -> void:
	_remaining = 0.0
	set_physics_process(false)
	if is_instance_valid(_trail):
		_trail.queue_free()
	_trail = null
	_stop_cast_animation()
