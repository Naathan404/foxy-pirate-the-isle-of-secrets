class_name FireflyVfx
extends RefCounted
## Bộ dựng VFX hạt sáng thuần túy và ánh sáng đèn lồng cho FireflyEnemy.

const POLLEN_FIELD_SCRIPT := preload("res://gameplay/enemies/firefly/firefly_pollen_field.gd")
const GLOW_SHADER := preload("res://gameplay/enemies/firefly/firefly_glow.gdshader")
const VFX_SHEET := preload("res://assets/sprites/enemies/firefly/firefly_vfx_sheet.png")
const SPARK_MOTE_TEXTURE := preload("res://assets/sprites/enemies/firefly/firefly_spark_mote.png")

const VFX_CELL_SIZE := 256.0
const BLAST_SPARK_COUNT := 26
const COUNTER_SPARK_COUNT := 16
const VENT_SPARK_COUNT := 12
const SWIFT_SPARK_COUNT := 8


## Trả về vùng con của sheet hào quang nổ Đom đóm (cột 0..3).
static func create_vfx_atlas(cell_col: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = VFX_SHEET
	atlas.region = Rect2(float(cell_col) * VFX_CELL_SIZE, 0.0, VFX_CELL_SIZE, VFX_CELL_SIZE)
	return atlas


## Phát toàn bộ cụm chớp sáng và tia lửa vàng cam cho cú nổ chính trên không.
static func spawn_blast_vfx(
	parent: Node, blast_center: Vector3, blast_radius_meters: float
) -> void:
	if not is_instance_valid(parent) or parent.is_queued_for_deletion():
		return
	spawn_vfx_burst(
		parent,
		"FireflySolarFlash",
		blast_center + Vector3.UP * 0.65,
		SPARK_MOTE_TEXTURE,
		Color(1.0, 0.94, 0.45, 1.0),
		0.55,
		2.6,
		0.28,
		true
	)
	spawn_vfx_burst(
		parent,
		"FireflyOuterFlare",
		blast_center + Vector3.UP * 0.08,
		create_vfx_atlas(3),
		Color(1.0, 0.82, 0.24, 0.98),
		0.45,
		blast_radius_meters * 1.25,
		0.36,
		false
	)
	spawn_vfx_burst(
		parent,
		"FireflyInnerPulseRing",
		blast_center + Vector3.UP * 0.1,
		create_vfx_atlas(2),
		Color(1.0, 0.98, 0.65, 0.92),
		0.25,
		blast_radius_meters * 0.92,
		0.26,
		false
	)
	spawn_blast_sparks(parent, blast_center + Vector3.UP * 0.45, BLAST_SPARK_COUNT)


## Phát VFX tia lửa nhẹ khi Đom đóm lướt bay thoát thân không gây sát thương.
static func spawn_swift_escape_vfx(parent: Node, center: Vector3) -> void:
	if not is_instance_valid(parent) or parent.is_queued_for_deletion():
		return
	spawn_blast_sparks(parent, center + Vector3.UP * 0.45, SWIFT_SPARK_COUNT)


## Phát VFX xì vũng phấn độc vàng-lục khi bị ép dưới đất.
static func spawn_pollen_vent_vfx(parent: Node, center: Vector3, pool_radius: float) -> void:
	if not is_instance_valid(parent) or parent.is_queued_for_deletion():
		return
	spawn_vfx_burst(
		parent,
		"FireflyVentFlash",
		center + Vector3.UP * 0.45,
		SPARK_MOTE_TEXTURE,
		Color(0.76, 1.0, 0.34, 0.92),
		0.32,
		pool_radius * 1.45,
		0.26,
		true
	)
	spawn_blast_sparks(parent, center + Vector3.UP * 0.45, VENT_SPARK_COUNT)


## Phát VFX xung đẩy gió vàng cam khi Đom đóm bung đòn đẩy lùi.
static func spawn_gale_pulse_vfx(parent: Node, center: Vector3, blast_radius: float) -> void:
	if not is_instance_valid(parent) or parent.is_queued_for_deletion():
		return
	spawn_vfx_burst(
		parent,
		"FireflyCounterFlash",
		center + Vector3.UP * 0.55,
		SPARK_MOTE_TEXTURE,
		Color(1.0, 0.78, 0.34, 0.96),
		0.4,
		blast_radius * 1.1,
		0.28,
		true
	)
	spawn_vfx_burst(
		parent,
		"FireflyCounterRing",
		center + Vector3.UP * 0.1,
		create_vfx_atlas(3),
		Color(1.0, 0.78, 0.28, 0.88),
		0.32,
		blast_radius * 1.05,
		0.28,
		false
	)
	spawn_blast_sparks(parent, center + Vector3.UP * 0.45, COUNTER_SPARK_COUNT)


## Tạo một vòng chớp sáng additive ngắn rồi tự giải phóng.
static func spawn_vfx_burst(
	parent: Node,
	node_name: String,
	world_pos: Vector3,
	tex: Texture2D,
	tint: Color,
	start_scale: float,
	end_scale: float,
	duration_seconds: float,
	billboard: bool
) -> void:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = (
		BaseMaterial3D.BILLBOARD_ENABLED if billboard else BaseMaterial3D.BILLBOARD_DISABLED
	)
	if not billboard:
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED

	var burst := Sprite3D.new()
	burst.name = node_name
	burst.texture = tex
	burst.pixel_size = 0.0085
	burst.billboard = (
		BaseMaterial3D.BILLBOARD_ENABLED if billboard else BaseMaterial3D.BILLBOARD_DISABLED
	)
	if not billboard:
		burst.rotation.x = -PI * 0.5
	burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	burst.modulate = tint
	burst.scale = Vector3.ONE * start_scale
	burst.material_override = mat
	parent.add_child(burst)
	burst.global_position = world_pos

	var tween := burst.create_tween().set_parallel(true)
	tween.tween_property(burst, "scale", Vector3.ONE * end_scale, duration_seconds)
	tween.tween_property(burst, "modulate:a", 0.0, duration_seconds)
	tween.chain().tween_callback(burst.queue_free)


## Phóng cụm hạt sáng vàng cam từ tâm nổ bằng texture hạt độc lập.
static func spawn_blast_sparks(
	parent: Node, world_pos: Vector3, spark_count: int = BLAST_SPARK_COUNT
) -> void:
	var sparks := CPUParticles3D.new()
	sparks.name = "FireflyBlastSparks"
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sparks.amount = maxi(1, spark_count)
	sparks.lifetime = 0.72
	sparks.one_shot = true
	sparks.explosiveness = 0.95
	sparks.emitting = false
	sparks.local_coords = false
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 0.35
	sparks.direction = Vector3.UP
	sparks.spread = 95.0
	sparks.initial_velocity_min = 1.8
	sparks.initial_velocity_max = 4.4
	sparks.gravity = Vector3(0.0, 0.85, 0.0)
	sparks.damping_min = 1.6
	sparks.damping_max = 2.6
	sparks.scale_amount_min = 0.24
	sparks.scale_amount_max = 0.48
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(1.0, 0.98, 0.62, 0.98), Color(1.0, 0.62, 0.14, 0.0)])
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	sparks.color_ramp = grad
	sparks.mesh = POLLEN_FIELD_SCRIPT.create_spark_quad(Vector2(0.38, 0.38), true)
	parent.add_child(sparks)
	sparks.global_position = world_pos
	sparks.emitting = true
	var cleanup := sparks.create_tween()
	cleanup.tween_interval(0.9)
	cleanup.tween_callback(sparks.queue_free)


## Khởi tạo bóng tròn mềm dưới mặt đất giúp người chơi đọc vị trí trên không.
static func create_ground_shadow(parent: Node3D, ground_offset_y: float) -> Sprite3D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var center := Vector2(31.5, 31.5)
	for y in range(64):
		for x in range(64):
			var dist := Vector2(x, y).distance_to(center) / 30.0
			var alpha := clampf(1.0 - dist * dist, 0.0, 1.0) * 0.72
			img.set_pixel(x, y, Color(0.04, 0.06, 0.02, alpha))
	var shadow := Sprite3D.new()
	shadow.name = "GroundShadow"
	shadow.texture = ImageTexture.create_from_image(img)
	shadow.pixel_size = 0.024
	shadow.rotation.x = -PI * 0.5
	shadow.position = Vector3(0.0, ground_offset_y, 0.0)
	shadow.shaded = false
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(shadow)
	return shadow


## Tạo vòng corona báo hiệu pha gồng nổ trên không quanh thân Đom đóm.
static func create_air_charge_ring(vfx_anchor: Node3D) -> Sprite3D:
	var atlas := create_vfx_atlas(3)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.albedo_texture = atlas
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	var ring := Sprite3D.new()
	ring.name = "AirChargeCorona"
	ring.texture = atlas
	ring.pixel_size = 0.0058
	ring.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	ring.shaded = false
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = Vector3(0.0, 0.05, 0.0)
	ring.visible = false
	ring.material_override = mat
	vfx_anchor.add_child(ring)
	return ring


## Gắn cụm đèn OmniLight, hạt sáng bay quanh thân và shader phát sáng bụng Đom đóm.
static func setup_lantern_rig(
	vfx_anchor: Node3D, sprite: Sprite3D, rest_color: Color, rest_energy: float
) -> Dictionary:
	var glow_material := ShaderMaterial.new()
	glow_material.shader = GLOW_SHADER
	if is_instance_valid(sprite):
		sprite.material_overlay = glow_material

	var lantern_light := OmniLight3D.new()
	lantern_light.name = "FireflyLanternLight"
	lantern_light.light_color = rest_color
	lantern_light.light_energy = rest_energy
	lantern_light.omni_range = 3.4
	lantern_light.shadow_enabled = false
	lantern_light.position = Vector3(0.0, 0.45, 0.1)
	vfx_anchor.add_child(lantern_light)

	var ambient_motes := GPUParticles3D.new()
	ambient_motes.name = "FireflyAmbientMotes"
	ambient_motes.amount = 28
	ambient_motes.lifetime = 1.25
	ambient_motes.local_coords = true
	ambient_motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ambient_motes.visibility_aabb = AABB(Vector3(-2.5, -1.0, -2.5), Vector3(5.0, 4.0, 5.0))
	var mote_process := ParticleProcessMaterial.new()
	mote_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mote_process.emission_sphere_radius = 0.42
	mote_process.direction = Vector3.UP
	mote_process.spread = 45.0
	mote_process.initial_velocity_min = 0.08
	mote_process.initial_velocity_max = 0.28
	mote_process.gravity = Vector3(0.0, 0.16, 0.0)
	mote_process.scale_min = 0.45
	mote_process.scale_max = 1.0
	mote_process.color_ramp = POLLEN_FIELD_SCRIPT.create_fade_ramp_texture(
		Color(1.0, 0.96, 0.46, 0.9), Color(1.0, 0.72, 0.22, 0.0)
	)
	ambient_motes.process_material = mote_process
	ambient_motes.draw_pass_1 = POLLEN_FIELD_SCRIPT.create_spark_quad(Vector2(0.28, 0.28), true)
	ambient_motes.position = Vector3(0.0, 0.35, 0.0)
	vfx_anchor.add_child(ambient_motes)

	return {
		"glow_material": glow_material,
		"lantern_light": lantern_light,
		"ambient_motes": ambient_motes,
	}
