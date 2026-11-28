class_name ArrowRainAttack
extends CharmActiveAttack
## Một mũi tên Arrow Rain bay theo parabol rồi cắm xuống điểm rơi, kéo theo vệt lửa.

const FIRE_TRAIL: PackedScene = preload("res://assets/vfx/fire_trails/Fire_Trail.tscn")
## Shrinks the authored fire trail to arrow size.
const TRAIL_WIDTH_SCALE := 0.5
const TRAIL_TIME_SCALE := 0.24
## The flame leaves from the fletching, this far behind the arrow's centre.
const TRAIL_BACK_METERS := 0.45
const LANDING_RADIUS_METERS := 0.9
const LANDING_COLOR := Color(1.0, 0.72, 0.3)

@export var flight_start: Vector3 = Vector3.ZERO
@export var flight_control: Vector3 = Vector3.ZERO
@export var flight_end: Vector3 = Vector3.ZERO
@export_range(0.1, 5.0, 0.01) var flight_duration: float = 0.8
@export_range(0.0, 1.0, 0.01) var impact_activation_progress: float = 0.5
@export_range(0.01, 1.0, 0.01) var impact_hold_seconds: float = 0.18

var volley_finisher: bool = false

var _elapsed: float = 0.0
var _impact_hold_remaining: float = 0.0
var _impact_armed: bool = false
var _previous_position: Vector3 = Vector3.ZERO
var _landed: bool = false
var _fire_trail: ProjectileFireTrail
var _heading: Vector3 = Vector3.DOWN

@onready var _sprite: Sprite3D = $Sprite3D
@onready var _sprite_scale: Vector3 = _sprite.scale


func _ready() -> void:
	super._ready()
	hitbox.damage_prepared.connect(_on_damage_prepared)
	hitbox.damage_applied.connect(_on_damage_applied)


func activate() -> void:
	if flight_start.is_zero_approx() and not global_position.is_zero_approx():
		flight_start = global_position
	if flight_control.is_zero_approx():
		flight_control = flight_start.lerp(flight_end, 0.5) + Vector3.UP * 4.0
	if flight_end.is_zero_approx():
		flight_end = global_position
	global_position = flight_start
	active = true
	launched = true
	hitbox.actor = context.actor
	hitbox.team = context.team
	hitbox.scale = hitbox_scale * context.hitbox_multiplier
	# Arrow Rain only deals damage while descending; the upward launch is visual-only.
	hitbox.end_attack()
	_elapsed = 0.0
	_impact_hold_remaining = maxf(0.01, impact_hold_seconds)
	_impact_armed = false
	_landed = false
	_impact_reported = false
	_previous_position = global_position
	_start_trail()
	_update_visual_basis(flight_control - flight_start)
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if not active or not is_instance_valid(context) or not is_instance_valid(context.actor):
		_cancel_and_free()
		return
	if bool(context.actor.get("dead")):
		_cancel_and_free()
		return
	var step := maxf(0.0, delta)
	_previous_position = global_position
	_elapsed += step
	var progress := clampf(_elapsed / maxf(0.01, flight_duration), 0.0, 1.0)
	var next_position := _quadratic_bezier(progress)
	global_position = next_position
	var tangent := _quadratic_bezier_derivative(progress)
	if not tangent.is_zero_approx():
		_update_visual_basis(tangent)
		if not _landed:
			_update_trail(tangent)

	if not _impact_armed and progress >= impact_activation_progress:
		_impact_armed = true
		if not hitbox.begin_attack_with_context(context.create_damage_context()):
			_cancel_and_free()
			return
		# Catch a target crossed between physics frames on the descending leg.
		_sweep_hit(_previous_position, global_position)
	elif _impact_armed:
		_sweep_hit(_previous_position, global_position)

	if progress >= 1.0:
		if not _landed:
			_landed = true
			if is_instance_valid(_trail):
				_trail.hide()
			_release_fire_trail()
			CharmBlastVfx.burst(
				get_parent(),
				flight_end,
				CharmBlastVfx.Kind.SPARK,
				LANDING_RADIUS_METERS,
				LANDING_COLOR
			)
			CharmFeel.sound(
				self, CharmFeel.IMPACT_SOUND, flight_end, -14.0, randf_range(1.1, 1.35)
			)
		_impact_hold_remaining -= step
		if _impact_hold_remaining <= 0.0:
			_cancel_and_free()


func _quadratic_bezier(progress: float) -> Vector3:
	var first := flight_start.lerp(flight_control, progress)
	var second := flight_control.lerp(flight_end, progress)
	return first.lerp(second, progress)


func _quadratic_bezier_derivative(progress: float) -> Vector3:
	var first_tangent := (1.0 - progress) * (flight_control - flight_start)
	var second_tangent := progress * (flight_end - flight_control)
	return 2.0 * (first_tangent + second_tangent)


func _sweep_hit(from: Vector3, to: Vector3) -> void:
	if not _impact_armed or from.is_equal_approx(to) or not is_instance_valid(get_world_3d()):
		return
	var query := PhysicsRayQueryParameters3D.create(from, to, CombatLayers.ENEMY_HURTBOX)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	if context.actor is CollisionObject3D:
		query.exclude = [(context.actor as CollisionObject3D).get_rid()]
	var collision := get_world_3d().direct_space_state.intersect_ray(query)
	if collision.is_empty() or not collision.collider is HurtBox:
		return
	global_position = collision.position
	hitbox.try_hit(collision.collider as HurtBox)


func _on_damage_prepared(damage: DamageContext, target: Node) -> void:
	if is_instance_valid(context):
		context.damage_prepared.emit(damage, target)


func _on_damage_applied(damage: DamageContext, target: Node, applied_hp: float) -> void:
	if is_instance_valid(context):
		context.damage_applied.emit(damage, target, applied_hp)


func _update_visual_basis(direction: Vector3) -> void:
	var camera := get_viewport().get_camera_3d()
	if not is_instance_valid(camera) or direction.is_zero_approx():
		return
	var screen_x := direction.dot(camera.global_basis.x)
	var screen_y := direction.dot(camera.global_basis.y)
	if is_zero_approx(screen_x) and is_zero_approx(screen_y):
		return
	var angle := atan2(screen_y, screen_x) + PI
	# Arrow.png points left in its source image. Keep the sprite camera-facing
	# while rotating its screen-space heading along the parabolic tangent.
	_sprite.global_basis = (
		camera.global_basis.orthonormalized()
		* Basis(Vector3.BACK, angle)
		* Basis.from_scale(_sprite_scale)
	)


func _start_trail() -> void:
	_fire_trail = ProjectileFireTrail.new(
		FIRE_TRAIL, get_parent(), _trail_anchor(), TRAIL_WIDTH_SCALE, TRAIL_TIME_SCALE
	)


func _update_trail(direction: Vector3) -> void:
	_heading = direction.normalized()
	if _fire_trail != null:
		_fire_trail.follow(_trail_anchor())


func _trail_anchor() -> Vector3:
	return global_position - _heading * TRAIL_BACK_METERS


func _release_fire_trail() -> void:
	if _fire_trail != null:
		_fire_trail.release(_trail_anchor())
	_fire_trail = null


func _exit_tree() -> void:
	super._exit_tree()
	_release_fire_trail()


func _cancel_and_free() -> void:
	deactivate()
	queue_free()
