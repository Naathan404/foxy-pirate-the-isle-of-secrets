class_name ShadowLungeEffect
extends CharmEffect
## Lunges through every enemy on the way, striking each once. Only walls and the room's edge
## stop it: enemy bodies are left out of Foxy's collision mask for the length of the lunge.
## Each step strikes the enemies near the segment just travelled, so a long step never skips
## one.
## Leaves a line of shadow after-images, a cut through each enemy struck and a burst at both
## ends.

const HEIGHT := Vector3.UP * 0.65
const GHOST_TEXTURE: Texture2D = preload("res://assets/sprites/foxy/charm_casts/shadow_lunge.png")
## Ghost frame of the lunge pose in shadow_lunge.png (4 columns, 2 rows).
const GHOST_FRAME := 1
const GHOST_PIXEL_SIZE := 0.009
const GHOST_EVERY_SECONDS := 0.03
const GHOST_FADE_SECONDS := 0.32
const CUT_LENGTH_METERS := 2.4
const CUT_WIDTH_METERS := 0.55
## Enemies this far above or below Foxy's path are still struck (a lunge off a pier or step).
const STRIKE_HEIGHT_SLACK_METERS := 2.0

var _remaining := 0.0
var _speed := 0.0
var _direction := Vector3.BACK
var _start := Vector3.ZERO
var _trail: CharmVfx
var _damage := 0.0
var _struck: Dictionary[int, bool] = {}
var _ghost_clock := 0.0
var _saved_mask := 0
var _hit_radius := 1.0


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
	_damage = _get_base_damage() * definition.get_param_float(&"damage_multiplier")
	_struck.clear()
	_ghost_clock = 0.0
	_hit_radius = definition.get_param_float(&"hit_radius_units", 1.0)
	var body := actor as CharacterBody3D
	_saved_mask = body.collision_mask
	body.collision_mask &= ~CombatLayers.ENEMY_BODY
	_start = actor.global_position + HEIGHT
	_trail = CharmVfx.streak(actor.get_parent(), _start, _start, CharmVfx.SHADOW, 0.9, seconds)
	_trail.sustained = true
	CharmBlastVfx.burst(
		actor.get_parent(), actor.global_position, CharmBlastVfx.Kind.SHADOW, 1.3, CharmVfx.SHADOW
	)
	CharmFeel.shake(actor, 3.0, 0.1)
	CharmFeel.sound(actor, CharmFeel.WHOOSH_SOUND, actor.global_position, -5.0, 0.8)
	_play_cast_animation(&"active", _direction, seconds)
	set_physics_process(true)
	return true


func _physics_process(delta: float) -> void:
	if _remaining <= 0.0 or delta <= 0.0:
		return
	var distance := minf(_remaining, _speed * delta)
	var body := actor as CharacterBody3D
	var from := actor.global_position
	var collision := body.move_and_collide(_direction * distance)
	var moved := distance
	if collision != null:
		moved = distance - collision.get_remainder().length()
	_remaining -= distance
	_strike_along(from, actor.global_position)
	_trail.set_endpoints(_start, actor.global_position + HEIGHT, 0.9)
	_ghost_clock -= delta
	if _ghost_clock <= 0.0:
		_ghost_clock = GHOST_EVERY_SECONDS
		_drop_after_image(actor.global_position)
	if collision != null or moved <= 0.0001 or _remaining <= 0.001:
		_finish()


## Every enemy within the strike radius of the segment Foxy just covered takes the strike once.
## Measured flat on the ground, so a height difference between Foxy and the enemy does not
## make the lunge pass through without hitting.
func _strike_along(from: Vector3, to: Vector3) -> void:
	var middle := (from + to) * 0.5
	var reach := from.distance_to(to) * 0.5 + _hit_radius + STRIKE_HEIGHT_SLACK_METERS
	for target in _targets_in_radius(middle, reach):
		if absf(target.global_position.y - middle.y) > STRIKE_HEIGHT_SLACK_METERS:
			continue
		if _flat_distance_to_segment(target.global_position, from, to) <= _hit_radius:
			_strike(target)


static func _flat_distance_to_segment(point: Vector3, from: Vector3, to: Vector3) -> float:
	var p := Vector2(point.x, point.z)
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	var along := b - a
	if along.length_squared() < 0.000001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(along) / along.length_squared(), 0.0, 1.0)
	return p.distance_to(a + along * t)


func _strike(target: Node3D) -> void:
	if not is_instance_valid(target) or target == actor or _struck.has(target.get_instance_id()):
		return
	_struck[target.get_instance_id()] = true
	if _damage_target(target, _damage, actor.global_position, 1.2) <= 0.0:
		return
	var at := target.global_position + HEIGHT
	var across := _direction.cross(Vector3.UP).normalized() * CUT_LENGTH_METERS * 0.5
	CharmVfx.streak(
		actor.get_parent(), at - across + _direction * 0.3, at + across - _direction * 0.3,
		CharmVfx.SHADOW, CUT_WIDTH_METERS, 0.22
	)
	CharmVfx.spawn(actor.get_parent(), at, CharmVfx.SHADOW, 0.9)
	CharmFeel.local_hitstop(actor, null, target, 0.07)
	CharmFeel.sound(actor, CharmFeel.HIT_SOUND, at, -5.0, randf_range(0.85, 1.0))
	if _struck.size() == 1:
		CharmFeel.shake(actor, 6.5, 0.16)
		CharmFeel.flash(actor, CharmVfx.SHADOW, 0.1, 0.12)


func _drop_after_image(at: Vector3) -> void:
	var ghost := Sprite3D.new()
	ghost.texture = GHOST_TEXTURE
	ghost.hframes = 4
	ghost.vframes = 2
	ghost.frame = GHOST_FRAME
	ghost.flip_h = _direction.dot(_camera_right()) < 0.0
	ghost.pixel_size = GHOST_PIXEL_SIZE
	ghost.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	ghost.shaded = false
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	ghost.modulate = Color(0.62, 0.36, 1.0, 0.7)
	actor.get_parent().add_child(ghost)
	ghost.global_position = at + Vector3.UP * 1.1
	var fade := ghost.create_tween().set_parallel()
	fade.tween_property(ghost, "modulate:a", 0.0, GHOST_FADE_SECONDS)
	fade.tween_property(ghost, "scale", Vector3.ONE * 0.85, GHOST_FADE_SECONDS)
	fade.chain().tween_callback(ghost.queue_free)


func _camera_right() -> Vector3:
	var camera := actor.get_viewport().get_camera_3d()
	return camera.global_basis.x if is_instance_valid(camera) else Vector3.RIGHT


func _finish() -> void:
	_remaining = 0.0
	set_physics_process(false)
	_restore_mask()
	_end_cast_lock()
	if is_instance_valid(_trail):
		_trail.queue_free()
	_trail = null
	var landing := actor.global_position
	CharmBlastVfx.burst(
		actor.get_parent(), landing, CharmBlastVfx.Kind.SHADOW, 1.8, CharmVfx.SHADOW
	)
	if not _struck.is_empty():
		CharmFeel.hitstop(actor, 0.05)
		CharmFeel.shockwave(actor, landing + HEIGHT, CharmVfx.SHADOW, 150.0, 0.012, 0.4)
	_play_cast_animation(&"recover", _direction, 0.1, true)


func _restore_mask() -> void:
	if _saved_mask != 0 and is_instance_valid(actor) and actor is CharacterBody3D:
		(actor as CharacterBody3D).collision_mask = _saved_mask
	_saved_mask = 0


func cancel_active() -> void:
	_remaining = 0.0
	set_physics_process(false)
	_restore_mask()
	if is_instance_valid(_trail):
		_trail.queue_free()
	_trail = null
	_stop_cast_animation()
