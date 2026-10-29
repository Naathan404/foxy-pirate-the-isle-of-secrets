class_name DaggerAttack
extends WeaponAttack

const SPRITE_FEEDBACK: Script = preload("res://gameplay/weapons/dagger_sprite_feedback.gd")
const SWING_SOUND: AudioStream = preload("res://assets/audio/combat/dagger_throw.wav")
const HIT_SOUND: AudioStream = preload("res://assets/audio/combat/dagger_hit.wav")

@export var hitbox: HitBox
@export var forward_offset: float = 0.8

var _elapsed: float = 0.0
var _vfx: MeleeSlashVFX
var _impact_played: bool = false


# validate trước khi node vào scenetree
func validate() -> bool:
	return is_instance_valid(hitbox)


func _ready() -> void:
	if not hitbox.damage_prepared.is_connected(_on_damage_prepared):
		hitbox.damage_prepared.connect(_on_damage_prepared)
	if not hitbox.damage_applied.is_connected(_on_damage_applied):
		hitbox.damage_applied.connect(_on_damage_applied)


func activate() -> void:
	if context == null or not is_instance_valid(hitbox) or not is_instance_valid(context.actor):
		return

	super.activate()
	global_position = context.actor.global_position

	# forward là trục -Z
	look_at(global_position + context.direction, Vector3.UP)

	hitbox.position.z = -forward_offset
	hitbox.scale = Vector3.ONE * context.hitbox_multiplier
	_elapsed = 0.0
	_impact_played = false
	if context.combo_step != null:
		_configure_swing()

	hitbox.begin_attack_with_context(context.create_damage_context())
	if context.combo_step != null:
		_sample_swing(0.0)
		get_node("/root/AudioManager").play_sfx_3d(
			SWING_SOUND, global_position, -15.0, context.combo_step.audio_pitch
		)


func tick_active(delta: float) -> void:
	if context != null and is_instance_valid(context.actor):
		global_position = context.actor.global_position
		if context.combo_step != null and active:
			var previous := _elapsed / context.active_seconds
			_elapsed = minf(_elapsed + delta, context.active_seconds)
			var progress := _elapsed / context.active_seconds
			# Subsample the swept angle, including the final active frame.
			var degrees := (
				absf(context.combo_step.swing_end_degrees - context.combo_step.swing_start_degrees)
				* (progress - previous)
			)
			var samples := maxi(1, ceili(degrees / 8.0))
			for index in samples:
				_sample_swing(lerpf(previous, progress, float(index + 1) / samples))
				if not active:
					break
			if is_instance_valid(_vfx):
				_vfx.global_transform = global_transform
				_vfx.set_progress(progress)


func deactivate() -> void:
	super.deactivate()
	if is_instance_valid(hitbox):
		hitbox.end_attack()
	if is_instance_valid(_vfx):
		_vfx.finish()


func _configure_swing() -> void:
	var reach := context.range_units * context.combo_step.reach_multiplier
	var collider := hitbox.get_node("CollisionShape3D") as CollisionShape3D
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.42, 1.4, reach)
	collider.shape = shape
	collider.position = Vector3(0.0, 0.7, -reach * 0.5)
	hitbox.position = Vector3.ZERO
	_vfx = MeleeSlashVFX.new()
	get_parent().add_child(_vfx)
	_vfx.global_transform = global_transform
	_vfx.setup(context.combo_step, reach * context.hitbox_multiplier)


func _sample_swing(progress: float) -> void:
	hitbox.rotation.y = -deg_to_rad(
		lerpf(
			context.combo_step.swing_start_degrees, context.combo_step.swing_end_degrees, progress
		)
	)
	hitbox.sample_shape()


func _on_damage_prepared(damage: DamageContext, target: Node) -> void:
	if context != null:
		context.damage_prepared.emit(damage, target)


func _on_damage_applied(damage: DamageContext, target: Node, applied_hp: int) -> void:
	if context != null:
		context.damage_applied.emit(damage, target, applied_hp)
	if context == null or context.combo_step == null or applied_hp <= 0:
		return
	var step := context.combo_step
	var heavy := step.heavy_impact
	var at := global_position + context.direction + Vector3.UP
	if target is EnemyBase and is_instance_valid(target.visual.sprite):
		var sprite: Sprite3D = target.visual.sprite
		at = sprite.global_transform * sprite.get_aabb().get_center()
		var feedback := sprite.get_node_or_null("DaggerFeedback")
		if feedback == null:
			feedback = SPRITE_FEEDBACK.new()
			feedback.name = "DaggerFeedback"
			sprite.add_child(feedback)
		feedback.kick(context.direction, 0.08 if heavy else 0.035, true)
	if is_instance_valid(_vfx):
		_vfx.impact(at, context.direction, heavy)
	if not _impact_played:
		_impact_played = true
		get_node("/root/HitstopController").request_local(
			context.actor, target as Node3D, step.hitstop_seconds
		)
		get_node("/root/ScreenShakeController").request(step.shake_pixels, 0.16 if heavy else 0.1)
		get_node("/root/AudioManager").play_sfx_3d(
			HIT_SOUND, at, -8.0 if heavy else -13.0, step.audio_pitch
		)
