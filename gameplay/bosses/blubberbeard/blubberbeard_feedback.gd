class_name BlubberbeardFeedback
extends Node
## Chỉ xử lý hiệu ứng hình ảnh và âm thanh; toàn bộ sát thương và nhịp đánh thuộc BlubberbeardBoss.

const EFFECTS = preload("res://gameplay/bosses/boss_effects.gd")
const EXPLOSION = preload("res://gameplay/bosses/blubberbeard/powder_explosion_vfx.tscn")
const MOVE_DUST_SHEET = preload("res://assets/sprites/bosses/blubberbeard/boss_move_dust.png")
const ASH_SCORCH_TEXTURE = preload("res://assets/sprites/bosses/blubberbeard/barrel_ash_scorch.png")
const PROPS_SHEET = preload("res://assets/sprites/bosses/blubberbeard/anchor_whirlwind_props.png")
const BOOM = preload("res://gameplay/bosses/blubberbeard/boss_explosion.wav")
const CHARGE = preload("res://gameplay/bosses/blubberbeard/boss_charge.wav")
const ROAR = preload("res://gameplay/bosses/blubberbeard/boss_roar.wav")

const WALL_SHOCKWAVE_DURATION := 0.4
const WALL_SHOCKWAVE_STRENGTH := 0.016
const WALL_SHOCKWAVE_COLOR := Color("ff9c46")
const WALL_SHOCKWAVE_RADIUS_PIXELS := 190.0
const DEATH_SHOCKWAVE_DURATION := 0.6
const DEATH_SHOCKWAVE_STRENGTH := 0.022
const DEATH_SHOCKWAVE_COLOR := Color("ffb25f")
const DEATH_SHOCKWAVE_RADIUS_PIXELS := 240.0
const DEATH_SHOCKWAVE_HEIGHT := 2.0

@export_range(0.0, 2.0, 0.1) var intensity: float = 1.0
@export_range(30.0, 75.0, 1.0, "degrees") var fight_camera_fov: float = 45.0

var boss: BossBase
var visual: BlubberbeardVisual
var aura: CPUParticles3D
var flash: ColorRect
var _flash_tween: Tween
var _trail_timer: float = 0.0
var _stomp_timer: float = 0.0
var _camera: Camera3D
var _camera_fov: float = 0.0
var _camera_tween: Tween
var _slam_warning: Node3D
var _slam_warning_material: StandardMaterial3D


func setup(owner_boss: BossBase, boss_visual: BlubberbeardVisual) -> void:
	boss = owner_boss
	visual = boss_visual
	_create_aura()
	_create_screen_flash()


func fight_started() -> void:
	_begin_camera()
	_play(ROAR, boss.global_position, -9.0, 0.85)
	EFFECTS.shockwave(boss.get_parent(), boss.global_position, 4.0, Color(1.0, 0.3, 0.08, 0.75))


func charge_start() -> void:
	_trail_timer = 0.0
	_stomp_timer = 0.0
	_play(CHARGE, boss.global_position, -7.0, 0.85)
	_shake(8.0, 0.2)
	var flat := Vector3(boss.velocity.x, 0.0, boss.velocity.z)
	for offset_angle in [-0.45, 0.45]:
		var dir := (flat.normalized() if not flat.is_zero_approx() else Vector3.BACK).rotated(
			Vector3.UP, offset_angle
		)
		spawn_move_dust(boss.global_position - dir * 0.9, dir, true)
	EFFECTS.shockwave(boss.get_parent(), boss.global_position, 3.2, Color(1.0, 0.45, 0.1, 0.8))


func charge_tick(delta: float) -> void:
	_trail_timer -= delta
	_stomp_timer -= delta
	if _trail_timer <= 0.0:
		_trail_timer = 0.09
		_spawn_afterimage()
		var flat := Vector3(boss.velocity.x, 0.0, boss.velocity.z)
		var heading := flat.normalized() if not flat.is_zero_approx() else Vector3.BACK
		spawn_move_dust(boss.global_position - heading * 1.1, heading, true)
	if _stomp_timer <= 0.0:
		_stomp_timer = 0.18
		_shake(4.5, 0.13)


func aoe_hit(target: Node) -> void:
	if not is_instance_valid(target) or not target is Node3D:
		return
	var impact := (target as Node3D).global_position + Vector3.UP
	EFFECTS.burst(boss.get_parent(), impact, Color(1, 0.65, 0.18), 28, 0.4, 6.5)
	_shake(8.5, 0.18)
	_screen_flash(Color(1.0, 0.26, 0.05), 0.07, 0.14)


func barrel_explosion(at: Vector3, radius: float) -> void:
	_spawn_explosion(at, radius / 2.5)
	spawn_barrel_ash(at, radius)
	_play(BOOM, at, -5.0, randf_range(0.92, 1.08))
	_shake(12.0, 0.3)
	_screen_flash(Color(1.0, 0.45, 0.08), 0.07, 0.18)
	EFFECTS.shockwave(boss.get_parent(), at, radius * 1.4, Color(1.0, 0.65, 0.12, 0.95))
	EFFECTS.burst(boss.get_parent(), at + Vector3.UP, Color(1.0, 0.55, 0.12), 54, 0.8, 8.0)


func spikes_release() -> void:
	_play(CHARGE, boss.global_position, -7.0, 1.5)
	_shake(7.0, 0.18)
	EFFECTS.shockwave(boss.get_parent(), boss.global_position, 5.0, Color(1.0, 0.25, 0.08, 0.9))
	EFFECTS.burst(
		boss.get_parent(),
		boss.global_position + Vector3.UP * 2.0,
		Color(1.0, 0.5, 0.12),
		48,
		2.0,
		7.0
	)


func anchor_slam(at: Vector3, radius: float) -> void:
	_play(BOOM, at, -6.0, 0.78)
	_shake(11.0, 0.25)
	_screen_flash(Color(1.0, 0.35, 0.08), 0.09, 0.18)
	get_node("/root/ShockwaveController").request_world(
		at + Vector3.UP * 0.4,
		WALL_SHOCKWAVE_DURATION,
		WALL_SHOCKWAVE_STRENGTH * intensity,
		WALL_SHOCKWAVE_COLOR,
		WALL_SHOCKWAVE_RADIUS_PIXELS
	)
	for index in 4:
		var angle := TAU * float(index) / 4.0 + 0.35
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		spawn_move_dust(at + dir * 0.6, dir, true)
	EFFECTS.shockwave(boss.get_parent(), at, radius * 1.15, Color(1.0, 0.48, 0.12, 0.92))
	EFFECTS.burst(boss.get_parent(), at + Vector3.UP * 0.5, Color(1.0, 0.55, 0.18), 44, 1.4, 7.5)


func emit_skill_cue(
	cue: StringName, at: Vector3, radius: float = 0.0, target_node: Node = null
) -> void:
	match cue:
		&"skydive_launch":
			_cue_skydive_launch(at)
		&"skydive_lock":
			_play(CHARGE, at, -9.0, 1.35)
			_shake(4.0, 0.12)
		&"skydive_slam":
			_cue_skydive_slam(at, radius)
		&"whirlwind_windup":
			_play(ROAR, at, -8.0, 0.85)
			_shake(5.0, 0.14)
		&"whirlwind_hit":
			_cue_whirlwind_hit(target_node)
		&"venom_spit":
			_cue_venom_spit(at)
		&"venom_splash":
			_cue_venom_splash(at, radius)
		&"spiky_counter_shock":
			_cue_counter_shock(at)


func whirlwind_spin_tick(delta: float, at: Vector3) -> void:
	_stomp_timer -= delta
	if _stomp_timer <= 0.0:
		_stomp_timer = 0.2
		_play(CHARGE, at, -10.0, 1.2)
		_shake(4.5, 0.12)
		var jitter := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
		spawn_move_dust(at + jitter, Vector3.BACK, true)


func skydive_flight_tick(delta: float, airborne_height: float, heading: Vector3) -> void:
	_trail_timer -= delta
	if _trail_timer > 0.0:
		return
	_trail_timer = 0.085
	_spawn_afterimage()
	var flat := Vector3(heading.x, 0.0, heading.z)
	var dir := flat.normalized() if not flat.is_zero_approx() else Vector3.BACK
	var air_pos := (
		boss.global_position - dir * 0.75 + Vector3.UP * maxf(0.0, airborne_height - 0.15)
	)
	spawn_move_dust(air_pos, dir, true)


func phase_changed() -> void:
	aura.emitting = true
	_play(ROAR, boss.global_position, -5.0, 0.7)
	_shake(13.0, 0.3)
	_screen_flash(Color(0.8, 0.03, 0.03), 0.2, 0.35)
	EFFECTS.shockwave(boss.get_parent(), boss.global_position, 6.0, Color(1.0, 0.08, 0.03, 0.95))
	EFFECTS.burst(
		boss.get_parent(),
		boss.global_position + Vector3.UP * 2.0,
		Color(1.0, 0.2, 0.05),
		64,
		2.0,
		8.0
	)


func death() -> void:
	aura.emitting = false
	_restore_camera(true)
	_play(BOOM, boss.global_position, -5.0, 0.7)
	_shake(14.0, 0.3)
	_screen_flash(Color(1.0, 0.35, 0.08), 0.18, 0.3)
	get_node("/root/ShockwaveController").request_world(
		boss.global_position + Vector3.UP * DEATH_SHOCKWAVE_HEIGHT,
		DEATH_SHOCKWAVE_DURATION,
		DEATH_SHOCKWAVE_STRENGTH * intensity,
		DEATH_SHOCKWAVE_COLOR,
		DEATH_SHOCKWAVE_RADIUS_PIXELS
	)
	_spawn_explosion(boss.global_position, 1.5)
	EFFECTS.shockwave(boss.get_parent(), boss.global_position, 7.0, Color(1.0, 0.55, 0.12, 0.95))
	EFFECTS.burst(
		boss.get_parent(),
		boss.global_position + Vector3.UP * 2.0,
		Color(1.0, 0.48, 0.1),
		72,
		2.0,
		9.0
	)


func spawn_move_dust(at: Vector3, heading: Vector3, heavy: bool = false) -> void:
	if not is_instance_valid(boss) or not is_instance_valid(boss.get_parent()):
		return
	var parent := boss.get_parent()
	if parent.is_queued_for_deletion():
		return
	var puff := Sprite3D.new()
	puff.name = "BossMoveDustPuff"
	puff.texture = MOVE_DUST_SHEET
	puff.hframes = 4
	puff.vframes = 1
	puff.frame = 0
	puff.pixel_size = 0.013 if heavy else 0.0115
	puff.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	puff.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	puff.render_priority = 2
	puff.sorting_offset = 1.5
	puff.flip_h = randf() < 0.5
	puff.modulate = Color(1.0, 0.96, 0.88, 0.96 if heavy else 0.92)
	parent.add_child(puff)
	var drift_dir := Vector3(heading.x, 0.0, heading.z)
	drift_dir = drift_dir.normalized() if not drift_dir.is_zero_approx() else Vector3.BACK
	var jitter := Vector3(randf_range(-0.3, 0.3), 0.0, randf_range(-0.3, 0.3))
	puff.global_position = at + jitter + Vector3.UP * (0.95 if heavy else 0.85)
	puff.scale = Vector3.ONE * (1.05 if heavy else 0.95)
	var life := 0.55 if heavy else 0.48
	var target_pos := (
		puff.global_position
		- drift_dir * (2.0 if heavy else 1.2)
		+ Vector3.UP * (1.25 if heavy else 0.95)
	)
	var tween := puff.create_tween().set_parallel(true)
	tween.tween_property(puff, "global_position", target_pos, life).set_ease(Tween.EASE_OUT)
	tween.tween_property(puff, "scale", Vector3.ONE * (1.75 if heavy else 1.55), life).set_ease(
		Tween.EASE_OUT
	)
	tween.tween_property(puff, "modulate:a", 0.0, life).set_ease(Tween.EASE_IN)
	tween.tween_method(
		func(step: float) -> void:
			if is_instance_valid(puff):
				puff.frame = mini(3, int(step * 4.0)),
		0.0,
		0.99,
		life
	)
	tween.chain().tween_callback(puff.queue_free)


func spawn_barrel_ash(at: Vector3, radius: float) -> void:
	_spawn_ground_decal("BarrelAshScorch", ASH_SCORCH_TEXTURE, at, radius * 2.3, 5.5, -1)


func create_dust_emitter() -> CPUParticles3D:
	var emitter := CPUParticles3D.new()
	emitter.name = "ChargeDust"
	emitter.emitting = false
	emitter.amount = 48
	emitter.lifetime = 0.5
	emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	emitter.emission_box_extents = Vector3(1.1, 0.18, 1.1)
	emitter.local_coords = false
	emitter.direction = Vector3.UP
	emitter.spread = 75.0
	emitter.initial_velocity_min = 0.8
	emitter.initial_velocity_max = 3.2
	emitter.gravity = Vector3(0, -1.6, 0)
	emitter.scale_amount_min = 0.85
	emitter.scale_amount_max = 1.45
	emitter.color = Color(1.0, 0.96, 0.88, 0.92)
	emitter.anim_speed_min = 1.0
	emitter.anim_speed_max = 1.2
	emitter.sorting_offset = 1.0
	var mesh := QuadMesh.new()
	mesh.size = Vector2(1.25, 1.25)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.render_priority = 1
	material.albedo_texture = MOVE_DUST_SHEET
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.particles_anim_h_frames = 4
	material.particles_anim_v_frames = 1
	material.particles_anim_loop = false
	mesh.material = material
	emitter.mesh = mesh
	boss.add_child(emitter)
	emitter.position.y = 0.55
	return emitter


func create_slam_warning(base_radius: float) -> Node3D:
	var warning := Node3D.new()
	warning.name = "AnchorSlamWarning"
	warning.top_level = true
	warning.visible = false
	var disc := MeshInstance3D.new()
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = base_radius
	disc_mesh.bottom_radius = base_radius
	disc_mesh.height = 0.02
	disc.mesh = disc_mesh
	var disc_mat := StandardMaterial3D.new()
	disc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc_mat.albedo_color = Color(1.0, 0.2, 0.04, 0.16)
	disc.material_override = disc_mat
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	warning.add_child(disc)
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = maxf(0.05, base_radius - 0.12)
	ring_mesh.outer_radius = base_radius
	ring.mesh = ring_mesh
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(1.0, 0.28, 0.05)
	ring.material_override = ring_mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position.y = 0.02
	warning.add_child(ring)
	boss.add_child(warning)
	_slam_warning = warning
	_slam_warning_material = disc_mat
	return warning


func show_slam_warning(
	at: Vector3, ground_y: float, radius: float, base_radius: float, ring_color: Color
) -> void:
	if not is_instance_valid(_slam_warning):
		return
	var scale_xz := radius / maxf(0.1, base_radius)
	_slam_warning.global_position = Vector3(at.x, ground_y + 0.04, at.z)
	_slam_warning.scale = Vector3(scale_xz, 1.0, scale_xz)
	if is_instance_valid(_slam_warning_material):
		_slam_warning_material.albedo_color = Color(ring_color.r, ring_color.g, ring_color.b, 0.18)
	_slam_warning.visible = true


func update_slam_warning_alpha(alpha_val: float) -> void:
	if is_instance_valid(_slam_warning_material):
		_slam_warning_material.albedo_color.a = alpha_val


func hide_slam_warning() -> void:
	if is_instance_valid(_slam_warning):
		_slam_warning.visible = false


func _cue_skydive_launch(at: Vector3) -> void:
	_trail_timer = 0.0
	_play(ROAR, at, -7.0, 1.12)
	_shake(5.5, 0.14)
	EFFECTS.shockwave(boss.get_parent(), at, 2.5, Color(0.75, 0.92, 1.0, 0.72))


func _cue_skydive_slam(at: Vector3, radius: float) -> void:
	_spawn_ground_decal("SkydiveCraterDecal", PROPS_SHEET, at, radius * 2.15, 5.0, 6)
	_play(BOOM, at, -4.5, 0.72)
	_shake(13.0, 0.3)
	_screen_flash(Color(1.0, 0.32, 0.06), 0.11, 0.22)
	get_node("/root/ShockwaveController").request_world(
		at + Vector3.UP * 0.4,
		WALL_SHOCKWAVE_DURATION,
		WALL_SHOCKWAVE_STRENGTH * intensity * 1.2,
		WALL_SHOCKWAVE_COLOR,
		WALL_SHOCKWAVE_RADIUS_PIXELS * 1.15
	)
	for index in 5:
		var angle := TAU * float(index) / 5.0
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		spawn_move_dust(at + dir * 0.85, dir, true)
	EFFECTS.shockwave(boss.get_parent(), at, radius * 1.3, Color(1.0, 0.46, 0.12, 0.95))
	EFFECTS.burst(boss.get_parent(), at + Vector3.UP * 0.5, Color(0.95, 0.62, 0.25), 52, 1.6, 8.5)


func _cue_whirlwind_hit(target_node: Node) -> void:
	if not is_instance_valid(target_node) or not target_node is Node3D:
		return
	var impact := (target_node as Node3D).global_position + Vector3.UP
	EFFECTS.burst(boss.get_parent(), impact, Color(0.3, 0.95, 0.9), 34, 0.5, 7.5)
	_shake(11.0, 0.24)
	_screen_flash(Color(0.25, 0.88, 0.95), 0.09, 0.16)


func _cue_venom_spit(at: Vector3) -> void:
	_play(CHARGE, at, -7.5, 1.38)
	_shake(5.5, 0.14)
	EFFECTS.burst(boss.get_parent(), at + Vector3.UP * 2.0, Color(0.42, 0.95, 0.25), 24, 0.6, 5.0)


func _cue_venom_splash(at: Vector3, radius: float) -> void:
	EFFECTS.shockwave(boss.get_parent(), at, radius * 0.95, Color(0.45, 0.95, 0.25, 0.78))
	EFFECTS.burst(boss.get_parent(), at + Vector3.UP * 0.4, Color(0.55, 0.25, 0.85), 22, 0.5, 4.5)


func _cue_counter_shock(at: Vector3) -> void:
	_play(ROAR, at, -6.5, 1.18)
	_shake(6.5, 0.16)
	EFFECTS.shockwave(boss.get_parent(), at, 3.4, Color(1.0, 0.42, 0.12, 0.85))
	EFFECTS.burst(boss.get_parent(), at + Vector3.UP * 1.5, Color(1.0, 0.58, 0.18), 32, 1.1, 6.0)


func _spawn_ground_decal(
	node_name: String,
	tex: Texture2D,
	at: Vector3,
	width_meters: float,
	hold_seconds: float,
	sheet_frame: int
) -> void:
	if not is_instance_valid(boss) or not is_instance_valid(boss.get_parent()):
		return
	var parent := boss.get_parent()
	if parent.is_queued_for_deletion():
		return
	var decal := Sprite3D.new()
	decal.name = node_name
	decal.texture = tex
	if sheet_frame >= 0:
		decal.hframes = 4
		decal.vframes = 2
		decal.frame = sheet_frame
		decal.pixel_size = width_meters / 360.0
	else:
		decal.pixel_size = 0.016 * maxf(0.75, width_meters / 5.75)
	decal.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	decal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	decal.modulate = Color(1.0, 1.0, 1.0, 0.94)
	parent.add_child(decal)
	decal.global_position = Vector3(at.x, at.y + 0.03, at.z)
	decal.rotation = Vector3(-PI * 0.5, randf() * TAU, 0.0)
	var tween := decal.create_tween()
	tween.tween_interval(hold_seconds)
	tween.tween_property(decal, "modulate:a", 0.0, 1.5).set_ease(Tween.EASE_IN)
	tween.tween_callback(decal.queue_free)


func _spawn_explosion(at: Vector3, size: float) -> void:
	var effect := EXPLOSION.instantiate() as Node3D
	boss.get_parent().add_child(effect)
	effect.global_position = at
	effect.scale = Vector3.ONE * size


func _spawn_afterimage() -> void:
	if not is_instance_valid(visual):
		return
	var ghost := Sprite3D.new()
	ghost.name = "BossChargeAfterimage"
	ghost.texture = visual.texture
	ghost.hframes = visual.hframes
	ghost.vframes = visual.vframes
	ghost.frame = visual.frame
	ghost.flip_h = visual.flip_h
	ghost.pixel_size = visual.pixel_size
	ghost.billboard = visual.billboard
	ghost.texture_filter = visual.texture_filter
	ghost.modulate = Color(1.0, 0.28, 0.08, 0.45)
	boss.get_parent().add_child(ghost)
	ghost.global_transform = visual.global_transform
	var tween := ghost.create_tween().set_parallel(true)
	tween.tween_property(ghost, "modulate:a", 0.0, 0.3)
	tween.tween_property(ghost, "scale", ghost.scale * 1.1, 0.3)
	tween.chain().tween_callback(ghost.queue_free)


func _play(stream: AudioStream, at: Vector3, volume: float, pitch: float) -> void:
	get_node("/root/AudioManager").play_sfx_3d(stream, at, volume, pitch)


func _shake(strength: float, duration: float) -> void:
	get_node("/root/ScreenShakeController").request(strength * intensity, duration)


func _screen_flash(color: Color, opacity: float, duration: float) -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	flash.color = Color(color.r, color.g, color.b, opacity * intensity)
	_flash_tween = create_tween()
	_flash_tween.tween_property(flash, "color:a", 0.0, duration)


func _begin_camera() -> void:
	var camera := boss.get_viewport().get_camera_3d()
	if camera == null or camera.projection != Camera3D.PROJECTION_PERSPECTIVE:
		return
	_camera = camera
	_camera_fov = camera.fov
	_camera_tween = camera.create_tween()
	_camera_tween.tween_property(camera, "fov", maxf(camera.fov, fight_camera_fov), 0.6).set_trans(
		Tween.TRANS_SINE
	)


func _restore_camera(animated: bool) -> void:
	if not is_instance_valid(_camera):
		return
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()
	if animated and _camera.is_inside_tree():
		_camera_tween = _camera.create_tween()
		_camera_tween.tween_property(_camera, "fov", _camera_fov, 0.45).set_trans(Tween.TRANS_SINE)
	else:
		_camera.fov = _camera_fov


func _exit_tree() -> void:
	_restore_camera(false)


func _create_screen_flash() -> void:
	var layer := CanvasLayer.new()
	layer.name = "BossImpactFlash"
	layer.layer = 9
	boss.add_child(layer)
	flash = ColorRect.new()
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color.TRANSPARENT
	layer.add_child(flash)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _create_aura() -> void:
	aura = CPUParticles3D.new()
	aura.name = "EnragedEmbers"
	aura.emitting = false
	aura.amount = 42
	aura.lifetime = 1.0
	aura.local_coords = false
	aura.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	aura.emission_sphere_radius = 1.25
	aura.direction = Vector3.UP
	aura.spread = 30.0
	aura.initial_velocity_min = 1.0
	aura.initial_velocity_max = 3.0
	aura.gravity = Vector3(0, 1.5, 0)
	aura.scale_amount_min = 0.2
	aura.scale_amount_max = 0.5
	aura.color = Color(1.0, 0.18, 0.04, 0.8)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.15, 0.15, 0.15)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	aura.mesh = mesh
	boss.add_child(aura)
	aura.position.y = 1.45
