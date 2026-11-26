class_name BarrelBullet
extends Node3D

const IMPACT_SCENE := preload("res://gameplay/enemies/barrel/barrel_bullet_impact.tscn")
const MAX_SWEEPS_PER_FRAME := 8
const SEPARATION := 0.01
const MIN_BOUNCE_SPEED := 0.6
const IMPACT_INTERVAL := 0.1
## Below this on-screen speed the blob keeps its last heading instead of spinning.
const MIN_SCREEN_SPEED := 0.05
## The ink blob jiggles while it flies.
const WOBBLE_FREQUENCY_HZ := 7.0
const WOBBLE_AMOUNT := 0.09
## A ground bounce flattens the blob along its path, then it springs back.
const BOUNCE_SQUASH := 0.4
const BOUNCE_RECOVER_SECONDS := 0.2

@export_range(0.1, 30.0, 0.1, "suffix:s") var lifetime: float = 8.0
@export_range(0.0, 50.0, 0.1, "suffix:m/s²") var gravity: float = 22.0
@export_range(0.0, 1.0, 0.01) var ground_bounce: float = 0.95
## Size of the ink blob artwork only; the hit radius stays the Sweep shape.
@export_range(0.25, 4.0, 0.05) var visual_scale: float = 1.0

## Push, slow and screen ink applied when this blob costs Foxy HP; none when unset.
var ink_hit: BarrelInkHit

var _source: Node
var _source_team: int = 0
var _direction: Vector3 = Vector3.FORWARD
var _speed: float = 0.0
var _velocity: Vector3 = Vector3.ZERO
var _damage: float = 0
var _remaining_lifetime: float = 0.0
var _impact_cooldown: float = 0.0
var _finished: bool = false
var _age_seconds: float = 0.0
var _since_bounce_seconds: float = BOUNCE_RECOVER_SECONDS
## Heading of the artwork on screen; the texture points its head to +x.
var _screen_angle: float = 0.0

@onready var hitbox: HitBox = $HitBox
@onready var sweep: ShapeCast3D = $Sweep
@onready var trail: GPUParticles3D = $Trail
@onready var sprite: Sprite3D = $Sprite3D


func launch(
	source: Node, source_team: int, direction: Vector3, speed: float, damage: float
) -> void:
	_source = source
	_source_team = source_team
	_direction = Vector3(direction.x, 0.0, direction.z).normalized()
	_speed = maxf(0.0, speed)
	_velocity = _direction * _speed
	_damage = maxf(0.0, damage)


func _ready() -> void:
	_remaining_lifetime = lifetime
	sweep.collision_mask = (
		CombatLayers.WORLD | CombatLayers.ENEMY_BODY | CombatLayers.PLAYER_HURTBOX
	)
	if _source is CollisionObject3D:
		sweep.add_exception(_source)
	hitbox.monitoring = false
	hitbox.actor = _source
	hitbox.team = _source_team
	hitbox.damage_prepared.connect(_on_damage_prepared)
	hitbox.hit_confirmed.connect(_on_hit_confirmed)
	var damage := DamageContext.new()
	damage.source = _source
	damage.source_team = _source_team
	damage.base_amount_hp = _damage
	damage.amount_hp = _damage
	damage.tag = &"projectile"
	damage.knockback_multiplier = 0.0
	if is_instance_valid(_source) and _damage > 0.0:
		hitbox.begin_attack_with_context(damage)
		# ShapeCast owns sampling; the HitBox only dispatches and deduplicates damage.
		hitbox.set_physics_process(false)


func _process(delta: float) -> void:
	_age_seconds += delta
	_since_bounce_seconds += delta
	_orient_sprite()


func _physics_process(delta: float) -> void:
	if _finished:
		return
	var elapsed := minf(maxf(delta, 0.0), _remaining_lifetime)
	_impact_cooldown = maxf(0.0, _impact_cooldown - elapsed)
	_velocity.y -= gravity * elapsed
	_move_bullet(elapsed)
	_remaining_lifetime -= elapsed
	if not _finished and _remaining_lifetime <= 0.0:
		finish()


func _move_bullet(delta: float) -> void:
	var remaining := delta
	for _step in MAX_SWEEPS_PER_FRAME:
		if remaining <= 0.00001 or _velocity.is_zero_approx():
			return
		var motion := _velocity * remaining
		sweep.target_position = sweep.global_basis.inverse() * motion
		sweep.force_shapecast_update()
		if not sweep.is_colliding():
			global_position += motion
			return
		var fraction := clampf(sweep.get_closest_collision_safe_fraction(), 0.0, 1.0)
		global_position += motion * fraction
		remaining *= 1.0 - fraction
		# A player hit takes precedence when several colliders are reached together.
		for index in sweep.get_collision_count():
			var hurtbox := sweep.get_collider(index) as HurtBox
			if hurtbox != null:
				hitbox.try_hit(hurtbox)
				finish()
				return
		var normal := sweep.get_collision_normal(0)
		if normal.is_zero_approx():
			return
		normal = normal.normalized()
		var approach_speed := -_velocity.dot(normal)
		if approach_speed <= 0.0:
			global_position += normal * SEPARATION
			return
		if _impact_cooldown <= 0.0 and approach_speed >= MIN_BOUNCE_SPEED:
			_spawn_impact(sweep.get_collision_point(0), normal)
			_impact_cooldown = IMPACT_INTERVAL
		if normal.y > 0.7:
			if approach_speed >= MIN_BOUNCE_SPEED:
				_since_bounce_seconds = 0.0
			var bounce := ground_bounce if approach_speed >= MIN_BOUNCE_SPEED else 0.0
			_velocity += normal * approach_speed * (1.0 + bounce)
		else:
			_velocity = _velocity.bounce(normal)
		var horizontal := Vector3(_velocity.x, 0.0, _velocity.z)
		if not horizontal.is_zero_approx():
			_direction = horizontal.normalized()
		global_position += normal * SEPARATION


## Only Foxy is pushed; other targets of the blob keep taking no knockback.
func _on_damage_prepared(damage: DamageContext, target: Node) -> void:
	var player := target as Player
	if player == null or ink_hit == null:
		return
	damage.knockback_multiplier = ink_hit.knockback_multiplier
	# The player is pushed away from the origin, so put it behind them along the flight.
	damage.origin = player.global_position - _direction


## Runs only when HP was lost, so a dodge or post-hit immunity leaves no ink or slow.
func _on_hit_confirmed(_damage: DamageContext, target: Node, _applied_hp: float) -> void:
	var player := target as Player
	if player != null and ink_hit != null:
		ink_hit.apply_to(player)


func finish() -> void:
	if _finished:
		return
	_finished = true
	hitbox.end_attack()
	var parent := get_parent()
	if is_instance_valid(parent) and not parent.is_queued_for_deletion():
		_spawn_impact(global_position)
		trail.emitting = false
		trail.reparent(parent, true)
		get_tree().create_timer(trail.lifetime + 0.2).timeout.connect(trail.queue_free)
	queue_free()


## `normal` is the surface hit; a floor hit leaves an ink stain, a mid-air hit only splashes.
func _spawn_impact(at: Vector3, normal: Vector3 = Vector3.ZERO) -> void:
	var parent := get_parent()
	if not is_instance_valid(parent) or parent.is_queued_for_deletion():
		return
	var impact := IMPACT_SCENE.instantiate() as BarrelInkSplash
	parent.add_child(impact)
	impact.global_position = at
	impact.play(normal)


## Faces the camera like a billboard, turned so the blob's head leads along its flight on
## screen, with a jiggle and a squash after each bounce.
func _orient_sprite() -> void:
	var camera := get_viewport().get_camera_3d()
	if not is_instance_valid(camera):
		return
	var facing := camera.global_basis.orthonormalized()
	var on_screen := facing.inverse() * _velocity
	if Vector2(on_screen.x, on_screen.y).length() > MIN_SCREEN_SPEED:
		_screen_angle = atan2(on_screen.y, on_screen.x)
	var squash := (
		BOUNCE_SQUASH * clampf(1.0 - _since_bounce_seconds / BOUNCE_RECOVER_SECONDS, 0.0, 1.0)
	)
	var wobble := sin(_age_seconds * TAU * WOBBLE_FREQUENCY_HZ) * WOBBLE_AMOUNT
	var stretch := Vector3(1.0 + wobble - squash, 1.0 - wobble + squash * 0.6, 1.0)
	sprite.global_basis = (
		facing * Basis(Vector3.BACK, _screen_angle) * Basis.from_scale(stretch * visual_scale)
	)
