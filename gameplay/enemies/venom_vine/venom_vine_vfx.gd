class_name VenomVineVfx
extends RefCounted
## Tiện ích dựng hiệu ứng burst/spray/recoil/hit dùng chung cho VenomVine và EliteVenomVine.

const ACID_POOL_SCRIPT := preload("res://gameplay/enemies/venom_vine/venom_acid_pool.gd")
const PARTICLE_SHEET := preload("res://assets/sprites/enemies/venom_vine/venom_acid_particles.png")
const DUST_TEXTURE := preload("res://assets/sprites/effects/Dust Particle.png")
const TUNNEL_TRAIL_SHEET := preload(
	"res://assets/sprites/enemies/venom_vine/venom_vine_tunnel_trail.png"
)

const PARTICLE_CELL_SIZE := 256.0
const MUZZLE_FLASH_DURATION := 0.18
const MUZZLE_DROPLET_LIFETIME := 0.28
const HIT_EFFECT_HEIGHT_METERS := 1.25
const HIT_DROPLET_LIFETIME := 0.32
const NORMAL_GLOW_COLOR := Color(0.55, 1.0, 0.25)
const COUNTER_GLOW_COLOR := Color(1.0, 0.45, 0.18)
const PURPLE_ACID_GLOW_COLOR := Color(0.82, 0.34, 1.0)


static func spawn_muzzle_flash(
	parent: Node,
	spawn_pos: Vector3,
	facing_dir: Vector3,
	counter_mix: float,
	is_purple: bool = false
) -> void:
	if not is_instance_valid(parent) or parent.is_queued_for_deletion():
		return
	var base_glow := PURPLE_ACID_GLOW_COLOR if is_purple else NORMAL_GLOW_COLOR
	var flash_color := (
		COUNTER_GLOW_COLOR.lerp(Color.WHITE, 0.35)
		if counter_mix > 0.5
		else base_glow.lerp(Color.WHITE, 0.28)
	)
	spawn_additive_atlas_burst(
		parent,
		"VenomMuzzleFlash",
		spawn_pos,
		{
			"col": 0,
			"pixel_size": 0.0062,
			"tint": flash_color,
			"start_scale": 0.45,
			"end_scale": 1.25,
			"duration": MUZZLE_FLASH_DURATION,
			"billboard": true,
			"purple": is_purple,
		}
	)
	var shoot_dir := (facing_dir * 0.8 + Vector3.UP * 0.55).normalized()
	var start_col := Color(0.95, 0.65, 1.0, 0.95) if is_purple else Color(0.85, 1.0, 0.48, 0.95)
	var end_col := Color(0.56, 0.16, 0.94, 0.0) if is_purple else Color(0.3, 0.95, 0.22, 0.0)
	spawn_one_shot_spray(
		parent,
		"MuzzleAcidSpray",
		spawn_pos,
		shoot_dir,
		{
			"spread": 36.0,
			"vel_min": 2.0,
			"vel_max": 3.8,
			"gravity_y": -7.5,
			"count": 10,
			"lifetime": MUZZLE_DROPLET_LIFETIME,
			"start_color": start_col,
			"end_color": end_col,
			"col": 2,
			"purple": is_purple,
		}
	)


static func spawn_hit_impact_vfx(
	parent: Node, origin_pos: Vector3, hit_dir: Vector3, counter_triggered: bool
) -> void:
	if not is_instance_valid(parent) or parent.is_queued_for_deletion():
		return
	var hit_pos := origin_pos + Vector3.UP * HIT_EFFECT_HEIGHT_METERS
	var primary_col := (
		COUNTER_GLOW_COLOR.lerp(Color.WHITE, 0.35)
		if counter_triggered
		else NORMAL_GLOW_COLOR.lerp(Color.WHITE, 0.4)
	)
	var end_col := Color(1.0, 0.35, 0.1, 0.0) if counter_triggered else Color(0.28, 0.95, 0.22, 0.0)
	spawn_additive_atlas_burst(
		parent,
		"VenomHitFlash",
		hit_pos,
		{
			"col": 0,
			"pixel_size": 0.0068 if counter_triggered else 0.0056,
			"tint": primary_col,
			"start_scale": 0.45,
			"end_scale": 1.35 if counter_triggered else 1.1,
			"duration": 0.18,
			"billboard": true,
		}
	)
	spawn_additive_atlas_burst(
		parent,
		"VenomHitWave",
		hit_pos,
		{
			"col": 3,
			"pixel_size": 0.0066 if counter_triggered else 0.005,
			"tint": COUNTER_GLOW_COLOR if counter_triggered else NORMAL_GLOW_COLOR,
			"start_scale": 0.35,
			"end_scale": 1.55 if counter_triggered else 1.2,
			"duration": 0.24,
			"billboard": true,
		}
	)
	var away_dir := (
		Vector3(hit_dir.x, 0.65, hit_dir.z).normalized()
		if not hit_dir.is_zero_approx()
		else Vector3.UP
	)
	spawn_one_shot_spray(
		parent,
		"VenomHitDroplets",
		hit_pos,
		away_dir,
		{
			"spread": 58.0,
			"vel_min": 2.2,
			"vel_max": 4.5,
			"gravity_y": -8.5,
			"count": 18 if counter_triggered else 12,
			"lifetime": HIT_DROPLET_LIFETIME,
			"start_color": primary_col,
			"end_color": end_col,
			"col": 2,
		}
	)


static func spawn_additive_atlas_burst(
	parent: Node, node_name: String, world_pos: Vector3, config: Dictionary = {}
) -> void:
	var particle_col := int(config.get("col", 0))
	var billboard := bool(config.get("billboard", true))
	var pixel_size_value := float(config.get("pixel_size", 0.0056))
	var start_scale := float(config.get("start_scale", 0.45))
	var end_scale := float(config.get("end_scale", 1.2))
	var duration_seconds := float(config.get("duration", 0.2))
	var tint: Color = config.get("tint", NORMAL_GLOW_COLOR) as Color
	var is_purple := bool(config.get("purple", false))

	var atlas := AtlasTexture.new()
	atlas.atlas = PARTICLE_SHEET
	atlas.region = Rect2(
		float(particle_col) * PARTICLE_CELL_SIZE, 0.0, PARTICLE_CELL_SIZE, PARTICLE_CELL_SIZE
	)
	var mat: Material = null
	if is_purple:
		mat = ACID_POOL_SCRIPT.create_purple_particle_material(atlas, 1.35)
	else:
		var std_mat := StandardMaterial3D.new()
		std_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		std_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		std_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		std_mat.vertex_color_use_as_albedo = true
		if billboard:
			std_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		else:
			std_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		std_mat.albedo_texture = atlas
		std_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		std_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		mat = std_mat

	var burst := Sprite3D.new()
	burst.name = node_name
	burst.texture = atlas
	burst.pixel_size = pixel_size_value
	burst.billboard = (
		BaseMaterial3D.BILLBOARD_ENABLED if billboard else BaseMaterial3D.BILLBOARD_DISABLED
	)
	if not billboard:
		burst.rotation.x = -PI * 0.5
	burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	burst.modulate = tint
	burst.scale = Vector3.ONE * start_scale
	burst.material_override = mat
	burst.position = (parent as Node3D).to_local(world_pos) if parent is Node3D else world_pos
	parent.add_child(burst)
	burst.global_position = world_pos

	var tween := burst.create_tween().set_parallel(true)
	tween.tween_property(burst, "scale", Vector3.ONE * end_scale, duration_seconds)
	tween.tween_property(burst, "modulate:a", 0.0, duration_seconds)
	tween.chain().tween_callback(burst.queue_free)


static func spawn_one_shot_spray(
	parent: Node, node_name: String, world_pos: Vector3, spray_dir: Vector3, config: Dictionary = {}
) -> void:
	var lifetime_seconds := float(config.get("lifetime", 0.3))
	var particle_col := int(config.get("col", 2))
	var start_color: Color = config.get("start_color", Color(0.85, 1.0, 0.48, 0.95)) as Color
	var end_color: Color = config.get("end_color", Color(0.3, 0.95, 0.22, 0.0)) as Color
	var spray := CPUParticles3D.new()
	spray.name = node_name
	spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spray.amount = int(config.get("count", 10))
	spray.lifetime = lifetime_seconds
	spray.one_shot = true
	spray.explosiveness = 1.0
	spray.emitting = false
	spray.local_coords = false
	spray.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	spray.emission_sphere_radius = 0.14
	spray.direction = spray_dir
	spray.spread = float(config.get("spread", 45.0))
	spray.initial_velocity_min = float(config.get("vel_min", 2.0))
	spray.initial_velocity_max = float(config.get("vel_max", 4.0))
	spray.gravity = Vector3(0.0, float(config.get("gravity_y", -8.0)), 0.0)
	spray.scale_amount_min = 0.2
	spray.scale_amount_max = 0.38
	spray.color_ramp = ACID_POOL_SCRIPT.create_fade_ramp(start_color, end_color)
	var is_purple := bool(config.get("purple", false))
	spray.mesh = ACID_POOL_SCRIPT.create_particle_quad(
		particle_col, Vector2(0.42, 0.42), true, is_purple
	)
	spray.position = (parent as Node3D).to_local(world_pos) if parent is Node3D else world_pos
	parent.add_child(spray)
	spray.global_position = world_pos
	spray.emitting = true
	var cleanup := spray.create_tween()
	cleanup.tween_interval(lifetime_seconds + 0.18)
	cleanup.tween_callback(spray.queue_free)


static func spawn_burrow_pit(
	parent: Node,
	world_pos: Vector3,
	diameter_meters: float,
	hold_seconds: float,
	fade_seconds: float
) -> Sprite3D:
	if not is_instance_valid(parent) or parent.is_queued_for_deletion():
		return null
	var pit := Sprite3D.new()
	pit.name = "VenomBurrowPit"
	pit.texture = TUNNEL_TRAIL_SHEET
	pit.hframes = 4
	pit.vframes = 1
	pit.frame = 0
	pit.pixel_size = clampf(diameter_meters / 330.0, 0.004, 0.012)
	pit.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	pit.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pit.sorting_offset = -1.5
	var target_scale := Vector3(1.02, 1.04, 1.0)
	pit.scale = target_scale * 0.42
	pit.modulate = Color(1.0, 1.0, 1.0, 0.96)
	var pit_pos := world_pos + Vector3.UP * 0.035
	pit.position = (parent as Node3D).to_local(pit_pos) if parent is Node3D else pit_pos
	parent.add_child(pit)
	pit.global_position = pit_pos

	var tween := pit.create_tween()
	tween.tween_property(pit, "scale", target_scale, 0.24).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	tween.tween_interval(maxf(0.05, hold_seconds))
	tween.tween_property(pit, "modulate:a", 0.0, maxf(0.15, fade_seconds))
	tween.tween_callback(pit.queue_free)
	return pit


static func spawn_burrow_pit_from_template(
	parent: Node, template: Sprite3D, hold_seconds: float, fade_seconds: float
) -> Sprite3D:
	if (
		not is_instance_valid(parent)
		or parent.is_queued_for_deletion()
		or not is_instance_valid(template)
	):
		return null
	var pit := template.duplicate() as Sprite3D
	if pit == null:
		return null
	pit.name = "VenomDeparturePit"
	pit.visible = true
	var target_scale := template.scale
	var pit_world := template.global_position
	pit.global_transform = template.global_transform
	pit.scale = target_scale * 0.42
	pit.modulate = Color(1.0, 1.0, 1.0, 0.96)
	pit.position = (parent as Node3D).to_local(pit_world) if parent is Node3D else pit_world
	parent.add_child(pit)
	pit.global_position = pit_world

	var tween := pit.create_tween()
	tween.tween_property(pit, "scale", target_scale, 0.24).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	tween.tween_interval(maxf(0.05, hold_seconds))
	tween.tween_property(pit, "modulate:a", 0.0, maxf(0.15, fade_seconds))
	tween.tween_callback(pit.queue_free)
	return pit


static func spawn_tunnel_tease_mound(
	parent: Node, roots_texture: Texture2D, world_pos: Vector3, config: Dictionary = {}
) -> void:
	if not is_instance_valid(parent) or parent.is_queued_for_deletion():
		return
	var tease := Sprite3D.new()
	tease.name = String(config.get("name", "TunnelDecoyTease"))
	tease.texture = roots_texture
	tease.hframes = 4
	tease.vframes = 2
	tease.frame = 4
	tease.offset = Vector2(0.0, 146.0)
	tease.pixel_size = float(config.get("pixel_size", 0.0056))
	tease.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	tease.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tease.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var base_scale := Vector3.ONE * float(config.get("scale", 0.9))
	tease.scale = Vector3(base_scale.x * 0.35, 0.08, base_scale.z * 0.35)
	tease.modulate = Color(1.04, 0.96, 0.88, float(config.get("alpha", 0.9)))
	var tease_pos := world_pos + Vector3.UP * 0.035
	tease.position = (parent as Node3D).to_local(tease_pos) if parent is Node3D else tease_pos
	parent.add_child(tease, true)
	tease.global_position = tease_pos

	var hold_seconds := maxf(0.12, float(config.get("hold", 0.3)))
	var sink_seconds := maxf(0.15, float(config.get("fade", 0.28)))
	var tween := tease.create_tween()
	tween.tween_property(tease, "scale", base_scale, 0.2).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	tween.tween_interval(hold_seconds)
	tween.tween_property(
		tease, "scale", Vector3(base_scale.x * 0.42, 0.06, base_scale.z * 0.42), sink_seconds
	)
	tween.parallel().tween_property(tease, "modulate:a", 0.0, sink_seconds)
	tween.tween_callback(tease.queue_free)


static func spawn_tunnel_trail_dot(
	parent: Node, world_pos: Vector3, config: Dictionary = {}
) -> void:
	if not is_instance_valid(parent) or parent.is_queued_for_deletion():
		return
	var dot := Sprite3D.new()
	dot.name = String(config.get("name", "TunnelTrailDot"))
	dot.texture = TUNNEL_TRAIL_SHEET
	dot.hframes = 4
	dot.vframes = 1
	dot.frame = 1
	var width_meters := float(config.get("width", 0.56))
	dot.pixel_size = clampf(width_meters / 210.0, 0.0018, 0.0042)
	dot.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	dot.offset = Vector2(0.0, 128.0)
	dot.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dot.flip_h = randf() < 0.5
	var dot_scale := float(config.get("scale", 0.92))
	var alpha_value := clampf(float(config.get("alpha", 0.88)), 0.15, 1.0)
	var hold_seconds := maxf(0.15, float(config.get("hold", 0.85)))
	var fade_seconds := maxf(0.2, float(config.get("fade", 0.45)))
	# Từng đụn chấm hiện trồi lên rồi chìm xuống ngay tại chỗ, không lướt trên đất.
	dot.scale = Vector3(dot_scale * 0.3, 0.06, dot_scale * 0.3)
	dot.modulate = Color(0.95, 0.92, 0.88, alpha_value)
	var dot_pos := world_pos + Vector3.UP * 0.025
	dot.position = (parent as Node3D).to_local(dot_pos) if parent is Node3D else dot_pos
	parent.add_child(dot, true)
	dot.global_position = dot_pos

	var tween := dot.create_tween()
	(
		tween
		. tween_property(dot, "scale", Vector3.ONE * dot_scale, 0.18)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	tween.tween_interval(hold_seconds)
	tween.tween_property(
		dot, "scale", Vector3(dot_scale * 0.42, 0.06, dot_scale * 0.42), fade_seconds
	)
	tween.parallel().tween_property(dot, "modulate:a", 0.0, fade_seconds)
	tween.tween_callback(dot.queue_free)


static func spawn_tunnel_track_scar(
	parent: Node,
	world_pos: Vector3,
	travel_dir: Vector3,
	width_meters: float,
	hold_seconds: float,
	fade_seconds: float
) -> void:
	if not is_instance_valid(parent) or parent.is_queued_for_deletion():
		return
	var scar := Sprite3D.new()
	scar.name = "TunnelGroundScar"
	scar.texture = TUNNEL_TRAIL_SHEET
	scar.hframes = 4
	scar.vframes = 1
	scar.frame = 2 if randf() > 0.28 else 3
	scar.pixel_size = clampf(width_meters / 320.0, 0.0035, 0.011)
	var flat_dir := Vector3(travel_dir.x, 0.0, travel_dir.z)
	# Frame 2/3 nam ngang theo truc X cuc bo, xoay local +X trung voi huong bo ngam.
	var yaw := atan2(-flat_dir.z, flat_dir.x) if not flat_dir.is_zero_approx() else 0.0
	yaw += randf_range(-0.1, 0.1)
	scar.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -PI * 0.5)
	scar.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	scar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scar.sorting_offset = -2.0
	var final_scale := Vector3(1.18, 0.88, 1.0)
	scar.scale = final_scale * 0.5
	scar.modulate = Color(1.0, 1.0, 1.0, 0.84)
	var scar_pos := world_pos + Vector3.UP * 0.032
	scar.position = (parent as Node3D).to_local(scar_pos) if parent is Node3D else scar_pos
	parent.add_child(scar)
	scar.global_position = scar_pos

	var tween := scar.create_tween()
	tween.tween_property(scar, "scale", final_scale, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_OUT
	)
	tween.tween_interval(maxf(0.1, hold_seconds))
	tween.tween_callback(
		func() -> void:
			if is_instance_valid(scar):
				scar.frame = 3
	)
	tween.tween_property(scar, "modulate:a", 0.0, maxf(0.2, fade_seconds))
	tween.tween_callback(scar.queue_free)


static func spawn_dirt_dust_burst(
	parent: Node,
	node_name: String,
	world_pos: Vector3,
	spray_dir: Vector3,
	count: int,
	lifetime_seconds: float = 0.42
) -> void:
	if not is_instance_valid(parent) or parent.is_queued_for_deletion():
		return
	var particles := CPUParticles3D.new()
	particles.name = node_name
	particles.emitting = false
	particles.one_shot = true
	particles.amount = count
	particles.lifetime = lifetime_seconds
	particles.explosiveness = 0.88
	particles.randomness = 0.45
	particles.local_coords = false

	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.24
	var norm_dir := spray_dir.normalized() if not spray_dir.is_zero_approx() else Vector3.UP
	particles.direction = norm_dir
	particles.spread = 66.0
	particles.initial_velocity_min = 1.6
	particles.initial_velocity_max = 3.4
	particles.gravity = Vector3(0.0, -8.5, 0.0)
	particles.damping_min = 2.0
	particles.damping_max = 3.8
	particles.scale_amount_min = 0.28
	particles.scale_amount_max = 0.62

	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.45))
	scale_curve.add_point(Vector2(0.32, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.15))
	particles.scale_amount_curve = scale_curve

	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(0.56, 0.43, 0.29, 0.88), Color(0.32, 0.24, 0.16, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 1.0])
	particles.color_ramp = ramp

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = DUST_TEXTURE
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.46, 0.46)
	mesh.material = mat
	particles.mesh = mesh

	var spawn_pos := world_pos + Vector3.UP * 0.14
	particles.position = ((parent as Node3D).to_local(spawn_pos) if parent is Node3D else spawn_pos)
	parent.add_child(particles)
	particles.global_position = spawn_pos
	particles.restart()
	particles.emitting = true

	var cleanup := particles.create_tween()
	cleanup.tween_interval(lifetime_seconds + 0.25)
	cleanup.tween_callback(particles.queue_free)
