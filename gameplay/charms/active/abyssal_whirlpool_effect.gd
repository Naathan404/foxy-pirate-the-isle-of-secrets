class_name AbyssalWhirlpoolEffect
extends CharmEffect
## Pulls ordinary enemies for a short window, then resolves one AoE blast.

const SHOCKWAVE_DURATION := 0.45
const SHOCKWAVE_STRENGTH := 0.013
const SHOCKWAVE_COLOR := Color("68caff")
const SHOCKWAVE_RADIUS_PIXELS := 160.0

var _zone: Area3D
var _remaining: float = 0.0
var _exploded: bool = false
var _cast_direction: Vector3 = Vector3.BACK


func activate(context: CharmActivationContext) -> bool:
	if not super.can_activate(context) or not context.has_target or not is_instance_valid(actor):
		return false
	if not _begin_cast_lock():
		return false
	_zone = Area3D.new()
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	var radius := definition.get_param_float(&"radius_units", 2.5)
	sphere.radius = radius
	shape.shape = sphere
	_zone.add_child(shape)
	_zone.collision_layer = 0
	_zone.collision_mask = CombatLayers.ENEMY_HURTBOX
	actor.get_parent().add_child(_zone)
	_zone.global_position = context.target_position
	_remaining = definition.get_param_float(&"duration_seconds", 1.5)
	var visual := CharmVfx.spawn(
		_zone, _zone.global_position, CharmVfx.TIDE, radius, _remaining, CharmVfx.Style.VORTEX
	)
	visual.sustained = true
	_exploded = false
	set_physics_process(true)
	_cast_direction = context.target_position - actor.global_position
	_play_cast_animation(&"channel", _cast_direction, _remaining)
	return true


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_zone) or not is_instance_valid(actor) or bool(actor.get("dead")):
		cancel_active()
		return
	for area: Area3D in _zone.get_overlapping_areas():
		var hurtbox := area as HurtBox
		if hurtbox == null or not is_instance_valid(hurtbox.actor) or not hurtbox.actor is Node3D:
			continue
		var target := hurtbox.actor as Node3D
		if (
			target.is_in_group("boss")
			or target.is_in_group("large")
			or target.is_in_group("immovable")
		):
			continue
		var direction := _zone.global_position - target.global_position
		direction.y = 0.0
		if direction.length() > 0.05:
			var motion := direction.normalized() * minf(direction.length(), delta * 3.0)
			if target is CharacterBody3D:
				(target as CharacterBody3D).move_and_collide(motion)
			else:
				target.global_position += motion
	_remaining -= maxf(0.0, delta)
	if _remaining <= 0.0 and not _exploded:
		_explode()


func _explode() -> void:
	_exploded = true
	var radius := definition.get_param_float(&"radius_units", 2.5)
	var damage := _get_base_damage() * definition.get_param_float(&"damage_multiplier", 1.0)
	CharmVfx.spawn(actor.get_parent(), _zone.global_position, CharmVfx.TIDE, radius * 1.2, 0.4)
	get_node("/root/ScreenShakeController").request(7.0, 0.22)
	get_node("/root/ShockwaveController").request_world(
		_zone.global_position,
		SHOCKWAVE_DURATION,
		SHOCKWAVE_STRENGTH,
		SHOCKWAVE_COLOR,
		SHOCKWAVE_RADIUS_PIXELS
	)
	var hit_confirmed := false
	for target in _targets_in_radius(_zone.global_position, radius):
		if _damage_target(target, damage, _zone.global_position, 1.4) > 0.0:
			hit_confirmed = true
	if hit_confirmed:
		get_node("/root/AudioManager").play_sfx_3d(
			preload("res://assets/audio/combat/bow_impact.wav"), _zone.global_position, -6.0
		)
		get_node("/root/HitstopController").request(0.07)
	_play_cast_animation(&"release", _cast_direction, 0.4, true)
	_clear_zone()


func cancel_active() -> void:
	_stop_cast_animation()
	_clear_zone()


func _clear_zone() -> void:
	_end_cast_lock()
	set_physics_process(false)
	if is_instance_valid(_zone):
		_zone.queue_free()
	_zone = null
	_remaining = 0.0
	_exploded = false
