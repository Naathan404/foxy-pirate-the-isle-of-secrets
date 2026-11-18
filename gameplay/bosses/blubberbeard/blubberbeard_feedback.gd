class_name BlubberbeardFeedback
extends Node
## Visual and audio feedback only; the behavior owns all damage and timing.

const EFFECTS = preload("res://gameplay/bosses/boss_effects.gd")
const EXPLOSION = preload("res://gameplay/bosses/blubberbeard/powder_explosion_vfx.tscn")
const MOVE_DUST_SHEET = preload("res://assets/sprites/bosses/blubberbeard/boss_move_dust.png")
const ASH_SCORCH_TEXTURE = preload("res://assets/sprites/bosses/blubberbeard/barrel_ash_scorch.png")
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
	EFFECTS.burst(
		boss.get_parent(), boss.global_position + Vector3.UP, Color(1, 0.45, 0.1), 30, 1.4, 5.0
	)


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


func charge_end(wall_impact: bool) -> void:
	_shake(11.0 if wall_impact else 8.0, 0.24)
	if wall_impact:
		get_node("/root/ShockwaveController").request_world(
			boss.global_position + Vector3.UP,
			WALL_SHOCKWAVE_DURATION,
			WALL_SHOCKWAVE_STRENGTH * intensity,
			WALL_SHOCKWAVE_COLOR,
			WALL_SHOCKWAVE_RADIUS_PIXELS
		)
	_play(BOOM, boss.global_position, -12.0, 1.25)
	for index in 3:
		var angle := (index - 1) * 0.55
		var dir := Vector3.BACK.rotated(Vector3.UP, angle)
		spawn_move_dust(boss.global_position + dir * 0.8, dir, true)
	EFFECTS.shockwave(boss.get_parent(), boss.global_position, 4.0, Color(1, 0.45, 0.15, 0.8))
	EFFECTS.burst(
		boss.get_parent(),
		boss.global_position + Vector3.UP * 0.5,
		Color(0.9, 0.62, 0.33),
		36,
		1.5,
		5.0
	)


func charge_hit(target: Node) -> void:
	if not is_instance_valid(target) or not target is Node3D:
		return
	var impact := (target as Node3D).global_position + Vector3.UP
	EFFECTS.burst(boss.get_parent(), impact, Color(1, 0.7, 0.22), 32, 0.4, 7.0)
	_shake(10.0, 0.22)
	_screen_flash(Color(1.0, 0.22, 0.04), 0.08, 0.16)
	get_node("/root/HitstopController").request_local(boss, target as Node3D, 0.055)


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


func evade_land() -> void:
	_shake(5.0, 0.16)
	visual.impact(0.12, 0.18)


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
	puff.pixel_size = 0.016 if heavy else 0.0145
	puff.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	puff.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	puff.render_priority = 2
	puff.sorting_offset = 1.5
	puff.flip_h = randf() < 0.5
	puff.modulate = Color(1.0, 0.96, 0.88, 0.96 if heavy else 0.92)
	parent.add_child(puff)
	var drift_dir := Vector3(heading.x, 0.0, heading.z)
	if drift_dir.is_zero_approx():
		drift_dir = Vector3.BACK
	drift_dir = drift_dir.normalized()
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
	if not is_instance_valid(boss) or not is_instance_valid(boss.get_parent()):
		return
	var parent := boss.get_parent()
	if parent.is_queued_for_deletion():
		return
	var ash := Sprite3D.new()
	ash.name = "BarrelAshScorch"
	ash.texture = ASH_SCORCH_TEXTURE
	ash.pixel_size = 0.016 * maxf(0.75, radius / 2.5)
	ash.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ash.modulate = Color(1.0, 1.0, 1.0, 0.92)
	parent.add_child(ash)
	ash.global_position = Vector3(at.x, at.y + 0.03, at.z)
	ash.rotation = Vector3(-PI * 0.5, randf() * TAU, 0.0)
	var tween := ash.create_tween()
	tween.tween_interval(5.5)
	tween.tween_property(ash, "modulate:a", 0.0, 1.5).set_ease(Tween.EASE_IN)
	tween.tween_callback(ash.queue_free)


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
	aura.emission_sphere_radius = 2.0
	aura.direction = Vector3.UP
	aura.spread = 30.0
	aura.initial_velocity_min = 1.0
	aura.initial_velocity_max = 3.0
	aura.gravity = Vector3(0, 1.5, 0)
	aura.scale_amount_min = 0.25
	aura.scale_amount_max = 0.7
	aura.color = Color(1.0, 0.18, 0.04, 0.8)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.2, 0.2, 0.2)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	aura.mesh = mesh
	boss.add_child(aura)
	aura.position.y = 2.5
