class_name HarpoonThrust
extends WeaponAttack
## Narrow, wall-occluded thrust shared by normal attacks and the piercing dash.

const SPRITE_FEEDBACK: Script = preload("res://gameplay/weapons/dagger_sprite_feedback.gd")
const HIT_VFX: PackedScene = preload("res://gameplay/weapons/bow_impact_vfx.tscn")
const PIERCE_HIT_VFX: PackedScene = preload("res://gameplay/weapons/harpoon_pierce_impact.tscn")
const SWING_SOUND: AudioStream = preload("res://assets/audio/combat/dagger_throw.wav")
const HIT_SOUND: AudioStream = preload("res://assets/audio/combat/dagger_hit.wav")
const SKILL_HIT_SOUND: AudioStream = preload("res://assets/audio/combat/bow_impact.wav")

@export var hitbox: HitBox
@export var dash_attack: bool = false
@export_range(0.1, 2.0, 0.01) var thrust_width: float = 0.42
@export_range(0.1, 3.0, 0.1) var thrust_height: float = 1.3
@export_range(0.1, 3.0, 0.1) var dash_tip_reach: float = 1.2

var _elapsed: float = 0.0
var _impact_played: bool = false

@onready var _vfx: Node3D = $ThrustVFX


func validate() -> bool:
	return is_instance_valid(hitbox) and get_node_or_null("ThrustVFX") != null


func _ready() -> void:
	hitbox.damage_prepared.connect(_on_damage_prepared)
	hitbox.damage_applied.connect(_on_damage_applied)


func begin_windup() -> void:
	if context == null or not is_instance_valid(context.actor):
		return
	_sync_transform()
	_vfx.call("prepare", context.range_units, thrust_width * context.hitbox_multiplier, dash_attack)


func tick_windup(_delta: float) -> void:
	_sync_transform()


func activate() -> void:
	if context == null or not is_instance_valid(context.actor):
		return
	super.activate()
	_elapsed = 0.0
	_impact_played = false
	_sync_transform()
	var reach: float = dash_tip_reach if dash_attack else context.range_units
	var shape := BoxShape3D.new()
	shape.size = Vector3(thrust_width, thrust_height, reach)
	var collider := hitbox.get_node("CollisionShape3D") as CollisionShape3D
	collider.shape = shape
	collider.position = Vector3(0.0, thrust_height * 0.5, -reach * 0.5 - 0.12)
	hitbox.scale = Vector3.ONE * context.hitbox_multiplier
	hitbox.begin_attack_with_context(
		context.create_damage_context(), HitBox.RehitPolicy.ONCE_PER_ATTACK
	)
	_vfx.call("strike", reach * context.hitbox_multiplier)
	hitbox.sample_shape()
	if not dash_attack:
		get_node("/root/AudioManager").play_sfx_3d(SWING_SOUND, global_position, -17.0, 1.5)


func tick_active(delta: float) -> void:
	if not active:
		return
	_elapsed += maxf(0.0, delta)
	_sync_transform()
	hitbox.sample_shape()
	_vfx.call("set_progress", clampf(_elapsed / context.active_seconds, 0.0, 1.0))


func deactivate() -> void:
	super.deactivate()
	if is_instance_valid(hitbox):
		hitbox.end_attack()
	if is_instance_valid(_vfx):
		_vfx.call("finish")


func _sync_transform() -> void:
	if context != null and is_instance_valid(context.actor):
		global_position = context.actor.global_position
		look_at(global_position + context.direction, Vector3.UP)


func _on_damage_prepared(damage: DamageContext, target: Node) -> void:
	context.damage_prepared.emit(damage, target)
	if not target is Node3D:
		return
	var origin: Vector3 = context.actor.global_position + Vector3.UP * 0.75
	var destination: Vector3 = (target as Node3D).global_position + Vector3.UP * 0.75
	var query := PhysicsRayQueryParameters3D.create(origin, destination, CombatLayers.WORLD)
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		damage.amount_hp = 0.0


func _on_damage_applied(damage: DamageContext, target: Node, applied_hp: float) -> void:
	context.damage_applied.emit(damage, target, applied_hp)
	if applied_hp <= 0.0:
		return
	var at: Vector3 = global_position + context.direction + Vector3.UP * 0.8
	var power: float = damage.get_impact_scale()
	if target is EnemyBase and is_instance_valid(target.visual.sprite):
		var sprite: Sprite3D = target.visual.sprite
		at = sprite.global_transform * sprite.get_aabb().get_center()
		var feedback := sprite.get_node_or_null("DaggerFeedback")
		if feedback == null:
			feedback = SPRITE_FEEDBACK.new()
			feedback.name = "DaggerFeedback"
			sprite.add_child(feedback)
		feedback.kick(context.direction, (0.18 if dash_attack else 0.045) * power, true, power)
	if dash_attack:
		var pierce_impact := PIERCE_HIT_VFX.instantiate() as Node3D
		get_parent().add_child(pierce_impact)
		var camera := get_viewport().get_camera_3d()
		var view_offset := Vector3.ZERO
		if is_instance_valid(camera):
			view_offset = (camera.global_position - at).normalized() * 0.1
		pierce_impact.global_position = at + view_offset
		pierce_impact.call("burst", context.direction, power)
	else:
		var impact := HIT_VFX.instantiate() as Node3D
		impact.set("effect_color", Color(1.0, 0.68, 0.1, 0.9))
		impact.set("core_color", Color(1.0, 0.98, 0.7, 1.0))
		impact.set("ring_count", 1)
		impact.set("spark_count", 6)
		impact.set("spark_streak_length", 2.0)
		get_parent().add_child(impact)
		impact.global_position = at
		impact.scale = Vector3.ONE * 0.32 * power
		impact.call("set_aim", context.direction)
		impact.call("burst", 0.35)
	if dash_attack or not _impact_played:
		if dash_attack and not _impact_played:
			get_node("/root/HitstopController").request(0.045 * power)
		_impact_played = true
		get_node("/root/HitstopController").request_local(
			null if dash_attack else context.actor, target as Node3D,
			(0.1 if dash_attack else 0.035) * power
		)
		get_node("/root/ScreenShakeController").request((6.0 if dash_attack else 1.8) * power, 0.14)
		get_node("/root/AudioManager").play_sfx_3d(
			SKILL_HIT_SOUND if dash_attack else HIT_SOUND,
			at, -6.0 if dash_attack else -16.0, 0.85 if dash_attack else 1.3
		)
		if dash_attack:
			get_node("/root/AudioManager").play_sfx_3d(HIT_SOUND, at, -13.0, 1.15)


func _exit_tree() -> void:
	if is_instance_valid(hitbox):
		hitbox.end_attack()
