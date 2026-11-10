extends Node3D
## Feedback từ damage thật; không thay đổi HP, hitstun hay quyền bất tử.

const DUST_SCENE: PackedScene = preload("res://gameplay/player/effects/run_dust_effect.tscn")
const VIGNETTE_SHADER: Shader = preload("res://gameplay/player/effects/hit_vignette.gdshader")
const SMOKE_TEXTURES := [
	preload("res://assets/sprites/effects/smoke/smoke_01.png"),
	preload("res://assets/sprites/effects/smoke/smoke_02.png"),
	preload("res://assets/sprites/effects/smoke/smoke_03.png"),
	preload("res://assets/sprites/effects/smoke/smoke_04.png"),
]
const SMOKE_SIZES := [Vector2(2.25, 1.5), Vector2(2.4, 1.2), Vector2(1.5, 2.25), Vector2(2.55, 2.3)]
const SMOKE_COUNTS := [5, 5, 3, 3]

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
@export var flash_color: Color = Color(1.0, 0.12, 0.12)
@export_group("Death Feedback")
@export_range(0.1, 1.0, 0.01) var vanish_duration: float = 0.22
@export_range(0.5, 1.0, 0.01) var death_zoom_factor: float = 0.73
@export_range(0.05, 0.8, 0.01) var death_zoom_duration: float = 0.28
@export_range(0.0, 0.12, 0.005) var death_hitstop_duration: float = 0.12
@export_range(0.0, 8.0, 0.5) var death_shake_pixels: float = 8.0
@export_range(0.0, 0.3, 0.01) var death_shake_duration: float = 0.3

var _rest_scale: Vector3
var _rest_position: Vector3
var _rest_color: Color
var _rest_shaded: bool
var _flash_tween: Tween
var _spine_flash_tween: Tween
var _pose_tween: Tween
var _vignette_tween: Tween
var _vignette_material: ShaderMaterial
var _vignette_overlay: ColorRect
var _sparks: Array[GPUParticles3D] = []
var _next_spark: int = 0
var _dust: GPUParticles3D
var _death_smoke: Array[GPUParticles3D] = []
var _death_tween: Tween
var _smoke_tween: Tween
var _camera_tween: Tween
var _death_camera: Camera3D
var _rest_camera_fov: float = 0.0
var _dying: bool = false
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
	_create_death_smoke()
	_create_vignette()
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
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


func _create_death_smoke() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.18, 0.52, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 0.0),
		Color(1, 1, 1, 1.0),
		Color(1, 1, 1, 0.95),
		Color(1, 1, 1, 0.0),
	])
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	for index in SMOKE_TEXTURES.size():
		var draw_material := StandardMaterial3D.new()
		draw_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		draw_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		draw_material.no_depth_test = true
		draw_material.render_priority = 10
		draw_material.vertex_color_use_as_albedo = true
		draw_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		draw_material.albedo_texture = SMOKE_TEXTURES[index]
		draw_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		var mesh := QuadMesh.new()
		mesh.size = SMOKE_SIZES[index]
		mesh.material = draw_material
		var material := ParticleProcessMaterial.new()
		material.color_ramp = ramp
		material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		material.emission_ring_axis = Vector3.UP
		material.emission_ring_radius = 0.45
		material.emission_ring_inner_radius = 0.12
		material.emission_ring_height = 0.15
		material.direction = Vector3.RIGHT
		material.spread = 180.0
		material.flatness = 1.0
		material.initial_velocity_min = 1.25
		material.initial_velocity_max = 1.85
		material.radial_accel_min = 4.0
		material.radial_accel_max = 5.5
		material.gravity = Vector3(0.0, 0.1, 0.0)
		material.damping_min = 0.6
		material.damping_max = 1.0
		material.scale_min = 0.72
		material.scale_max = 1.1
		var burst := GPUParticles3D.new()
		burst.name = "DeathSmoke%d" % (index + 1)
		burst.one_shot = true
		burst.explosiveness = 0.84
		burst.amount = SMOKE_COUNTS[index]
		burst.lifetime = 0.82
		burst.local_coords = false
		burst.emitting = false
		burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		burst.visibility_aabb = AABB(Vector3(-4, -3, -4), Vector3(8, 6, 8))
		burst.process_material = material
		burst.draw_pass_1 = mesh
		add_child(burst)
		burst.top_level = true
		_death_smoke.append(burst)


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
	if not _configured or _dying or amount <= 0 or not is_instance_valid(sprite):
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
	if _spine_flash_tween != null and _spine_flash_tween.is_valid():
		_spine_flash_tween.kill()
	sprite.shaded = false
	sprite.modulate = Color(flash_color, _rest_color.a)
	var spine_preview := visual.get_node_or_null("SpineIdlePreview")
	if spine_preview != null:
		spine_preview.set_hit_tint(0.75)
	_flash_tween = create_tween().set_ignore_time_scale(true)
	_flash_tween.tween_property(sprite, "modulate", Color(1, 0.28, 0.28, _rest_color.a), 0.05)
	_flash_tween.tween_property(sprite, "modulate", _rest_color, 0.14)
	_flash_tween.tween_callback(_restore_shading)
	if spine_preview != null:
		_spine_flash_tween = create_tween().set_ignore_time_scale(true)
		_spine_flash_tween.tween_method(spine_preview.set_hit_tint, 0.75, 0.0, 0.19)


func _on_died() -> void:
	if not _configured or _dying:
		return
	_dying = true
	get_node("/root/HitstopController").request(death_hitstop_duration)
	get_node("/root/ScreenShakeController").request(death_shake_pixels, death_shake_duration)
	for animation: Tween in [_flash_tween, _spine_flash_tween, _pose_tween]:
		if animation != null and animation.is_valid():
			animation.kill()
	_restore_shading()
	sprite.modulate = _rest_color
	var spine_preview := visual.get_node_or_null("SpineIdlePreview")
	if spine_preview != null:
		spine_preview.set_hit_tint(0.0)
	visual.position = _rest_position
	_death_camera = player.camera if is_instance_valid(player.camera) else get_viewport().get_camera_3d()
	if is_instance_valid(_death_camera):
		_rest_camera_fov = _death_camera.fov
		_camera_tween = create_tween().set_ignore_time_scale(true)
		_camera_tween.tween_property(
			_death_camera, "fov", _rest_camera_fov * death_zoom_factor, death_zoom_duration
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_death_tween = create_tween().set_ignore_time_scale(true)
	_death_tween.tween_property(
		visual, "scale", _rest_scale * Vector3(0.025, 0.005, 0.025), vanish_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_death_tween.tween_callback(_finish_vanish)
	_smoke_tween = create_tween().set_ignore_time_scale(true)
	_smoke_tween.tween_interval(vanish_duration * 0.45)
	_smoke_tween.tween_callback(_emit_death_smoke)


func _emit_death_smoke() -> void:
	for burst in _death_smoke:
		burst.global_position = player.global_position + Vector3.UP * 1.0
		burst.restart()
		burst.emitting = true


func _finish_vanish() -> void:
	visual.hide()


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
	if is_instance_valid(_death_camera) and _rest_camera_fov > 0.0:
		_death_camera.fov = _rest_camera_fov
