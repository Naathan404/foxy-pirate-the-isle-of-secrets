class_name DestructibleProp
extends Node3D

signal damaged(applied_hp: float)
signal destroyed

const HIT_FLASH_SHADER: Shader = preload("res://world/objects/destructible_hit_flash.gdshader")
const DEFAULT_FRAGMENTS_SCENE: PackedScene = preload(
	"res://world/objects/destructible_fragments.tscn"
)
const FragmentSettings = preload("res://world/objects/destructible_fragment_settings.gd")

@export_group("Durability")
@export_range(0.01, 100000.0, 0.01) var max_hp: float = 1.0

@export_group("Hit Feedback")
@export var visual_root: Node3D
@export_range(1.0, 2.0, 0.01) var hit_scale: float = 1.12
@export_range(0.01, 1.0, 0.01) var hit_recover_duration: float = 0.16
@export var hit_flash_color: Color = Color(1.0, 0.97, 0.9, 1.0)
@export_range(0.0, 1.0, 0.01) var hit_flash_hold_duration: float = 0.05
@export_range(0.01, 1.0, 0.01) var hit_flash_duration: float = 0.16
@export var smoke_scene: PackedScene = preload("res://world/objects/destructible_smoke.tscn")
@export var smoke_offset: Vector3 = Vector3(0.0, 0.8, 0.0)
@export_range(1, 128, 1) var hit_smoke_amount: int = 5
@export_range(1, 256, 1) var destroy_smoke_amount: int = 14

@export_group("Break Fragments")
@export var fragment_source: Sprite3D
@export var fragments_scene: PackedScene = DEFAULT_FRAGMENTS_SCENE
@export_range(1, 32, 1) var fragment_count: int = 9
@export_range(0.01, 0.5, 0.01) var fragment_min_size: float = 0.09
@export_range(0.01, 0.5, 0.01) var fragment_max_size: float = 0.24
@export_range(0.0, 1.0, 0.01) var fragment_alpha_threshold: float = 0.15
@export_range(0.0, 20.0, 0.1) var fragment_min_horizontal_speed: float = 5.0
@export_range(0.0, 20.0, 0.1) var fragment_max_horizontal_speed: float = 8.0
@export_range(0.0, 20.0, 0.1) var fragment_min_launch_speed: float = 7.5
@export_range(0.0, 20.0, 0.1) var fragment_max_launch_speed: float = 10.5
@export_range(0.0, 30.0, 0.1) var fragment_gravity: float = 20.0
@export_range(0.0, 20.0, 0.1) var fragment_max_spin: float = 11.0
@export_range(0.1, 5.0, 0.05) var fragment_lifetime: float = 1.1
@export_range(0.0, 1.0, 0.01) var fragment_fade_start: float = 0.7

@export_group("Loot")
@export var drop_item: BaseItem
@export_range(0.0, 1.0, 0.01) var drop_chance: float = 0.5
@export_range(1, 99, 1) var drop_quantity: int = 1
@export var pickup_scene: PackedScene = preload("res://gameplay/inventory/item_pickup.tscn")

var _destroyed: bool = false
var _visual_scale: Vector3
var _previous_overlay: Material
var _flash_material: ShaderMaterial
var _hit_tween: Tween
var _flash_tween: Tween

@onready var _health: HealthComponent = $HealthComponent
@onready var _hurtbox: HurtBox = $HurtBox


func _ready() -> void:
	_health.init(max_hp)
	_hurtbox.actor = self
	_hurtbox.team = CombatTeams.ENEMY
	_hurtbox.collision_layer = CombatLayers.ENEMY_HURTBOX
	_hurtbox.collision_mask = CombatLayers.PLAYER_ATTACK
	if is_instance_valid(visual_root):
		_visual_scale = visual_root.scale


func receive_damage(damage: DamageContext) -> float:
	if _destroyed or damage == null or damage.source_team != CombatTeams.PLAYER:
		return 0.0
	var applied_hp := _health.take_damage(damage.amount_hp)
	if applied_hp <= 0.0:
		return 0.0
	damaged.emit(applied_hp)
	if _health.is_alive():
		_play_hit_feedback()
		_spawn_smoke(hit_smoke_amount)
	else:
		_destroyed = true
		_hurtbox.enabled = false
		_hurtbox.set_deferred("monitorable", false)
		_spawn_smoke(destroy_smoke_amount)
		_spawn_fragments()
		_drop_loot()
		_play_hit_feedback()
		destroyed.emit()
		if _flash_tween != null and _flash_tween.is_valid():
			_flash_tween.finished.connect(queue_free, CONNECT_ONE_SHOT)
		else:
			queue_free()
	return applied_hp


func _play_hit_feedback() -> void:
	if not is_instance_valid(visual_root):
		return
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	visual_root.scale = _visual_scale * hit_scale
	_hit_tween = create_tween()
	_hit_tween.tween_property(visual_root, "scale", _visual_scale, hit_recover_duration)
	var sprite := visual_root as Sprite3D
	if sprite == null:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	if _flash_material == null:
		_previous_overlay = sprite.material_overlay
		_flash_material = ShaderMaterial.new()
		_flash_material.shader = HIT_FLASH_SHADER
	_flash_material.set_shader_parameter("sprite_texture", sprite.texture)
	_flash_material.set_shader_parameter("flash_color", hit_flash_color)
	_flash_material.set_shader_parameter("strength", 1.0)
	sprite.material_overlay = _flash_material
	_flash_tween = create_tween().set_ignore_time_scale(true)
	_flash_tween.tween_interval(hit_flash_hold_duration)
	_flash_tween.tween_property(
		_flash_material, "shader_parameter/strength", 0.0, hit_flash_duration
	)
	_flash_tween.tween_callback(_restore_flash_overlay)


func _restore_flash_overlay() -> void:
	if visual_root is Sprite3D:
		var sprite := visual_root as Sprite3D
		if sprite.material_overlay == _flash_material:
			sprite.material_overlay = _previous_overlay


func _spawn_smoke(amount: int) -> void:
	if smoke_scene == null or get_parent() == null:
		return
	var smoke := smoke_scene.instantiate() as GPUParticles3D
	if smoke == null:
		push_warning("DestructibleProp: smoke_scene must have a GPUParticles3D root")
		return
	smoke.amount = amount
	get_parent().add_child(smoke)
	smoke.global_position = to_global(smoke_offset)
	smoke.restart()
	smoke.emitting = true


func _spawn_fragments() -> void:
	if not is_instance_valid(fragment_source) or fragments_scene == null or get_parent() == null:
		return
	var fragments := fragments_scene.instantiate() as DestructibleFragments
	if fragments == null:
		push_warning("DestructibleProp: fragments_scene must have a DestructibleFragments root")
		return
	get_parent().add_child(fragments)
	fragments.global_position = fragment_source.global_position
	var settings := FragmentSettings.new()
	settings.count = fragment_count
	settings.min_size = fragment_min_size
	settings.max_size = fragment_max_size
	settings.alpha_threshold = fragment_alpha_threshold
	settings.min_horizontal_speed = fragment_min_horizontal_speed
	settings.max_horizontal_speed = fragment_max_horizontal_speed
	settings.min_launch_speed = fragment_min_launch_speed
	settings.max_launch_speed = fragment_max_launch_speed
	settings.gravity = fragment_gravity
	settings.max_spin = fragment_max_spin
	settings.lifetime = fragment_lifetime
	settings.fade_start = fragment_lifetime * fragment_fade_start
	fragments.burst_from_sprite(fragment_source, settings)


func _drop_loot() -> void:
	if drop_item == null or pickup_scene == null or drop_chance <= 0.0:
		return
	if drop_chance < 1.0 and randf() >= drop_chance:
		return
	if get_parent() == null:
		return
	var pickup := pickup_scene.instantiate() as ItemPickup
	if pickup == null:
		push_warning("DestructibleProp: pickup_scene must have an ItemPickup root")
		return
	pickup.item = drop_item
	pickup.quantity = drop_quantity
	get_parent().add_child(pickup)
	pickup.global_position = global_position
	pickup.play_drop_animation()
