class_name BuckshotSalvoEffect
extends CharmEffect
## Radial burst; each pellet has independent target reservation.

const RECOIL_SECONDS := 0.18
const ATTACK_SCENE := preload("res://gameplay/charms/active/buckshot_projectile_attack.tscn")
const PROJECTILE_SHEET: Texture2D = preload(
	"res://assets/sprites/effects/charms/buckshot_projectile.png"
)
var _executions: Array[CharmActiveAttack] = []
var _impact_reported := false
var _windup := 0.0
var _cast_direction: Vector3 = Vector3.BACK


func can_activate(context: CharmActivationContext) -> bool:
	return (
		super.can_activate(context)
		and context != null
		and context.is_valid()
		and is_instance_valid(actor)
		and is_instance_valid(actor.get_parent())
		and definition.get_param_float(&"windup_seconds") > 0.0
		and definition.get_param_int(&"projectile_count", 8) > 0
		and definition.get_param_float(&"projectile_speed", 14.0) > 0.0
		and definition.get_param_float(&"range_units", 5.0) > 0.0
	)


func activate(context: CharmActivationContext) -> bool:
	if not can_activate(context) or not _begin_cast_lock():
		return false
	var base_direction := context.direction
	base_direction.y = 0.0
	if base_direction.is_zero_approx():
		base_direction = Vector3.BACK
	base_direction = base_direction.normalized()
	_impact_reported = false
	_cast_direction = base_direction
	_windup = definition.get_param_float(&"windup_seconds")
	_play_cast_animation(&"windup", _cast_direction, _windup)
	set_physics_process(true)
	return true


func _physics_process(delta: float) -> void:
	if _windup <= 0.0:
		set_physics_process(false)
		return
	_windup = maxf(0.0, _windup - delta)
	if _windup > 0.0:
		return
	set_physics_process(false)
	_end_cast_lock()
	_fire()


func _fire() -> void:
	var count := definition.get_param_int(&"projectile_count", 8)
	var base_angle := atan2(_cast_direction.x, _cast_direction.z)
	CharmSpriteVfx.spawn(
		actor.get_parent(),
		actor.global_position + Vector3.UP * 0.65,
		PROJECTILE_SHEET,
		2,
		1.7,
		0.24
	)
	get_node("/root/ScreenShakeController").request(3.5, 0.12)
	for index in count:
		var angle := base_angle + TAU * float(index) / float(count)
		var direction := Vector3(sin(angle), 0.0, cos(angle))
		var execution := ATTACK_SCENE.instantiate() as CharmActiveAttack
		if execution == null:
			continue
		actor.get_parent().add_child(execution)
		(execution as BuckshotProjectileAttack).pellet_hit.connect(_on_pellet_hit)
		_executions.append(execution)
		execution.tree_exited.connect(_executions.erase.bind(execution), CONNECT_ONE_SHOT)
		execution.context = AttackContext.new()
		execution.context.delivery_type = AttackData.DeliveryType.PROJECTILE
		execution.context.charm_push = true
		execution.context.knockback_multiplier = 0.55
		execution.context.actor = actor
		execution.context.team = actor.get("team")
		execution.context.attack_id = Time.get_ticks_usec() + index
		execution.context.action = definition.charm_id
		execution.context.origin = actor.global_position
		execution.context.direction = direction
		execution.context.damage_hp = (
			_get_base_damage() * definition.get_param_float(&"damage_percent", 0.5)
		)
		execution.global_position = actor.global_position
		execution.hitbox_scale = Vector3(0.35, 1.0, 0.7)
		execution.forward_offset = 0.4
		execution.travel_speed_units_per_second = definition.get_param_float(
			&"projectile_speed", 14.0
		)
		execution.max_travel_distance = definition.get_param_float(&"range_units", 5.0)
		execution.activate()
		execution.release_after(
			execution.max_travel_distance / execution.travel_speed_units_per_second + 0.1
		)

	_play_cast_animation(&"release", _cast_direction, RECOIL_SECONDS, true)


func _on_pellet_hit(at: Vector3) -> void:
	if _impact_reported:
		return
	_impact_reported = true
	get_node("/root/ScreenShakeController").request(5.5, 0.14)
	get_node("/root/AudioManager").play_sfx_3d(
		preload("res://assets/audio/combat/bow_impact.wav"), at, -6.0
	)


func cancel_active() -> void:
	_windup = 0.0
	set_physics_process(false)
	_stop_cast_animation()
	for execution: CharmActiveAttack in _executions:
		if is_instance_valid(execution):
			execution.deactivate()
			execution.queue_free()
	_executions.clear()
