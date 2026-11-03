class_name EliteFeedback
extends Node3D

## Presentation feedback: sprite-bound elite glow, wind-up warning, pulse, and movement dust.
## Combat states decide when to begin and end the telegraph.

const DUST_TEXTURE: Texture2D = preload("res://assets/sprites/effects/Dust Particle.png")
const ELITE_SPRITE_GLOW_SHADER: Shader = preload(
	"res://gameplay/enemies/elite_sprite_glow.gdshader"
)

@export_group("Elite Identity")
@export_range(0.0, 1.0, 0.01) var elite_glow_strength: float = 0.9
@export_group("Attack Telegraph")
@export_range(0.5, 5.0, 0.05, "suffix:m") var telegraph_ring_radius: float = 1.35
@export_range(0.01, 0.2, 0.005, "suffix:m") var telegraph_ring_thickness: float = 0.045
@export_group("Movement Dust")
@export_range(0.05, 5.0, 0.05) var movement_dust_minimum_speed: float = 0.3
@export_range(0.3, 3.0, 0.05) var movement_dust_step_distance: float = 1.2
@export_range(0.0, 1.0, 0.01) var movement_dust_heel_offset: float = 0.32

var _movement_smoke: GPUParticles3D
var _source_sprite: Sprite3D
var _elite_sprite_glow_material: ShaderMaterial
var _previous_sprite_overlay: Material
var _telegraph_ring: MeshInstance3D
var _telegraph_ring_material: StandardMaterial3D
var _telegraph_active: bool = false
var _telegraph_elapsed: float = 0.0
var _telegraph_base_modulate: Color = Color.WHITE
var _telegraph_base_scale: Vector3 = Vector3.ONE
var _movement_dust_material: ParticleProcessMaterial
var _movement_dust_puffs: Array[GPUParticles3D] = []
var _movement_dust_next_puff: int = 0
var _movement_dust_distance: float = 0.0


func _ready() -> void:
	var enemy := get_parent() as EnemyBase
	if enemy != null:
		# Child _ready runs before EnemyBase caches its @onready visual field.
		_source_sprite = enemy.get_node_or_null("Visual/Sprite3D") as Sprite3D
	_setup_elite_sprite_glow()
	_create_telegraph_ring()
	_create_movement_smoke()


func _process(delta: float) -> void:
	_update_elite_sprite_glow()
	_update_telegraph_flash(delta)
	_update_movement_smoke()


func begin_telegraph() -> void:
	if is_instance_valid(_source_sprite):
		_telegraph_base_modulate = _source_sprite.modulate
		_telegraph_base_scale = _source_sprite.scale
	_telegraph_active = true
	_telegraph_elapsed = 0.0
	if is_instance_valid(_telegraph_ring):
		_telegraph_ring.visible = true


func end_telegraph() -> void:
	if _telegraph_active and is_instance_valid(_source_sprite):
		_source_sprite.modulate = _telegraph_base_modulate
		_source_sprite.scale = _telegraph_base_scale
	_telegraph_active = false
	if is_instance_valid(_telegraph_ring):
		_telegraph_ring.visible = false


func _setup_elite_sprite_glow() -> void:
	if not is_instance_valid(_source_sprite):
		return
	_previous_sprite_overlay = _source_sprite.material_overlay
	_elite_sprite_glow_material = ShaderMaterial.new()
	_elite_sprite_glow_material.shader = ELITE_SPRITE_GLOW_SHADER
	_elite_sprite_glow_material.render_priority = 2
	_source_sprite.material_overlay = _elite_sprite_glow_material
	_sync_elite_sprite_glow_parameters()


func _create_telegraph_ring() -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = maxf(0.05, telegraph_ring_radius - telegraph_ring_thickness)
	mesh.outer_radius = telegraph_ring_radius
	mesh.rings = 32
	mesh.ring_segments = 8
	_telegraph_ring_material = StandardMaterial3D.new()
	_telegraph_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_telegraph_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_telegraph_ring_material.albedo_color = Color(1.0, 0.72, 0.24, 0.72)
	_telegraph_ring_material.emission_enabled = true
	_telegraph_ring_material.emission = Color(1.0, 0.48, 0.08)
	_telegraph_ring_material.emission_energy_multiplier = 1.6
	mesh.material = _telegraph_ring_material
	_telegraph_ring = MeshInstance3D.new()
	_telegraph_ring.name = "EliteAttackTelegraphRing"
	_telegraph_ring.mesh = mesh
	_telegraph_ring.position.y = 0.045
	_telegraph_ring.visible = false
	add_child(_telegraph_ring)


func _create_movement_smoke() -> void:
	_movement_smoke = GPUParticles3D.new()
	_movement_smoke.name = "EliteMovementSmoke"
	_movement_smoke.amount = 24
	_movement_smoke.amount_ratio = 0.18
	_movement_smoke.lifetime = 0.28
	_movement_smoke.fixed_fps = 60
	_movement_smoke.local_coords = false
	_movement_smoke.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 4, 8))
	_movement_smoke.process_material = _make_movement_smoke_material()
	_movement_dust_material = _movement_smoke.process_material as ParticleProcessMaterial
	_movement_smoke.draw_pass_1 = _make_movement_dust_mesh()
	_movement_smoke.emitting = false
	add_child(_movement_smoke)
	_create_movement_dust_puffs()


func _create_movement_dust_puffs() -> void:
	for index in range(3):
		var puff := _movement_smoke.duplicate() as GPUParticles3D
		puff.name = "EliteMovementPuff%d" % index
		puff.process_material = _movement_smoke.process_material.duplicate()
		puff.one_shot = true
		puff.explosiveness = 1.0
		puff.amount_ratio = 1.0
		puff.amount = 4
		puff.lifetime = 0.26
		puff.emitting = false
		var material := puff.process_material as ParticleProcessMaterial
		material.spread = 55.0
		material.initial_velocity_min = 0.55
		material.initial_velocity_max = 1.05
		material.scale_min = 0.72
		material.scale_max = 1.12
		add_child(puff)
		puff.top_level = true
		_movement_dust_puffs.append(puff)


func _make_movement_smoke_material() -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(0.18, 0.01, 0.12)
	material.direction = Vector3(0.0, 0.4, 1.0)
	material.spread = 35.0
	material.initial_velocity_min = 0.35
	material.initial_velocity_max = 0.75
	material.gravity = Vector3(0.0, 0.3, 0.0)
	material.damping_min = 1.5
	material.damping_max = 2.5
	material.scale_min = 0.68
	material.scale_max = 1.18
	material.color_ramp = _make_movement_dust_ramp()
	return material


func _make_movement_dust_ramp() -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.16, 1.0])
	gradient.colors = PackedColorArray(
		[Color(0.92, 0.95, 1.0, 0.0), Color(0.88, 0.91, 0.96, 0.42), Color(0.68, 0.72, 0.8, 0.0)]
	)
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	return ramp


func _make_movement_dust_mesh() -> QuadMesh:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.albedo_texture = DUST_TEXTURE
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.28, 0.28)
	mesh.material = material
	return mesh


func _update_elite_sprite_glow() -> void:
	if _elite_sprite_glow_material == null or not is_instance_valid(_source_sprite):
		return
	var enemy := get_parent() as EnemyBase
	if enemy == null or enemy.dead:
		_elite_sprite_glow_material.set_shader_parameter("glow_strength", 0.0)
		return
	_sync_elite_sprite_glow_parameters()


func _sync_elite_sprite_glow_parameters() -> void:
	if _elite_sprite_glow_material == null or not is_instance_valid(_source_sprite):
		return
	_elite_sprite_glow_material.set_shader_parameter("glow_strength", elite_glow_strength)
	var hframes := maxi(1, _source_sprite.hframes)
	var vframes := maxi(1, _source_sprite.vframes)
	var frame_count := hframes * vframes
	var frame := clampi(_source_sprite.frame, 0, frame_count - 1)
	var frame_column := frame % hframes
	var frame_row := frame / hframes
	_elite_sprite_glow_material.set_shader_parameter(
		"frame_uv_offset", Vector2(float(frame_column) / hframes, float(frame_row) / vframes)
	)
	_elite_sprite_glow_material.set_shader_parameter(
		"frame_uv_size", Vector2(1.0 / hframes, 1.0 / vframes)
	)
	var texture_size: Vector2i = Vector2i.ONE
	if _source_sprite.texture != null:
		texture_size = _source_sprite.texture.get_size()
	var frame_aspect := 1.0
	if texture_size.y > 0:
		frame_aspect = (float(texture_size.x) / hframes) / (float(texture_size.y) / vframes)
	_elite_sprite_glow_material.set_shader_parameter("frame_aspect", frame_aspect)


func _update_telegraph_flash(delta: float) -> void:
	if not _telegraph_active:
		return
	_telegraph_elapsed += maxf(0.0, delta)
	var pulse := 0.5 + 0.5 * sin(_telegraph_elapsed * 14.0)
	if is_instance_valid(_source_sprite):
		var brightness := lerpf(0.16, 0.52, pulse)
		var bright_color := Color(1.35, 1.35, 1.35, _telegraph_base_modulate.a)
		_source_sprite.modulate = _telegraph_base_modulate.lerp(bright_color, brightness)
		_source_sprite.scale = _telegraph_base_scale * (1.0 + 0.035 * pulse)
	_update_telegraph_ring(pulse)


func _update_telegraph_ring(pulse: float) -> void:
	if not is_instance_valid(_telegraph_ring) or _telegraph_ring_material == null:
		return
	# One ground ring blinks during the warning window only; it is gone before the strike starts.
	_telegraph_ring.visible = sin(_telegraph_elapsed * 18.0) >= -0.15
	var alpha := lerpf(0.3, 0.8, pulse)
	var ring_color := _telegraph_ring_material.albedo_color
	ring_color.a = alpha
	_telegraph_ring_material.albedo_color = ring_color
	_telegraph_ring_material.emission_energy_multiplier = lerpf(1.1, 2.0, pulse)


func _update_movement_smoke() -> void:
	if not is_instance_valid(_movement_smoke) or _movement_dust_material == null:
		return
	var enemy := get_parent() as EnemyBase
	if enemy == null or enemy.dead:
		_stop_movement_dust()
		return
	var movement := enemy.get_real_velocity()
	movement.y = 0.0
	if not enemy.is_on_floor() or movement.length() <= movement_dust_minimum_speed:
		_stop_movement_dust()
		return
	var direction := movement.normalized()
	var foot := _get_enemy_foot_position(enemy)
	var speed_ratio := clampf(movement.length() / maxf(0.1, enemy.data.move_speed), 0.0, 1.0)
	_movement_smoke.global_position = foot - direction * movement_dust_heel_offset
	_movement_smoke.amount_ratio = lerpf(0.12, 0.3, speed_ratio)
	_movement_dust_material.direction = (
		_movement_smoke.global_basis.inverse() * (-direction + Vector3.UP * 0.45).normalized()
	)
	_movement_smoke.emitting = true
	_movement_dust_distance += movement.length() * get_process_delta_time()
	if _movement_dust_distance >= movement_dust_step_distance:
		_movement_dust_distance = fmod(_movement_dust_distance, movement_dust_step_distance)
		_emit_movement_dust_puff(foot - direction * movement_dust_heel_offset, direction)


func _stop_movement_dust() -> void:
	if is_instance_valid(_movement_smoke):
		_movement_smoke.emitting = false
	_movement_dust_distance = 0.0


func _emit_movement_dust_puff(origin: Vector3, direction: Vector3) -> void:
	if _movement_dust_puffs.is_empty():
		return
	var puff := _movement_dust_puffs[_movement_dust_next_puff]
	_movement_dust_next_puff = (_movement_dust_next_puff + 1) % _movement_dust_puffs.size()
	if not is_instance_valid(puff):
		return
	puff.global_position = origin
	var material := puff.process_material as ParticleProcessMaterial
	if material != null:
		material.direction = (
			puff.global_basis.inverse() * (-direction + Vector3.UP * 0.35).normalized()
		)
	puff.restart()
	puff.emitting = true


func _get_enemy_foot_position(enemy: EnemyBase) -> Vector3:
	var foot := enemy.global_position
	var collider := enemy.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collider != null and collider.shape is CapsuleShape3D:
		var capsule := collider.shape as CapsuleShape3D
		foot = collider.global_position
		foot.y -= capsule.height * collider.global_basis.y.length() * 0.5
	return foot + Vector3.UP * 0.05


func _exit_tree() -> void:
	if (
		is_instance_valid(_source_sprite)
		and _source_sprite.material_overlay == _elite_sprite_glow_material
	):
		_source_sprite.material_overlay = _previous_sprite_overlay
