class_name DestructibleProp
extends Node3D

signal damaged(applied_hp: float)
signal destroyed

const HIT_FLASH_SHADER: Shader = preload("res://world/objects/destructible_hit_flash.gdshader")
const WIND_SHADER: Shader = preload("res://world/objects/destructible_wind.gdshader")
const WIND_UPRIGHT_SHADER: Shader = preload(
	"res://world/objects/destructible_wind_upright.gdshader"
)
const GROUND_SHADOW_SHADER: Shader = preload(
	"res://world/objects/destructible_ground_shadow.gdshader"
)
const DEFAULT_FRAGMENTS_SCENE: PackedScene = preload(
	"res://world/objects/destructible_fragments.tscn"
)
const FragmentSettings = preload("res://world/objects/destructible_fragment_settings.gd")

@export_group("Durability")
@export_range(0.01, 100000.0, 0.01) var max_hp: float = 1.0
# //NLVP sửa: Chỉ bật cho vật thể cần nhận thêm đòn quái.
## Cho phép đòn quái gây sát thương lên vật thể.
@export var receives_enemy_attacks: bool = false

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
## Multiplies the hitstop of hits on this prop. Breaking scenery should not freeze the swing as
## hard as hitting an enemy; HitstopController reads this from the hit target.
@export_range(0.0, 1.0, 0.05) var hitstop_scale: float = 0.3

@export_group("Wind Sway")
@export var swingable: bool = false
## Depth-test the camera-facing sprite as if it stood upright like a character, so a character
## standing beside a tall prop is never cut through by the tilted quad. Use on trees and tall
## plants; needs `swingable`. Costs early depth testing, so leave it off on small props.
@export var upright_depth: bool = false
@export_range(0.0, 0.5, 0.005) var wind_amplitude: float = 0.28
@export_range(0.1, 6.0, 0.05) var wind_speed: float = 4.4
@export_range(0.0, 1.0, 0.01) var wind_gust_strength: float = 0.38
@export_range(0.0, 0.9, 0.01) var wind_root_height: float = 0.08
@export_range(0.5, 4.0, 0.05) var wind_bend_power: float = 1.35
@export_range(0.0, 6.28, 0.01) var wind_phase_offset: float = 0.0

@export_group("Ground Shadow")
## Lay the sprite's outline on the ground as its shadow, starting at its base, instead of casting
## a shadow-map shadow. Shadow maps cast billboards from the light's side, so their shadow leaves
## the sprite at a wrong angle. Needs `visual_root` to be a Sprite3D whose base is the prop origin.
@export var ground_shadow: bool = false
## Ground shift (x, z) per metre of sprite height: the shadow's direction and length. Keep it
## leaning the same way as the room's sun shadows. Negative z leans it up the screen.
@export var ground_shadow_offset_per_meter := Vector2(0.8, -0.6)
@export var ground_shadow_color := Color(0.04, 0.05, 0.08, 0.6)

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
var _wind_material: ShaderMaterial
var _hit_tween: Tween
var _flash_tween: Tween

@onready var _health: HealthComponent = $HealthComponent
@onready var _hurtbox: HurtBox = $HurtBox
@onready var _movement_shape: CollisionShape3D = get_node_or_null("MovementBody/CollisionShape3D")


func _ready() -> void:
	_health.init(max_hp)
	_hurtbox.actor = self
	_hurtbox.team = CombatTeams.ENEMY
	_hurtbox.collision_layer = CombatLayers.ENEMY_HURTBOX
	_hurtbox.collision_mask = CombatLayers.PLAYER_ATTACK
	# //NLVP sửa: Hai phe cùng đánh được vật thể trung lập đã bật tùy chọn.
	if receives_enemy_attacks:
		_hurtbox.team = CombatTeams.NONE
		_hurtbox.collision_layer |= CombatLayers.PLAYER_HURTBOX
		_hurtbox.collision_mask |= CombatLayers.ENEMY_ATTACK
	if is_instance_valid(visual_root):
		_visual_scale = visual_root.scale
	if swingable:
		_configure_wind()
	if ground_shadow:
		_configure_ground_shadow()


func _configure_wind() -> void:
	var sprite := visual_root as Sprite3D
	if sprite == null or sprite.texture == null:
		push_warning("DestructibleProp: swingable requires a Sprite3D with a texture")
		return
	_wind_material = ShaderMaterial.new()
	_wind_material.shader = WIND_UPRIGHT_SHADER if upright_depth else WIND_SHADER
	var columns := maxi(sprite.hframes, 1)
	var rows := maxi(sprite.vframes, 1)
	var frame_width := 1.0 / float(columns)
	var frame_height := 1.0 / float(rows)
	var frame_x := sprite.frame % columns
	var frame_y := sprite.frame / columns
	_wind_material.set_shader_parameter("sprite_texture", sprite.texture)
	_wind_material.set_shader_parameter(
		"frame_uv", Vector4(frame_x * frame_width, frame_y * frame_height, frame_width, frame_height)
	)
	_wind_material.set_shader_parameter(
		"sprite_width", sprite.texture.get_width() * frame_width * sprite.pixel_size
	)
	_wind_material.set_shader_parameter("wind_amplitude", wind_amplitude)
	_wind_material.set_shader_parameter("wind_speed", wind_speed)
	_wind_material.set_shader_parameter("gust_strength", wind_gust_strength)
	_wind_material.set_shader_parameter("root_height", wind_root_height)
	_wind_material.set_shader_parameter("bend_power", wind_bend_power)
	_wind_material.set_shader_parameter(
		"wind_phase", wind_phase_offset + fposmod(float(get_instance_id()), TAU)
	)
	_wind_material.set_shader_parameter(
		"horizontal_uv_direction", -1.0 if sprite.flip_h else 1.0
	)
	_wind_material.set_shader_parameter(
		"vertical_uv_direction", -1.0 if sprite.flip_v else 1.0
	)
	_wind_material.set_shader_parameter("flash_color", hit_flash_color)
	sprite.material_override = _wind_material


func _configure_ground_shadow() -> void:
	var sprite := visual_root as Sprite3D
	if sprite == null or sprite.texture == null:
		push_warning("DestructibleProp: ground_shadow requires a Sprite3D with a texture")
		return
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Sprite image in this prop's space (without the prop's own scale, which the child inherits).
	# Sprite3D.get_aabb() is a billboard-safe cube, so rebuild the image rectangle the way
	# Sprite3D lays it out: offset in pixels, y up, centred on the origin when `centered`.
	var sprite_space := global_transform.affine_inverse() * sprite.global_transform
	var scale_in_prop := sprite_space.basis.get_scale()
	var columns := maxi(sprite.hframes, 1)
	var rows := maxi(sprite.vframes, 1)
	var frame_size := Vector2(1.0 / float(columns), 1.0 / float(rows))
	var frame_origin := Vector2(sprite.frame % columns, sprite.frame / columns) * frame_size
	var frame_pixels := Vector2(sprite.texture.get_size()) * frame_size
	var corner_pixels := sprite.offset - (frame_pixels * 0.5 if sprite.centered else Vector2.ZERO)
	var left := sprite_space.origin.x + corner_pixels.x * sprite.pixel_size * scale_in_prop.x
	var bottom := sprite_space.origin.y + corner_pixels.y * sprite.pixel_size * scale_in_prop.y
	var width := frame_pixels.x * sprite.pixel_size * scale_in_prop.x
	var height := frame_pixels.y * sprite.pixel_size * scale_in_prop.y

	var material := ShaderMaterial.new()
	material.shader = GROUND_SHADOW_SHADER
	material.set_shader_parameter("sprite_texture", sprite.texture)
	material.set_shader_parameter(
		"frame_uv", Vector4(frame_origin.x, frame_origin.y, frame_size.x, frame_size.y)
	)
	material.set_shader_parameter("sprite_rect", Vector4(left, bottom, width, height))
	material.set_shader_parameter("sprite_depth_meters", sprite_space.origin.z)
	material.set_shader_parameter("shadow_offset_per_meter", ground_shadow_offset_per_meter)
	material.set_shader_parameter("shadow_color", ground_shadow_color)
	material.set_shader_parameter("flip_h", sprite.flip_h)
	material.set_shader_parameter("flip_v", sprite.flip_v)

	var shadow := MeshInstance3D.new()
	shadow.name = "GroundShadow"
	shadow.mesh = QuadMesh.new()
	shadow.material_override = material
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The shader moves the vertices, so give culling the shadow's real bounds.
	var tip_shift := ground_shadow_offset_per_meter * (bottom + height)
	var base_shift := ground_shadow_offset_per_meter * bottom
	var bounds := AABB(Vector3(left, -0.1, sprite_space.origin.z), Vector3(width, 0.2, 0.0))
	for shift: Vector2 in [tip_shift, base_shift]:
		bounds = bounds.merge(
			AABB(
				Vector3(left + shift.x, -0.1, sprite_space.origin.z + shift.y),
				Vector3(width, 0.2, 0.0)
			)
		)
	shadow.custom_aabb = bounds.grow(0.1)
	add_child(shadow)


func receive_damage(damage: DamageContext) -> float:
	if _destroyed or damage == null:
		return 0.0
	# //NLVP sửa: Gỗ, đá vẫn chỉ nhận đòn người chơi theo mặc định.
	var accepted_team := (
		damage.source_team == CombatTeams.PLAYER
		or (receives_enemy_attacks and damage.source_team == CombatTeams.ENEMY)
	)
	if not accepted_team:
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
		if is_instance_valid(_movement_shape):
			_movement_shape.set_deferred("disabled", true)
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
	if _wind_material != null:
		_wind_material.set_shader_parameter("flash_color", hit_flash_color)
		_wind_material.set_shader_parameter("flash_strength", 1.0)
		_flash_tween = create_tween().set_ignore_time_scale(true)
		_flash_tween.tween_interval(hit_flash_hold_duration)
		_flash_tween.tween_property(
			_wind_material, "shader_parameter/flash_strength", 0.0, hit_flash_duration
		)
		return
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
