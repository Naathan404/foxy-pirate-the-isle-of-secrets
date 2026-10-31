extends WeaponAttack
## One snapshotted arrow; swept collision prevents tunnelling through thin targets/walls.

const SPRITE_FEEDBACK: Script = preload("res://gameplay/weapons/dagger_sprite_feedback.gd")

@export var hitbox: HitBox
@export_range(1.0, 60.0, 0.1) var speed: float = 18.0
@export_range(0.0, 3.0, 0.05) var release_height: float = 0.9
@export_range(0.1, 10.0, 0.1) var lifetime: float = 4.0

@export_group("Hit Feedback")
@export var impact_scene: PackedScene = preload("res://gameplay/weapons/bow_impact_vfx.tscn")
@export_range(0.0, 0.1, 0.001) var hitstop_seconds: float = 0.035
@export_range(0.0, 8.0, 0.1) var hit_shake_pixels: float = 1.5
@export_range(0.0, 0.2, 0.005) var hit_kick_distance: float = 0.04
@export_range(0.1, 1.0, 0.05) var impact_scale: float = 0.4
@export var impact_charge_scale_bonus: float = 0.5
@export_range(0.0, 1.0, 0.01) var impact_base_strength: float = 0.2
@export_range(0.0, 1.0, 0.01) var impact_charge_strength_bonus: float = 0.4
@export var hit_charge_kick_bonus: float = 0.5
@export var hit_charge_hitstop_bonus: float = 0.5
@export var hit_charge_shake_bonus: float = 1.0
@export_range(0.0, 1.0, 0.01) var hit_shake_seconds: float = 0.12

@export_group("Hit Audio")
@export var hit_sound: AudioStream = preload("res://assets/audio/combat/bow_impact.wav")
@export_range(-80.0, 6.0, 1.0) var hit_volume_db: float = -12.0
@export var hit_charge_volume_bonus_db: float = 2.0
@export var hit_pitch_base: float = 1.15
@export var hit_charge_pitch_offset: float = -0.1

@export_group("Trail")
@export var trail_scene: PackedScene = preload("res://gameplay/weapons/bow_energy_trail.tscn")

var curve_offset: float = 0.0
var curve_height: float = 0.0
var energy_strength: float = 0.0
var _start: Vector3
var _control: Vector3
var _end: Vector3
var _trail: Node3D

var _travelled: float = 0.0
var _age: float = 0.0
var _finished: bool = false
var _previous_position: Vector3

@onready var _model: MeshInstance3D = $ArrowModel


func _ready() -> void:
	hide()
	set_physics_process(false)
	hitbox.damage_prepared.connect(_on_damage_prepared)
	hitbox.damage_applied.connect(_on_damage_applied)


func validate() -> bool:
	return (
		is_instance_valid(hitbox)
		and speed > 0.0
		and lifetime > 0.0
		and trail_scene != null
		and impact_scene != null
	)


func activate() -> void:
	if context == null or not is_instance_valid(context.actor) or context.range_units <= 0.0:
		return
	super.activate()
	show()
	global_position = context.actor.global_position + Vector3.UP * release_height
	look_at(global_position + context.direction, Vector3.UP)
	_start = global_position
	_previous_position = global_position
	_model.position = Vector3.ZERO
	_end = _start + context.direction * context.range_units
	_control = (_start + _end) * 0.5
	_control += context.direction.cross(Vector3.UP) * curve_offset + Vector3.UP * curve_height
	if energy_strength > 0.0:
		_trail = trail_scene.instantiate() as Node3D
		_trail.set("strength", energy_strength)
		get_parent().add_child(_trail)
		_trail.call("push_point", global_position)
	_travelled = 0.0
	_age = 0.0
	_finished = false
	hitbox.scale = Vector3.ONE * context.hitbox_multiplier
	hitbox.begin_attack_with_context(context.create_damage_context())
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if not launched or _finished:
		return
	if not is_instance_valid(context.actor) or bool(context.actor.get("dead")):
		_finish_projectile()
		return
	_age += maxf(0.0, delta)
	_previous_position = global_position
	var distance := minf(speed * maxf(0.0, delta), context.range_units - _travelled)
	var progress := clampf((_travelled + distance) / context.range_units, 0.0, 1.0)
	var destination := _start.bezier_interpolate(_control, _control, _end, progress)
	if curve_offset == 0.0 and curve_height == 0.0:
		destination = _start.lerp(_end, progress)
	if distance > 0.0:
		var query := PhysicsRayQueryParameters3D.create(
			global_position, destination, CombatLayers.WORLD | CombatLayers.ENEMY_HURTBOX
		)
		query.collide_with_areas = true
		if context.actor is CollisionObject3D:
			query.exclude = [(context.actor as CollisionObject3D).get_rid()]
		var collision := get_world_3d().direct_space_state.intersect_ray(query)
		if not collision.is_empty():
			global_position = collision.position
			if is_instance_valid(_trail):
				_trail.call("push_point", global_position)
			if collision.collider is HurtBox:
				hitbox.try_hit(collision.collider as HurtBox)
			_finish_projectile()
			return
	global_position = destination
	var tangent := _start.bezier_derivative(_control, _control, _end, progress)
	if not tangent.is_zero_approx():
		look_at(global_position + tangent, Vector3.UP)
	if is_instance_valid(_trail):
		_trail.call("push_point", global_position)
	_travelled += distance
	if _travelled >= context.range_units or _age >= lifetime:
		_finish_projectile()


func _process(_delta: float) -> void:
	if launched and not _finished:
		_model.global_position = _previous_position.lerp(
			global_position, Engine.get_physics_interpolation_fraction()
		)


func _on_damage_prepared(damage: DamageContext, target: Node) -> void:
	context.damage_prepared.emit(damage, target)


func _on_damage_applied(damage: DamageContext, target: Node, applied_hp: float) -> void:
	if _finished or applied_hp <= 0.0:
		return
	context.damage_applied.emit(damage, target, applied_hp)
	_play_hit_feedback(target, damage.get_impact_scale())
	_finish_projectile()


func _play_hit_feedback(target: Node, knockback_scale: float) -> void:
	var strength := clampf(energy_strength, 0.0, 1.0)
	if target is EnemyBase and is_instance_valid(target.visual.sprite):
		var sprite: Sprite3D = target.visual.sprite
		# Reuse the sprite-owned kick/flash so it survives arrow deletion and stacks safely
		# with melee hits instead of creating competing overlay materials.
		var feedback := sprite.get_node_or_null("DaggerFeedback")
		if feedback == null:
			feedback = SPRITE_FEEDBACK.new()
			feedback.name = "DaggerFeedback"
			sprite.add_child(feedback)
		feedback.kick(
			context.direction,
			hit_kick_distance * (1.0 + strength * hit_charge_kick_bonus) * knockback_scale,
			true,
			knockback_scale
		)
	var impact := impact_scene.instantiate() as Node3D
	get_parent().add_child(impact)
	impact.global_position = global_position
	impact.call("set_aim", context.direction)
	impact.scale = (
		Vector3.ONE * impact_scale * (1.0 + strength * impact_charge_scale_bonus) * knockback_scale
	)
	impact.call("burst", impact_base_strength + strength * impact_charge_strength_bonus)
	get_node("/root/AudioManager").play_sfx_3d(
		hit_sound,
		global_position,
		hit_volume_db + strength * hit_charge_volume_bonus_db + linear_to_db(knockback_scale),
		hit_pitch_base + strength * hit_charge_pitch_offset
	)
	# Ranged impacts briefly stop the target while the shooter remains responsive.
	get_node("/root/HitstopController").request_local(
		null,
		target as Node3D,
		hitstop_seconds * (1.0 + strength * hit_charge_hitstop_bonus) * knockback_scale
	)
	get_node("/root/ScreenShakeController").request(
		hit_shake_pixels * (1.0 + strength * hit_charge_shake_bonus) * knockback_scale,
		hit_shake_seconds
	)


func _finish_projectile() -> void:
	if _finished:
		return
	_finished = true
	hitbox.end_attack()
	set_physics_process(false)
	queue_free()


func _exit_tree() -> void:
	if is_instance_valid(_trail):
		_trail.call("finish")
	if is_instance_valid(hitbox):
		hitbox.end_attack()
