class_name ShadowLungeEffect
extends CharmEffect
## Collision-aware dash-length lunge with one sweep hitbox.

const ATTACK_SCENE := preload("res://gameplay/charms/active/charm_active_attack.tscn")
var _execution: CharmActiveAttack
var _cast_direction: Vector3 = Vector3.BACK


func can_activate(context: CharmActivationContext) -> bool:
	return (
		super.can_activate(context)
		and context != null
		and context.is_valid()
		and is_instance_valid(actor)
		and is_instance_valid(actor.get_parent())
		and definition.get_param_float(&"damage_multiplier", 3.0) > 0.0
	)


func activate(context: CharmActivationContext) -> bool:
	if not can_activate(context):
		return false
	var direction := context.direction
	if context.has_target:
		direction = context.target_position - actor.global_position
	direction.y = 0.0
	if direction.is_zero_approx():
		direction = Vector3.BACK
	direction = direction.normalized()
	var distance := definition.get_param_float(&"dash_distance_units", 5.0)
	var origin := actor.global_position
	var motion := direction * distance
	var travel_distance := distance
	if actor is CharacterBody3D:
		var collision := (actor as CharacterBody3D).move_and_collide(motion)
		if collision != null:
			travel_distance = origin.distance_to(actor.global_position)
	else:
		actor.global_position += motion
	if travel_distance <= 0.001:
		return true
	var start := origin + Vector3.UP * 0.7
	var end := actor.global_position + Vector3.UP * 0.7
	CharmVfx.streak(actor.get_parent(), start, end, CharmVfx.SHADOW, 1.5, 0.28)
	var side := direction.cross(Vector3.UP) * 0.3
	for offset: Vector3 in [side, -side]:
		CharmVfx.streak(
			actor.get_parent(),
			start + offset,
			end + offset,
			Color(CharmVfx.SHADOW, 0.45),
			0.6,
			0.36
		)
	CharmVfx.spawn(actor.get_parent(), origin, CharmVfx.SHADOW, 0.9)
	CharmVfx.spawn(actor.get_parent(), actor.global_position, CharmVfx.SHADOW, 1.2)
	var execution := ATTACK_SCENE.instantiate() as CharmActiveAttack
	if execution == null:
		return false
	actor.get_parent().add_child(execution)
	_execution = execution
	_cast_direction = direction
	execution.travel_finished.connect(_on_lunge_finished)
	execution.context = AttackContext.new()
	execution.context.actor = actor
	execution.context.team = actor.get("team")
	execution.context.attack_id = Time.get_ticks_usec()
	execution.context.action = definition.charm_id
	execution.context.origin = origin
	execution.context.direction = direction
	execution.context.damage_hp = (
		_get_base_damage() * definition.get_param_float(&"damage_multiplier", 3.0)
	)
	execution.global_position = origin
	execution.trail_color = CharmVfx.SHADOW
	execution.trail_width = 0.8
	execution.hitstop_seconds = 0.06
	execution.shake_pixels = 5.5
	execution.hitbox_scale = Vector3(1.0, 1.0, 1.5)
	execution.forward_offset = 0.0
	execution.travel_speed_units_per_second = travel_distance / 0.18
	execution.max_travel_distance = travel_distance
	execution.activate()
	execution.release_after(0.28)
	_play_cast_animation(
		&"active", direction, travel_distance / execution.travel_speed_units_per_second
	)
	return true


func cancel_active() -> void:
	_stop_cast_animation()
	if is_instance_valid(_execution):
		_execution.deactivate()
		_execution.queue_free()
	_execution = null


func _on_lunge_finished() -> void:
	_play_cast_animation(&"recover", _cast_direction, 0.1, true)


func _get_base_damage() -> float:
	var weapon_controller := actor.get("weapon_controller") as WeaponController
	if is_instance_valid(weapon_controller) and weapon_controller.equipped != null:
		var attack := weapon_controller.equipped.get_attack(&"normal")
		if attack != null:
			return attack.damage_hp
	return 1.0
