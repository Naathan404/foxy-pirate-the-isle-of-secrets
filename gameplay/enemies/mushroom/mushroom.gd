class_name MushroomEnemy
extends EnemyBase

const SPORE_CLOUD = preload("res://gameplay/enemies/mushroom/mushroom_spore_cloud.gd")
const NORMAL_TEXTURE = preload("res://assets/sprites/enemies/mushroom/mushroom_footless_4dir.png")
const CHARGE_TEXTURE = preload("res://assets/sprites/enemies/mushroom/mushroom_charge_4dir.png")
const CHARGE_ANIMATION_SECONDS := 1.6
const HOP_FREQUENCY := 0.9
const HOP_HEIGHT := 0.16
const HOP_MIN_SPEED_FACTOR := 0.35
const CHARGE_TINT := Color(1.0, 1.0, 0.55, 1.0)
const CHARGE_PULSE_COUNT := 4.0
const EVADE_CHECK_UP := 1.2
const EVADE_CHECK_DOWN := 2.4
const EVADE_DIRECTION_ANGLES := [
	0.0,
	PI / 4.0,
	-PI / 4.0,
	PI / 2.0,
	-PI / 2.0,
	3.0 * PI / 4.0,
	-3.0 * PI / 4.0,
	PI,
]
const EVADE_DISTANCE_FACTORS := [1.0, 0.5, 0.25]

@export_group("Detection")
## Foxy must be inside this radius before the mushroom can detect or pursue them.
@export_range(0.1, 30.0, 0.1, "suffix:m") var detection_radius: float = 6.0

@export_group("Mushroom Movement")
@export_range(0.1, 30.0, 0.1, "suffix:m") var movement_radius: float = 12.0
@export_range(0.1, 5.0, 0.1) var chase_speed_scale: float = 0.8
@export_range(0.1, 5.0, 0.1) var wander_speed_scale: float = 0.55
@export_range(0.1, 3.0, 0.1, "suffix:s") var observe_seconds: float = 0.8
@export_range(0.1, 5.0, 0.1, "suffix:s") var retreat_seconds: float = 1.1
@export_range(0.1, 5.0, 0.1) var retreat_speed_scale: float = 0.7

@export_group("Defensive Hop")
@export_range(0.1, 10.0, 0.1, "suffix:m") var evade_distance: float = 2.0
@export_range(0.1, 2.0, 0.05, "suffix:s") var evade_duration_seconds: float = 0.45
@export_range(0.1, 10.0, 0.1, "suffix:s") var evade_cooldown_seconds: float = 2.5
@export_range(0.0, 2.0, 0.05, "suffix:m") var evade_hop_height: float = 0.4

@export_group("Poison Cloud")
## Foxy triggers an immediate charge within this distance when the attack is ready.
@export_range(0.1, 10.0, 0.1, "suffix:m") var attack_range: float = 2.5
@export_range(1.0, 2.0, 0.1, "suffix:s") var windup_seconds: float = 1.6
@export_range(0.1, 3.0, 0.1, "suffix:s") var recovery_seconds: float = 0.5
@export_range(0.1, 20.0, 0.1, "suffix:s") var cooldown_seconds: float = 4.0
## While chasing a detected Foxy, randomly charge even outside the close attack range.
@export_range(0.1, 60.0, 0.1, "suffix:s") var chase_spore_min_seconds: float = 6.0
@export_range(0.1, 60.0, 0.1, "suffix:s") var chase_spore_max_seconds: float = 12.0
@export_range(0.4, 10.0, 0.1, "suffix:m") var cloud_radius: float = 2.6
@export_range(0.2, 20.0, 0.1, "suffix:s") var cloud_duration_seconds: float = 3.5
@export_range(0.1, 3.0, 0.1, "suffix:s") var spore_ramp_seconds: float = 0.8
@export_range(0.1, 5.0, 0.1, "suffix:s") var poison_interval_seconds: float = 1.0
@export_range(0.1, 100.0, 0.1) var poison_damage: float = 0.5

var home_position: Vector3
var attack_cooldown_remaining: float = 0.0
var _hop_time: float = 0.0
var _charge_base_modulate: Color = Color.WHITE
var _charge_feedback_active: bool = false
var _evade_pending: bool = false
var _evade_away: Vector3 = Vector3.ZERO
var _evade_direction: Vector3 = Vector3.ZERO
var _evade_remaining: float = 0.0
var _evade_speed: float = 0.0
var _evade_cooldown_remaining: float = 0.0


func _ready() -> void:
	home_position = global_position
	var detector_shape := $TargetDetector/CollisionShape3D as CollisionShape3D
	detector_shape.shape = detector_shape.shape.duplicate()
	(detector_shape.shape as CylinderShape3D).radius = detection_radius
	super()


func _physics_process(delta: float) -> void:
	var hitstop := get_node_or_null("/root/HitstopController")
	if (
		hitstop != null
		and hitstop.has_method("is_frozen")
		and bool(hitstop.call("is_frozen", self))
	):
		return
	_evade_cooldown_remaining = maxf(0.0, _evade_cooldown_remaining - maxf(delta, 0.0))
	if _evade_pending and not dead:
		_start_defensive_hop()
	attack_cooldown_remaining = maxf(0.0, attack_cooldown_remaining - maxf(delta, 0.0))
	super(delta)
	if dead:
		_evade_remaining = 0.0
		return
	if _evade_remaining > 0.0:
		_update_defensive_hop(delta)
		return
	if not dead and is_instance_valid(visual):
		if Vector2(velocity.x, velocity.z).length() > 0.2:
			_hop_time += delta * HOP_FREQUENCY * TAU
			visual.position.y = absf(sin(_hop_time)) * HOP_HEIGHT
		else:
			visual.position.y = 0.0


func receive_damage(damage: DamageContext) -> float:
	var applied := super(damage)
	if (
		applied > 0.0
		and not dead
		and hp.is_alive()
		and damage.source_team == CombatTeams.PLAYER
		and _evade_cooldown_remaining <= 0.0
	):
		_evade_away = pending_hit_direction
		_evade_pending = true
		_evade_cooldown_remaining = evade_cooldown_seconds
	return applied


func is_evading() -> bool:
	return _evade_remaining > 0.0


func move_in_direction(direction: Vector3, delta: float, speed_scale: float = 1.0) -> void:
	if not direction.is_zero_approx():
		var hop_factor := lerpf(HOP_MIN_SPEED_FACTOR, 1.0, absf(sin(_hop_time)))
		speed_scale *= hop_factor
	super(direction, delta, speed_scale)


func play_directional_animation(action: StringName, restart: bool = false) -> bool:
	if is_instance_valid(visual) and is_instance_valid(visual.sprite):
		visual.sprite.texture = CHARGE_TEXTURE if action == &"spore_windup" else NORMAL_TEXTURE
	return super(action, restart)


func begin_charge_animation() -> void:
	_charge_base_modulate = visual.sprite.modulate
	_charge_feedback_active = true
	visual.animation_player.speed_scale = CHARGE_ANIMATION_SECONDS / windup_seconds
	play_directional_animation(&"spore_windup", true)


func release_cloud() -> void:
	var cloud := SPORE_CLOUD.new()
	cloud.setup(
		self,
		cloud_radius,
		cloud_duration_seconds,
		spore_ramp_seconds,
		poison_interval_seconds,
		poison_damage
	)
	get_parent().add_child(cloud)
	cloud.global_position = global_position
	cloud.activate_poison()
	attack_cooldown_remaining = cooldown_seconds


func update_charge_feedback(progress: float) -> void:
	var pulse := 0.5 + 0.5 * sin(progress * TAU * CHARGE_PULSE_COUNT)
	visual.sprite.modulate = _charge_base_modulate.lerp(CHARGE_TINT, progress * pulse)


func cancel_spore_charge() -> void:
	if _charge_feedback_active and is_instance_valid(visual) and is_instance_valid(visual.sprite):
		visual.sprite.modulate = _charge_base_modulate
	_charge_feedback_active = false


func _start_defensive_hop() -> void:
	_evade_pending = false
	var away := Vector3(_evade_away.x, 0.0, _evade_away.z).normalized()
	if has_target():
		var from_target := global_position - target.global_position
		from_target.y = 0.0
		if not from_target.is_zero_approx():
			away = from_target.normalized()
	if away.is_zero_approx():
		away = -last_facing_direction
	for distance_factor: float in EVADE_DISTANCE_FACTORS:
		var distance := evade_distance * distance_factor
		for angle: float in EVADE_DIRECTION_ANGLES:
			var direction := away.rotated(Vector3.UP, angle)
			if _is_hop_safe(direction, distance):
				_evade_direction = direction
				_evade_speed = distance / evade_duration_seconds
				_evade_remaining = evade_duration_seconds
				return


func _is_hop_safe(direction: Vector3, distance: float) -> bool:
	if test_move(global_transform, direction * distance):
		return false
	var space := get_world_3d().direct_space_state
	for fraction: float in [0.5, 1.0]:
		var point := global_position + direction * distance * fraction
		var query := PhysicsRayQueryParameters3D.create(
			point + Vector3.UP * EVADE_CHECK_UP,
			point + Vector3.DOWN * EVADE_CHECK_DOWN,
			CombatLayers.WORLD
		)
		query.exclude = [get_rid()]
		if space.intersect_ray(query).is_empty():
			return false
	return true


func _update_defensive_hop(delta: float) -> void:
	var step := minf(maxf(delta, 0.0), _evade_remaining)
	var collision := move_and_collide(_evade_direction * _evade_speed * step)
	_evade_remaining = maxf(0.0, _evade_remaining - step)
	if collision != null:
		_evade_remaining = 0.0
	var progress := 1.0 - _evade_remaining / evade_duration_seconds
	visual.position.y = sin(progress * PI) * evade_hop_height
