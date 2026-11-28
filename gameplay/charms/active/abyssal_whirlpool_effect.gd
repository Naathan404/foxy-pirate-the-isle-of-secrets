class_name AbyssalWhirlpoolEffect
extends CharmEffect
## Opens a whirlpool that drags every ordinary enemy within `pull_radius_units` towards its eye,
## harder as it runs, then erupts in a geyser that hits every enemy within `radius_units` and
## shatters the scenery there: props of up to `prop_break_max_hp` break outright, sturdier ones
## (a campfire, a boat) only take the blast's damage.
## The wide outer swirl shows the pull, a brighter inner ring the blast; the camera rumbles
## while it turns.

const SHOCKWAVE_DURATION := 0.5
const SHOCKWAVE_STRENGTH := 0.02
const SHOCKWAVE_COLOR := Color("68caff")
const SHOCKWAVE_RADIUS_PIXELS := 240.0
const WATER := Color("3fb6ff")
const FOAM := Color("9ee8ff")
## Pulled enemies stop this close to the eye instead of piling onto one point.
const EYE_RADIUS_METERS := 0.7
const RUMBLE_EVERY_SECONDS := 0.28

var _zone: Area3D
var _pull_vfx: CharmBlastVfx
var _blast_vfx: CharmBlastVfx
var _duration: float = 0.0
var _remaining: float = 0.0
var _rumble_clock: float = 0.0
var _exploded: bool = false
var _cast_direction: Vector3 = Vector3.BACK


func activate(context: CharmActivationContext) -> bool:
	if not super.can_activate(context) or not context.has_target or not is_instance_valid(actor):
		return false
	if not _begin_cast_lock():
		return false
	var pull_radius := _pull_radius()
	_zone = Area3D.new()
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = pull_radius
	shape.shape = sphere
	_zone.add_child(shape)
	_zone.collision_layer = 0
	_zone.collision_mask = CombatLayers.ENEMY_HURTBOX
	actor.get_parent().add_child(_zone)
	_zone.global_position = context.target_position
	_duration = definition.get_param_float(&"duration_seconds", 1.5)
	_remaining = _duration
	_rumble_clock = 0.0
	_pull_vfx = CharmBlastVfx.charge(
		actor.get_parent(), _zone.global_position, CharmBlastVfx.Kind.TIDE, pull_radius, WATER
	)
	_blast_vfx = CharmBlastVfx.charge(
		actor.get_parent(),
		_zone.global_position,
		CharmBlastVfx.Kind.SPARK,
		definition.get_param_float(&"radius_units", 3.5),
		FOAM
	)
	CharmFeel.sound(actor, CharmFeel.WHOOSH_SOUND, _zone.global_position, -4.0, 0.55)
	_exploded = false
	set_physics_process(true)
	_cast_direction = context.target_position - actor.global_position
	_play_cast_animation(&"channel", _cast_direction, _remaining)
	return true


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_zone) or not is_instance_valid(actor) or bool(actor.get("dead")):
		cancel_active()
		return
	var elapsed := 1.0 - _remaining / maxf(0.01, _duration)
	_pull_enemies(delta, elapsed)
	if is_instance_valid(_pull_vfx):
		_pull_vfx.set_fuse(elapsed)
	if is_instance_valid(_blast_vfx):
		_blast_vfx.set_fuse(elapsed)
	_rumble_clock -= delta
	if _rumble_clock <= 0.0:
		_rumble_clock = RUMBLE_EVERY_SECONDS
		CharmFeel.shake(actor, 1.5 + elapsed * 2.5, RUMBLE_EVERY_SECONDS)
	_remaining -= maxf(0.0, delta)
	if _remaining <= 0.0 and not _exploded:
		_explode()


## Drags every ordinary enemy in the pull area towards the eye, faster as the whirlpool runs.
func _pull_enemies(delta: float, elapsed: float) -> void:
	var speed := lerpf(
		definition.get_param_float(&"pull_speed_start", 3.0),
		definition.get_param_float(&"pull_speed_end", 9.0),
		elapsed
	)
	for area: Area3D in _zone.get_overlapping_areas():
		var hurtbox := area as HurtBox
		if hurtbox == null or not is_instance_valid(hurtbox.actor) or not hurtbox.actor is Node3D:
			continue
		var target := hurtbox.actor as Node3D
		# Scenery shares the enemy hurtbox layer; only creatures are dragged in.
		if (
			not target.is_in_group("enemy")
			or target.is_in_group("boss")
			or target.is_in_group("large")
			or target.is_in_group("immovable")
		):
			continue
		var to_eye := _zone.global_position - target.global_position
		to_eye.y = 0.0
		var distance := to_eye.length()
		if distance <= EYE_RADIUS_METERS:
			continue
		var motion := to_eye / distance * minf(distance - EYE_RADIUS_METERS, delta * speed)
		if target is CharacterBody3D:
			(target as CharacterBody3D).move_and_collide(motion)
		else:
			target.global_position += motion


func _explode() -> void:
	_exploded = true
	var at := _zone.global_position
	var radius := definition.get_param_float(&"radius_units", 3.5)
	var damage := _get_base_damage() * definition.get_param_float(&"damage_multiplier", 1.0)
	if is_instance_valid(_pull_vfx):
		_pull_vfx.dismiss()
	_pull_vfx = null
	if is_instance_valid(_blast_vfx):
		_blast_vfx.dismiss()
	_blast_vfx = null
	CharmBlastVfx.burst(actor.get_parent(), at, CharmBlastVfx.Kind.TIDE, radius, WATER)
	CharmVfx.spawn(actor.get_parent(), at, CharmVfx.TIDE, radius * 1.2, 0.4)
	CharmFeel.shake(actor, 9.0, 0.26)
	CharmFeel.flash(actor, FOAM, 0.12, 0.16)
	CharmFeel.shockwave(
		actor,
		at + Vector3.UP * 0.4,
		SHOCKWAVE_COLOR,
		SHOCKWAVE_RADIUS_PIXELS,
		SHOCKWAVE_STRENGTH,
		SHOCKWAVE_DURATION
	)
	CharmFeel.sound(actor, CharmFeel.IMPACT_SOUND, at, -2.0, 0.7)
	var hit_confirmed := false
	for target in _targets_in_radius(at, radius):
		if _damage_target(target, damage, at, 1.4) > 0.0:
			hit_confirmed = true
	if _damage_props(at, radius, damage):
		hit_confirmed = true
	if hit_confirmed:
		CharmFeel.sound(actor, CharmFeel.HIT_SOUND, at, -5.0)
		CharmFeel.hitstop(actor, 0.08)
	_play_cast_animation(&"release", _cast_direction, 0.4, true)
	_clear_zone()


## Breakable scenery is not in the enemy group, so the blast finds it in the room itself.
func _damage_props(at: Vector3, radius: float, damage: float) -> bool:
	var scene := actor.get_tree().current_scene
	if scene == null:
		return false
	var break_max_hp := definition.get_param_float(&"prop_break_max_hp", 10.0)
	var hit := false
	for node in scene.find_children("*", "DestructibleProp", true, false):
		var prop := node as DestructibleProp
		var offset := prop.global_position - at
		offset.y = 0.0
		if offset.length() > radius:
			continue
		if prop.max_hp <= break_max_hp:
			prop.break_from_impact()
			hit = true
		elif _damage_target(prop, damage, at, 0.0) > 0.0:
			hit = true
	return hit


func _pull_radius() -> float:
	return definition.get_param_float(&"pull_radius_units", 6.0)


func cancel_active() -> void:
	_stop_cast_animation()
	_clear_zone()


func _clear_zone() -> void:
	_end_cast_lock()
	set_physics_process(false)
	if is_instance_valid(_zone):
		_zone.queue_free()
	_zone = null
	for vfx: CharmBlastVfx in [_pull_vfx, _blast_vfx]:
		if is_instance_valid(vfx):
			vfx.dismiss()
	_pull_vfx = null
	_blast_vfx = null
	_remaining = 0.0
	_exploded = false
