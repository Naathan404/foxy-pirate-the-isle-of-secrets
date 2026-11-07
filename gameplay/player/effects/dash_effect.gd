extends Node3D

const SPINE_GHOST_SHADER: Shader = preload(
	"res://gameplay/player/effects/spine_dash_ghost.gdshader"
)
const SPINE_GHOST_INTERVAL: float = 0.075
const SPINE_GHOST_LIFETIME: float = 0.12
const SPINE_GHOST_ALPHA: float = 0.22

@export var player: Player
@export var sprite: Sprite3D
@export var spine_preview: Node3D

@export_group("Afterimages")
@export_range(0.01, 0.1, 0.005) var ghost_interval: float = 0.025
@export_range(0.05, 0.5, 0.01) var ghost_lifetime: float = 0.24
@export var ghosts: Array[Sprite3D] = []

@export var ghost_color: Color = Color(0.45, 0.85, 1.0, 0.65)

@export_group("Dash Feedback")
@export_range(0.0, 3.0, 0.1) var shake_pixels: float = 1.2
@export_range(0.0, 0.3, 0.01) var ground_clearance: float = 0.04
@export_range(0.2, 2.0, 0.05) var ring_radius: float = 0.9

var _dashing: bool = false
var _ghost_timer: float = 0.0
var _next_ghost: int = 0
var _ghost_tweens: Array[Tween] = []
var _spine_ghosts: Array[Node3D] = []
var _rings: Array[MeshInstance3D] = []
var _ring_tweens: Array[Tween] = []
var _bursts: Array[GPUParticles3D] = []

@onready var dash_particle: GPUParticles3D = $DashParticle


func _ready() -> void:
	_ghost_tweens.resize(ghosts.size())
	for index in ghosts.size():
		var snapshot := Node3D.new()
		snapshot.name = "SpineGhost%d" % index
		add_child(snapshot)
		snapshot.top_level = true
		snapshot.hide()
		_spine_ghosts.append(snapshot)
	dash_particle.local_coords = false
	dash_particle.amount = 12
	dash_particle.lifetime = 0.15
	var dust_material := dash_particle.process_material as ParticleProcessMaterial
	if dust_material != null:
		dust_material.emission_box_extents = Vector3(0.08, 0.02, 0.06)
		dust_material.initial_velocity_min = 0.55
		dust_material.initial_velocity_max = 1.15
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
		material.albedo_color = Color(0.65, 0.95, 1.0, 0.35)
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
		burst.amount = 4 if index == 0 else 3
		burst.lifetime = 0.15
		burst.emitting = false
		var process := burst.process_material as ParticleProcessMaterial
		process.spread = 32.0
		process.emission_box_extents = Vector3(0.08, 0.02, 0.06)
		process.initial_velocity_min = 0.55
		process.initial_velocity_max = 1.15
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
		var interval := ghost_interval
		if _get_spine_afterimage_source() != null:
			interval = maxf(interval, SPINE_GHOST_INTERVAL)
		_ghost_timer = maxf(0.0, _ghost_timer + maxf(0.01, interval))


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
	var spine_source := _get_spine_afterimage_source()
	if is_instance_valid(spine_source) and _snapshot_spine_ghost(index, spine_source):
		g.hide()
		return
	_spine_ghosts[index].hide()
	# A newly selected Spine clip may not have rendered its first mesh yet.
	# Never reveal the hidden legacy sheet as a dash afterimage.
	if is_instance_valid(spine_preview) and bool(spine_preview.get("enabled")):
		g.hide()
		return

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

	g.modulate = Color(0.9, 1.0, 1.0, minf(ghost_color.a, SPINE_GHOST_ALPHA))
	g.show()

	var tween := g.create_tween().set_parallel()
	_ghost_tweens[index] = tween
	tween.tween_property(g, "modulate", Color(ghost_color, 0.0), ghost_lifetime)
	tween.chain().tween_callback(g.hide)


func _get_spine_afterimage_source() -> Node3D:
	if is_instance_valid(spine_preview) and spine_preview.has_method("get_afterimage_source"):
		return spine_preview.get_afterimage_source()
	return null


func _snapshot_spine_ghost(index: int, source: Node3D) -> bool:
	var snapshot := _spine_ghosts[index]
	for child in snapshot.get_children():
		child.hide()
		child.queue_free()
	var materials: Array[ShaderMaterial] = []
	for child in source.get_children(true):
		var draw := child as MeshInstance3D
		if draw == null or not draw.name.begins_with("_SpineDraw3D_"):
			continue
		if not draw.visible or draw.mesh == null or draw.material_override == null:
			continue
		var source_material := draw.material_override as ShaderMaterial
		if source_material == null:
			continue
		var material := ShaderMaterial.new()
		material.shader = SPINE_GHOST_SHADER
		material.render_priority = source_material.render_priority
		material.set_shader_parameter(
			"spine_texture", source_material.get_shader_parameter("spine_texture")
		)
		material.set_shader_parameter("spine_camera_relative_depth",
			source_material.get_shader_parameter("spine_camera_relative_depth"))
		material.set_shader_parameter("ghost_tint",
			Color(ghost_color.r, ghost_color.g, ghost_color.b,
				minf(ghost_color.a, SPINE_GHOST_ALPHA)))
		var copy := MeshInstance3D.new()
		copy.mesh = draw.mesh
		copy.material_override = material
		copy.transform = draw.transform
		copy.sorting_offset = draw.sorting_offset
		copy.sorting_use_aabb_center = false
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		snapshot.add_child(copy)
		materials.append(material)
	if materials.is_empty():
		return false
	snapshot.global_transform = source.global_transform
	snapshot.show()
	var tween := snapshot.create_tween().set_parallel()
	_ghost_tweens[index] = tween
	for material in materials:
		tween.tween_property(material, "shader_parameter/ghost_tint",
			Color(ghost_color.r, ghost_color.g, ghost_color.b, 0.0),
			minf(ghost_lifetime, SPINE_GHOST_LIFETIME))
	tween.chain().tween_callback(snapshot.hide)
	return true


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
	material.albedo_color.a = 0.35 if index == 0 else 0.22
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


### Signal dash started and finished
func _on_foxy_dash_started() -> void:
	if not is_instance_valid(player):
		return

	_update_particle_direction(dash_particle)
	dash_particle.global_position = _get_foot_position()
	dash_particle.emitting = true

	_dashing = true
	_ghost_timer = 0.045
	set_process(true)
	_play_ground_burst(0)
	var shake := get_node_or_null("/root/ScreenShakeController")
	if shake != null and shake_pixels > 0.0:
		shake.request(shake_pixels, 0.1)


func _on_foxy_dash_finished(interrupted: bool) -> void:
	# Ngừng tạo bụi mới, bụi cũ vẫn tự mờ hết
	dash_particle.emitting = false
	_dashing = false
	set_process(false)
	if not interrupted and is_instance_valid(player):
		_play_ground_burst(1)
