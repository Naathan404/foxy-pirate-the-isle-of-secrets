extends CharmEffect

const PARTICLES := preload("res://gameplay/charms/active/devil_contract_particles.tscn")
const RELEASE_SECONDS := 0.2
const AURA_COLOR := Color("db406d")
var _remaining := 0.0
var _particles: CPUParticles3D
var _windup := 0.0
var _direction := Vector3.ZERO


func can_activate(context: CharmActivationContext) -> bool:
	return (
		super.can_activate(context)
		and actor is Player
		and definition.get_param_float(&"windup_seconds") > 0.0
		and (actor as Player).stamina.can_consume(definition.resource_cost)
	)


func get_activation_cost(_context: CharmActivationContext) -> float:
	return (actor as Player).stamina.get_current_sp()


func activate(context: CharmActivationContext) -> bool:
	if not _begin_cast_lock():
		return false
	_direction = context.direction
	_windup = definition.get_param_float(&"windup_seconds")
	(actor as Player).stamina.set_recovery_block(definition.charm_id, true)
	_play_cast_animation(&"windup", _direction, _windup)
	set_physics_process(true)
	return true


func modify_attack_damage(amount_hp: float, _attack: AttackContext) -> float:
	return (
		amount_hp * definition.get_param_float(&"damage_multiplier")
		if _remaining > 0.0
		else amount_hp
	)


func modify_stats(stats: Dictionary[StringName, float]) -> void:
	if _remaining > 0.0:
		stats[&"move_speed_multiplier"] = (
			stats.get(&"move_speed_multiplier", 1.0)
			* definition.get_param_float(&"move_speed_multiplier")
		)
		stats[&"charm_damage_multiplier"] = (
			stats.get(&"charm_damage_multiplier", 1.0)
			* definition.get_param_float(&"damage_multiplier")
		)


func _physics_process(delta: float) -> void:
	if _windup > 0.0:
		_windup = maxf(0.0, _windup - delta)
		if _windup <= 0.0:
			_end_cast_lock()
			_remaining = definition.get_param_float(&"duration_seconds")
			_particles = PARTICLES.instantiate() as CPUParticles3D
			actor.add_child(_particles)
			_play_cast_animation(&"release", _direction, RELEASE_SECONDS, true)
			CharmBlastVfx.burst(
				actor.get_parent(),
				actor.global_position,
				CharmBlastVfx.Kind.SPARK,
				2.6,
				AURA_COLOR
			)
			CharmFeel.shake(actor, 6.0, 0.2)
			CharmFeel.flash(actor, AURA_COLOR, 0.14, 0.2)
			CharmFeel.shockwave(
				actor, actor.global_position + Vector3.UP * 0.8, AURA_COLOR, 0.0, 0.01, 0.5
			)
			CharmFeel.sound(actor, CharmFeel.IMPACT_SOUND, actor.global_position, -3.0, 0.6)
			var attack_bonus := roundi(
				(definition.get_param_float(&"damage_multiplier") - 1.0) * 100
			)
			var speed_bonus := roundi(
				(definition.get_param_float(&"move_speed_multiplier") - 1.0) * 100
			)
			runtime.proc_triggered.emit(
				"+%d%% ATK\n+%d%% SPD" % [attack_bonus, speed_bonus], AURA_COLOR
			)
		return
	_remaining = maxf(0.0, _remaining - delta)
	if _remaining <= 0.0:
		cancel_active()


func on_input_cancelled() -> void:
	if _windup > 0.0:
		cancel_active()


func cancel_active() -> void:
	set_physics_process(false)
	_stop_cast_animation()
	_windup = 0.0
	_remaining = 0.0
	if (
		is_instance_valid(actor)
		and actor is Player
		and is_instance_valid((actor as Player).stamina)
	):
		(actor as Player).stamina.set_recovery_block(definition.charm_id, false)
	if is_instance_valid(_particles):
		_particles.queue_free()
	_particles = null
