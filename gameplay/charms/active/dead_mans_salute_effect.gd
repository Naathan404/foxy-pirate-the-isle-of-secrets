class_name DeadMansSaluteEffect
extends CharmEffect
## Hold-to-charge AoE blast with delta-time SP drain. While held, a golden ring of sun rays
## grows with the blast radius, sparks are drawn in from its rim and a tick rises in pitch;
## the release bursts that ring outwards with a shake, flash and refraction wave that all
## scale with how long the charge was held.

const SALUTE_COLOR := Color(1.0, 0.7, 0.24)
## Charge held this long reads as full on the ring's fill and on the release feedback.
const FULL_CHARGE_SECONDS := 2.5
const TICK_EVERY_SECONDS := 0.32
const CHARGE_PITCH_START := 0.8
const CHARGE_PITCH_END := 1.6

var _charging: bool = false
var _charge_seconds: float = 0.0
var _ring: CharmBlastVfx
var _cast_direction: Vector3 = Vector3.BACK
var _tick_clock: float = 0.0


func get_cooldown_policy() -> StringName:
	return &"manual"


func get_activation_cost(_context: CharmActivationContext) -> float:
	return 0.0


func activate(context: CharmActivationContext) -> bool:
	var stamina := actor.get("stamina") as StaminaComponent
	if (
		_charging
		or not is_instance_valid(stamina)
		or stamina.get_current_sp() <= 0.0
		or not _begin_cast_lock()
	):
		return false
	_charging = true
	_charge_seconds = 0.0
	_tick_clock = 0.0
	_cast_direction = context.direction
	_ring = CharmBlastVfx.charge(
		actor.get_parent(),
		actor.global_position,
		CharmBlastVfx.Kind.GOLD,
		_current_radius(),
		SALUTE_COLOR
	)
	CharmFeel.sound(actor, CharmFeel.TICK_SOUND, actor.global_position, -6.0, CHARGE_PITCH_START)
	set_physics_process(true)
	_play_cast_animation(&"channel", _cast_direction)
	return true


func on_input_held(_context: CharmActivationContext, delta: float) -> bool:
	return _charging and delta > 0.0


func _physics_process(delta: float) -> void:
	if not _charging or not is_instance_valid(actor) or bool(actor.get("dead")):
		cancel_active()
		return
	var stamina := actor.get("stamina") as StaminaComponent
	if not is_instance_valid(stamina):
		cancel_active()
		return
	var cost := definition.get_param_float(&"sp_per_second", 100.0) * maxf(0.0, delta)
	var spent := minf(stamina.get_current_sp(), cost)
	stamina.try_consume(spent)
	_charge_seconds += spent / definition.get_param_float(&"sp_per_second")
	if stamina.get_current_sp() <= 0.0:
		_release()
		return
	if is_instance_valid(_ring):
		_ring.set_radius(_current_radius())
		_ring.set_fuse(_charge_fraction())
		_ring.global_position = actor.global_position
	_tick_clock -= delta
	if _tick_clock <= 0.0:
		_tick_clock = TICK_EVERY_SECONDS
		var pitch := lerpf(CHARGE_PITCH_START, CHARGE_PITCH_END, _charge_fraction())
		CharmFeel.sound(actor, CharmFeel.TICK_SOUND, actor.global_position, -8.0, pitch)
		CharmFeel.shake(actor, 1.0 + _charge_fraction() * 2.0, 0.08)


func on_input_released(_context: CharmActivationContext) -> bool:
	if not _charging:
		return false
	_release()
	return true


func _current_radius() -> float:
	return (
		definition.get_param_float(&"min_radius_units", 0.75)
		+ _charge_seconds * definition.get_param_float(&"radius_per_second", 1.5)
	)


func _charge_fraction() -> float:
	return clampf(_charge_seconds / FULL_CHARGE_SECONDS, 0.0, 1.0)


func _release() -> void:
	if not _charging:
		return
	var radius := _current_radius()
	var power := _charge_fraction()
	var at := actor.global_position
	var damage := _get_base_damage() * definition.get_param_float(&"damage_multiplier", 1.0)
	if is_instance_valid(_ring):
		_ring.set_radius(radius)
		_ring.global_position = at
		_ring.detonate()
	_ring = null
	CharmVfx.spawn(actor.get_parent(), at + Vector3.UP * 0.5, SALUTE_COLOR, 1.2 + power, 0.3)
	CharmFeel.shake(actor, minf(10.0, 4.0 + _charge_seconds * 2.5), 0.24)
	CharmFeel.flash(actor, SALUTE_COLOR, lerpf(0.07, 0.14, power), 0.16)
	CharmFeel.shockwave(
		actor, at + Vector3.UP * 0.5, SALUTE_COLOR, 90.0 + radius * 45.0, 0.012 + power * 0.008
	)
	CharmFeel.sound(actor, CharmFeel.IMPACT_SOUND, at, -4.0, lerpf(1.1, 0.75, power))
	var hit_confirmed := false
	for target in _targets_in_radius(at, radius):
		if _damage_target(target, damage, at, 1.4) > 0.0:
			hit_confirmed = true
	if hit_confirmed:
		CharmFeel.sound(actor, CharmFeel.HIT_SOUND, at, -6.0)
		CharmFeel.hitstop(actor, minf(0.09, 0.04 + _charge_seconds * 0.02))
	runtime.start_cooldown()
	_play_cast_animation(&"release", _cast_direction, 0.45, true)
	_clear_charge()


func cancel_active() -> void:
	_stop_cast_animation()
	_clear_charge()


func _clear_charge() -> void:
	_end_cast_lock()
	set_physics_process(false)
	_charging = false
	_charge_seconds = 0.0
	if is_instance_valid(_ring):
		_ring.dismiss()
	_ring = null
