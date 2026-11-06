extends Node3D
## Animation and a single area damage sample for one meteor.

@export var animation_name: StringName = &"meteor"
@export_range(0, 200, 1) var impact_frame: int = 19
@export_range(0.0, 0.12, 0.005, "suffix:s") var hitstop_seconds: float = 0.06
@export_range(0.0, 8.0, 0.5) var shake_pixels: float = 6.0
@export_range(0.0, 0.3, 0.01, "suffix:s") var shake_seconds: float = 0.2
@export var impact_sound: AudioStream
@export_range(-80.0, 6.0, 1.0, "suffix:dB") var impact_volume_db: float = -8.0

var _context: AttackContext
var _impacted := false

@onready var _sprite: AnimatedSprite3D = $MeteorEffect/AnimatedSprite3D
@onready var _hitbox: HitBox = $HitBox


func _ready() -> void:
	set_physics_process(false)
	_sprite.animation_finished.connect(queue_free)
	_hitbox.damage_prepared.connect(_on_damage_prepared)
	_hitbox.damage_applied.connect(_on_damage_applied)


func launch(context: AttackContext) -> void:
	_context = context
	_hitbox.scale *= context.hitbox_multiplier
	_sprite.play(animation_name)
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	if _impacted or _sprite.frame < impact_frame:
		return
	_impacted = true
	set_physics_process(false)
	if not is_instance_valid(_context.actor):
		return
	if _hitbox.begin_attack_with_context(_context.create_damage_context()):
		_hitbox.sample_shape()
		_hitbox.end_attack()
	get_node("/root/HitstopController").request(hitstop_seconds)
	get_node("/root/ScreenShakeController").request(shake_pixels, shake_seconds)
	if impact_sound != null:
		get_node("/root/AudioManager").play_sfx_3d(impact_sound, global_position, impact_volume_db)


func _on_damage_prepared(damage: DamageContext, target: Node) -> void:
	_context.damage_prepared.emit(damage, target)


func _on_damage_applied(damage: DamageContext, target: Node, applied_hp: float) -> void:
	_context.damage_applied.emit(damage, target, applied_hp)
