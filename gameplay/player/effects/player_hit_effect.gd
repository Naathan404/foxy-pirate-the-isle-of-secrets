extends Node3D
## Feedback từ damage thật; không thay đổi HP, hitstun hay quyền bất tử.

const DUST_SCENE: PackedScene = preload("res://gameplay/player/effects/run_dust_effect.tscn")
const VIGNETTE_SHADER: Shader = preload("res://gameplay/player/effects/hit_vignette.gdshader")

@export var player: Player
@export var sprite: Sprite3D
@export var visual: Node3D
@export var health: HealthComponent

@export_group("Impact Feedback")
@export_range(0.0, 0.12, 0.005) var hitstop_duration: float = 0.055
@export_range(0.0, 10.0, 0.5) var shake_pixels: float = 4.5
@export_range(0.0, 0.5, 0.01) var vignette_strength: float = 0.22
@export_range(1.0, 1.3, 0.01) var squash_amount: float = 1.1
@export_range(0.0, 0.3, 0.01) var visual_recoil: float = 0.09
@export var flash_color: Color = Color(2.2, 1.65, 1.35)

var _rest_scale: Vector3
var _rest_position: Vector3
var _rest_color: Color
var _rest_shaded: bool
var _flash_tween: Tween
var _pose_tween: Tween
var _vignette_tween: Tween
var _vignette_material: ShaderMaterial
var _vignette_overlay: ColorRect
var _sparks: Array[GPUParticles3D] = []
var _next_spark: int = 0
var _dust: GPUParticles3D
var _configured: bool = false


func _ready() -> void:
	if (
		not is_instance_valid(player)
		or not is_instance_valid(sprite)
		or not is_instance_valid(visual)
		or not is_instance_valid(health)
	):
		return
	_rest_scale = visual.scale
	_rest_position = visual.position
	_rest_color = sprite.modulate
	_rest_shaded = sprite.shaded
	_create_sparks()
	_create_dust()
	_create_vignette()
	health.damaged.connect(_on_damaged)
	_configured = true


func _create_sparks() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	gradient.colors = PackedColorArray(
		[Color(1, 1, 0.9, 1), Color(1, 0.55, 0.2, 0.9), Color(1, 0.2, 0.05, 0)]
	)
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	var draw_material := StandardMaterial3D.new()
	draw_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_material.vertex_color_use_as_albedo = true
	draw_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.035, 0.22)
	mesh.material = draw_material
	for index in range(3):
		var material := ParticleProcessMaterial.new()
		material.spread = 180.0
		material.direction = Vector3.UP
		material.initial_velocity_min = 2.0
		material.initial_velocity_max = 4.0
		material.damping_min = 4.0
		material.damping_max = 6.0
		material.gravity = Vector3.ZERO
		material.angle_min = -180.0
		material.angle_max = 180.0
		material.color_ramp = ramp
		var burst := GPUParticles3D.new()
		burst.name = "ImpactSparks%d" % index
		burst.emitting = false
		burst.one_shot = true
		burst.explosiveness = 1.0
		burst.amount = 16
		burst.lifetime = 0.22
		burst.local_coords = false
		burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		burst.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
		burst.process_material = material
		burst.draw_pass_1 = mesh
		add_child(burst)
		burst.top_level = true
		_sparks.append(burst)


func _create_dust() -> void:
	# Lấy cấu hình hạt bụi mà không tạo thêm controller chạy.
	var source := DUST_SCENE.instantiate()
	_dust = source.get_node("Particle").duplicate() as GPUParticles3D
	source.free()
	_dust.process_material = _dust.process_material.duplicate()
	_dust.one_shot = true
	_dust.explosiveness = 1.0
	_dust.amount = 12
	_dust.amount_ratio = 1.0
	_dust.lifetime = 0.3
	_dust.local_coords = false
	_dust.emitting = false
	add_child(_dust)
	_dust.top_level = true


func _create_vignette() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	_vignette_overlay = ColorRect.new()
	_vignette_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette_material = ShaderMaterial.new()
	_vignette_material.shader = VIGNETTE_SHADER
	_vignette_overlay.material = _vignette_material
	layer.add_child(_vignette_overlay)
	_vignette_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette_overlay.hide()


func _on_damaged(amount: float) -> void:
	if not _configured or amount <= 0 or not is_instance_valid(sprite):
		return
	_play_flash()
	_play_recoil()
	_play_vignette()
	var burst: GPUParticles3D = _sparks[_next_spark]
	_next_spark = (_next_spark + 1) % _sparks.size()
	# Offset của Sprite3D tính bằng pixel, nên tâm ảnh không phải gốc Player.
	burst.global_position = (
		sprite.global_position
		+ Vector3.UP * (sprite.offset.y * sprite.pixel_size * sprite.global_basis.y.length())
		- player.pending_hit_direction * 0.25
	)
	burst.restart()
	burst.emitting = true
	if player.is_on_floor():
		_emit_ground_dust()
	get_node("/root/HitstopController").request(hitstop_duration)
	get_node("/root/ScreenShakeController").request(shake_pixels, 0.18)


func _play_flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	sprite.shaded = false
	sprite.modulate = Color(flash_color, _rest_color.a)
	_flash_tween = create_tween().set_ignore_time_scale(true)
	_flash_tween.tween_property(sprite, "modulate", Color(1, 0.4, 0.3, _rest_color.a), 0.05)
	_flash_tween.tween_property(sprite, "modulate", _rest_color, 0.14)
	_flash_tween.tween_callback(_restore_shading)


func _play_recoil() -> void:
	if _pose_tween != null and _pose_tween.is_valid():
		_pose_tween.kill()
	visual.scale = _rest_scale * Vector3(squash_amount, 0.88, 1.0)
	var parent := visual.get_parent() as Node3D
	var offset: Vector3 = parent.global_basis.inverse() * player.pending_hit_direction
	visual.position = _rest_position + offset * visual_recoil
	_pose_tween = create_tween().set_parallel().set_ignore_time_scale(true)
	_pose_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pose_tween.tween_property(visual, "scale", _rest_scale, 0.18)
	_pose_tween.tween_property(visual, "position", _rest_position, 0.18)


func _play_vignette() -> void:
	if _vignette_tween != null and _vignette_tween.is_valid():
		_vignette_tween.kill()
	_vignette_material.set_shader_parameter("strength", vignette_strength)
	_vignette_overlay.visible = vignette_strength > 0.0
	_vignette_tween = create_tween().set_ignore_time_scale(true)
	_vignette_tween.tween_property(_vignette_material, "shader_parameter/strength", 0.0, 0.28)
	_vignette_tween.tween_callback(_vignette_overlay.hide)


func _emit_ground_dust() -> void:
	var collider := player.get_node("CollisionShape3D") as CollisionShape3D
	var capsule := collider.shape as CapsuleShape3D
	_dust.global_position = (
		collider.global_position
		- Vector3.UP * (capsule.height * collider.global_basis.y.length() * 0.5 - 0.05)
	)
	var material := _dust.process_material as ParticleProcessMaterial
	material.direction = (
		_dust.global_basis.inverse()
		* (player.pending_hit_direction + Vector3.UP * 0.4).normalized()
	)
	_dust.restart()
	_dust.emitting = true


func _restore_shading() -> void:
	if is_instance_valid(sprite):
		sprite.shaded = _rest_shaded


func _exit_tree() -> void:
	if not _configured:
		return
	if is_instance_valid(sprite):
		sprite.modulate = _rest_color
		sprite.shaded = _rest_shaded
	if is_instance_valid(visual):
		visual.scale = _rest_scale
		visual.position = _rest_position
