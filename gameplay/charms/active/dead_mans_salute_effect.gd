class_name DeadMansSaluteEffect
extends CharmEffect
## Hold-to-charge AoE blast with delta-time SP drain.

var _charging: bool = false
var _charge_seconds: float = 0.0
var _ring: CharmVfx
var _cast_direction: Vector3 = Vector3.BACK


func get_cooldown_policy() -> StringName:
	return &"manual"


func get_activation_cost(_context: CharmActivationContext) -> float:
	return 0.0


func activate(context: CharmActivationContext) -> bool:
	if _charging or not is_instance_valid(actor):
		return false
	_charging = true
	_charge_seconds = 0.0
	_cast_direction = context.direction
	_ring = CharmVfx.spawn(
		actor.get_parent(),
		actor.global_position,
		CharmVfx.GOLD,
		definition.get_param_float(&"min_radius_units", 0.75),
		1.0,
		CharmVfx.Style.CHARGE
	)
	_ring.sustained = true
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
	if not stamina.try_consume(cost):
		_release()
		return
	if stamina.get_current_sp() <= 0.0:
		_release()
		return
	_charge_seconds += maxf(0.0, delta)
	if is_instance_valid(_ring):
		var radius := (
			definition.get_param_float(&"min_radius_units", 0.75)
			+ (_charge_seconds * definition.get_param_float(&"radius_per_second", 1.5))
		)
		_ring.set_radius(radius)
		_ring.global_position = actor.global_position + Vector3.UP * 0.06


func on_input_released(_context: CharmActivationContext) -> bool:
	if not _charging:
		return false
	_release()
	return true


func _release() -> void:
	if not _charging:
		return
	var radius := (
		definition.get_param_float(&"min_radius_units", 0.75)
		+ (_charge_seconds * definition.get_param_float(&"radius_per_second", 1.5))
	)
	var damage := _get_base_damage() * definition.get_param_float(&"damage_multiplier", 1.0)
	CharmVfx.spawn(actor.get_parent(), actor.global_position, CharmVfx.GOLD, radius, 0.45)
	get_node("/root/ScreenShakeController").request(minf(10.0, 4.0 + _charge_seconds * 2.0), 0.24)
	var hit_confirmed := false
	for node in actor.get_tree().get_nodes_in_group("enemy"):
		if (
			not node is Node3D
			or (node as Node3D).global_position.distance_to(actor.global_position) > radius
		):
			continue
		if node.has_method("receive_damage"):
			var context := DamageContext.new()
			context.source = actor
			context.source_team = actor.get("team")
			context.amount_hp = damage
			context.base_amount_hp = damage
			context.tag = definition.charm_id
			if float(node.call("receive_damage", context)) > 0.0:
				hit_confirmed = true
	if hit_confirmed:
		get_node("/root/HitstopController").request(minf(0.09, 0.04 + _charge_seconds * 0.015))
	runtime.start_cooldown()
	_play_cast_animation(&"release", _cast_direction, 0.45, true)
	_clear_charge()


func cancel_active() -> void:
	_stop_cast_animation()
	_clear_charge()


func _clear_charge() -> void:
	set_physics_process(false)
	_charging = false
	_charge_seconds = 0.0
	if is_instance_valid(_ring):
		_ring.queue_free()
	_ring = null


func _get_base_damage() -> float:
	var weapon_controller := actor.get("weapon_controller") as WeaponController
	if is_instance_valid(weapon_controller) and weapon_controller.equipped != null:
		var attack := weapon_controller.equipped.get_attack(&"normal")
		if attack != null:
			return attack.damage_hp
	return 1.0
