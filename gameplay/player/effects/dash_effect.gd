extends Node3D

@export var player: Player
@export var sprite: Sprite3D

@export_group("Afterimages")
@export_range(0.01, 0.1, 0.005) var ghost_interval: float = 0.025
@export_range(0.05, 0.5, 0.01) var ghost_lifetime: float = 0.24
@export var ghosts: Array[Sprite3D] = []

@export var ghost_color: Color = Color(0.45, 0.85, 1.0, 0.65)

@export_group("Dash Feedback")
@export_range(1.0, 1.3, 0.01) var stretch_amount: float = 1.16
@export_range(0.0, 3.0, 0.1) var shake_pixels: float = 1.2
@export_range(0.0, 0.3, 0.01) var ground_clearance: float = 0.04
@export_range(0.2, 2.0, 0.05) var ring_radius: float = 0.9

var _dashing: bool = false
var _ghost_timer: float = 0.0
var _next_ghost: int = 0
var _ghost_tweens: Array[Tween] = []
var _sprite_tween: Tween
var _sprite_rest_scale: Vector3 = Vector3.ONE
var _rings: Array[MeshInstance3D] = []
var _ring_tweens: Array[Tween] = []
var _bursts: Array[GPUParticles3D] = []

@onready var dash_particle: GPUParticles3D = $DashParticle


func _ready() -> void:
	if is_instance_valid(sprite):
		_sprite_rest_scale = sprite.scale
	_ghost_tweens.resize(ghosts.size())
	dash_particle.local_coords = false
	_create_burst_effects()
	set_process(false)

	for g in ghosts:
		if not is_instance_valid(g):
			continue

		g.top_level = true
		g.hide()
		g.shaded = false
		g.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _create_burst_effects() -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.82
	mesh.outer_radius = 1.0
	mesh.rings = 24
	mesh.ring_segments = 4
	_ring_tweens.resize(2)
	for index in range(2):
		var ring := MeshInstance3D.new()
		ring.name = "DashRing%d" % index
		ring.mesh = mesh
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.albedo_color = Color(0.65, 0.95, 1.0, 0.65)
		ring.material_override = material
		add_child(ring)
		ring.top_level = true
		ring.hide()
		_rings.append(ring)

		var burst := dash_particle.duplicate() as GPUParticles3D
		burst.name = "DashBurst%d" % index
		burst.process_material = dash_particle.process_material.duplicate()
		burst.one_shot = true
		burst.explosiveness = 1.0
		burst.amount = 18 if index == 0 else 10
		burst.lifetime = 0.28
		burst.emitting = false
		var process := burst.process_material as ParticleProcessMaterial
		process.spread = 75.0
		process.initial_velocity_min = 1.8
		process.initial_velocity_max = 3.6
		add_child(burst)
		burst.top_level = true
		_bursts.append(burst)


func _process(delta: float) -> void:
	if not _dashing:
		return
	_update_particle_direction(dash_particle)
	dash_particle.global_position = _get_foot_position() - player.last_facing_direction * 0.15
	_ghost_timer -= delta
	if _ghost_timer <= 0.0:
		_show_next_ghost()
		_ghost_timer = maxf(0.0, _ghost_timer + maxf(0.01, ghost_interval))


func _show_next_ghost() -> void:
	if ghosts.is_empty() or not is_instance_valid(sprite):
		return

	var index = _next_ghost
	_next_ghost += 1
	if _next_ghost >= ghosts.size():
		_next_ghost = 0

	var g = ghosts[index]
	if not is_instance_valid(g):
		return

	var old_tween = _ghost_tweens[index]
	if old_tween != null and old_tween.is_valid():
		old_tween.kill()

	g.texture = sprite.texture
	g.hframes = sprite.hframes
	g.vframes = sprite.vframes
	g.frame = sprite.frame
	g.pixel_size = sprite.pixel_size
	g.offset = sprite.offset
	g.centered = sprite.centered
	g.flip_h = sprite.flip_h
	g.billboard = sprite.billboard
	g.global_transform = sprite.global_transform

	g.modulate = Color(0.9, 1.0, 1.0, ghost_color.a)
	g.show()

	var tween := g.create_tween().set_parallel()
	_ghost_tweens[index] = tween
	tween.tween_property(g, "modulate", Color(ghost_color, 0.0), ghost_lifetime)
	tween.tween_property(g, "scale", g.scale * Vector3(0.92, 0.98, 1.0), ghost_lifetime)
	tween.chain().tween_callback(g.hide)


func _get_foot_position() -> Vector3:
	var foot: Vector3 = player.global_position
	var collider := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collider != null and collider.shape is CapsuleShape3D:
		var capsule := collider.shape as CapsuleShape3D
		foot = collider.global_position
		foot.y -= capsule.height * collider.global_basis.y.length() * 0.5
	return foot + Vector3.UP * ground_clearance


func _update_particle_direction(particle: GPUParticles3D) -> void:
	var direction := -player.last_facing_direction
	direction.y = 0.25
	var material := particle.process_material as ParticleProcessMaterial
	if material != null:
		material.direction = particle.global_basis.inverse() * direction.normalized()


func _play_ground_burst(index: int) -> void:
	var ring: MeshInstance3D = _rings[index]
	var material := ring.material_override as StandardMaterial3D
	if _ring_tweens[index] != null and _ring_tweens[index].is_valid():
		_ring_tweens[index].kill()
	var radius: float = ring_radius if index == 0 else ring_radius * 0.7
	ring.global_position = _get_foot_position()
	ring.scale = Vector3(radius * 0.2, 0.12, radius * 0.2)
	material.albedo_color.a = 0.65 if index == 0 else 0.4
	ring.show()
	var tween := ring.create_tween().set_parallel()
	_ring_tweens[index] = tween
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "scale", Vector3(radius, 0.06, radius), 0.22)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.22)
	tween.chain().tween_callback(ring.hide)
	var burst: GPUParticles3D = _bursts[index]
	burst.global_position = ring.global_position + Vector3.UP * 0.08
	_update_particle_direction(burst)
	burst.restart()
	burst.emitting = true


func _stretch_sprite() -> void:
	if not is_instance_valid(sprite):
		return
	if _sprite_tween != null and _sprite_tween.is_valid():
		_sprite_tween.kill()
	var camera := get_viewport().get_camera_3d()
	var right := camera.global_basis.x if camera != null else Vector3.RIGHT
	var horizontal: bool = absf(player.last_facing_direction.dot(right.normalized())) > 0.7
	var factor := (
		Vector3(stretch_amount, 0.9, 1.0) if horizontal else Vector3(0.92, stretch_amount, 1.0)
	)
	_sprite_tween = create_tween()
	_sprite_tween.tween_property(sprite, "scale", _sprite_rest_scale * factor, 0.045)


func _restore_sprite(immediate: bool) -> void:
	if _sprite_tween != null and _sprite_tween.is_valid():
		_sprite_tween.kill()
	if not is_instance_valid(sprite):
		return
	if immediate:
		sprite.scale = _sprite_rest_scale
	else:
		_sprite_tween = create_tween()
		_sprite_tween.tween_property(sprite, "scale", _sprite_rest_scale, 0.1)


### Signal dash started and finished
func _on_foxy_dash_started() -> void:
	if not is_instance_valid(player):
		return

	_update_particle_direction(dash_particle)
	dash_particle.global_position = _get_foot_position()
	dash_particle.emitting = true

	_dashing = true
	_ghost_timer = maxf(0.01, ghost_interval)
	set_process(true)
	_show_next_ghost()
	_play_ground_burst(0)
	_stretch_sprite()
	var shake := get_node_or_null("/root/ScreenShakeController")
	if shake != null and shake_pixels > 0.0:
		shake.request(shake_pixels, 0.1)


func _on_foxy_dash_finished(interrupted: bool) -> void:
	# Ngừng tạo bụi mới, bụi cũ vẫn tự mờ hết
	dash_particle.emitting = false
	_dashing = false
	set_process(false)
	_restore_sprite(interrupted)
	if not interrupted and is_instance_valid(player):
		_play_ground_burst(1)


func _exit_tree() -> void:
	_restore_sprite(true)
