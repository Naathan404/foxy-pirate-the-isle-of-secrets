class_name MushroomEgg
extends EnemyBase
## Trứng Nấm (cây nấm con chưa tiến hóa): enemy đứng yên có thể bị tiêu diệt trực tiếp;
## nếu sống sót hết thời gian ủ mầm sẽ nở ra một Mushroom bình thường.

const ADULT_MUSHROOM_SCENE := preload("res://gameplay/enemies/mushroom/mushroom.tscn")
const SPORE_CLOUD_SCRIPT := preload("res://gameplay/enemies/mushroom/mushroom_spore_cloud.gd")
const EGG_GROUP := &"mushroom_eggs"
const SHADOW_RADIUS_METERS := 0.36
const SHADOW_OFFSET_Y := 0.02

@export_group("Mushroom Egg Incubation")
## Thời gian ủ mầm (s) trước khi Trứng Nấm nở thành Mushroom bình thường.
@export_range(1.5, 15.0, 0.25, "suffix:s") var hatch_duration_seconds: float = 5.5
## Quãng thời gian cuối (s) Trứng Nấm rung mạnh & phát sáng báo hiệu sắp nở.
@export_range(0.5, 5.0, 0.1, "suffix:s") var warning_window_seconds: float = 1.8
## Biên độ phồng nhịp tim khi Trứng Nấm đang ủ mầm.
@export_range(0.0, 0.3, 0.01) var wobble_scale_amplitude: float = 0.08

var _source_elite: MushroomEnemy
var _hatch_remaining: float = 5.5
var _incubation_elapsed: float = 0.0
var _hatched: bool = false
var _initialized_timer: bool = false
var _shadow_mesh: MeshInstance3D
var _aura_light: OmniLight3D


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	add_to_group(EGG_GROUP)
	if not _initialized_timer:
		_hatch_remaining = maxf(1.0, hatch_duration_seconds)
	_build_egg_accents()


func setup_spawned(source_elite: MushroomEnemy, hatch_seconds: float) -> void:
	_source_elite = source_elite
	hatch_duration_seconds = maxf(1.0, hatch_seconds)
	_hatch_remaining = hatch_duration_seconds
	_initialized_timer = true


func advance_incubation(step: float) -> void:
	if dead or _hatched:
		return
	var dt := maxf(0.0, step)
	_incubation_elapsed += dt
	_hatch_remaining = maxf(0.0, _hatch_remaining - dt)
	_update_incubation_visual()


func is_about_to_hatch() -> bool:
	return _hatch_remaining <= minf(warning_window_seconds, hatch_duration_seconds)


func is_ready_to_hatch() -> bool:
	return _hatch_remaining <= 0.0 and not dead and not _hatched


func reset_incubation_visual() -> void:
	if is_instance_valid(visual):
		visual.scale = Vector3.ONE
	if is_instance_valid(visual) and is_instance_valid(visual.sprite):
		visual.sprite.modulate = Color.WHITE


func hatch_into_mushroom() -> MushroomEnemy:
	if dead or _hatched or not is_inside_tree():
		return null
	_hatched = true
	var parent := get_parent()
	if not is_instance_valid(parent) or parent.is_queued_for_deletion():
		queue_free()
		return null
	var hatched := ADULT_MUSHROOM_SCENE.instantiate() as MushroomEnemy
	if hatched == null:
		queue_free()
		return null
	hatched.position = position
	hatched.show_debug_health = show_debug_health
	parent.add_child(hatched)
	hatched.global_position = global_position
	hatched.home_position = global_position
	if is_instance_valid(_source_elite) and _source_elite.has_method("register_spawned_minion"):
		_source_elite.call("register_spawned_minion", hatched)
	_spawn_burst_vfx(true)
	queue_free()
	return hatched


func die() -> void:
	if dead:
		return
	if not _hatched and is_inside_tree():
		_spawn_burst_vfx(false)
	super()


func _update_incubation_visual() -> void:
	var near_hatch := is_about_to_hatch()
	var tension := 1.0
	if near_hatch and warning_window_seconds > 0.01:
		tension = clampf(1.0 - _hatch_remaining / warning_window_seconds, 0.0, 1.0)
	var freq := lerpf(4.0, 14.0, tension if near_hatch else 0.0)
	var amp := wobble_scale_amplitude * (1.0 + tension * 0.9 if near_hatch else 0.55)
	var wave := sin(_incubation_elapsed * freq) * amp
	if is_instance_valid(visual):
		visual.scale = Vector3(1.0 - wave * 0.45, 1.0 + wave, 1.0 - wave * 0.45)
		if is_instance_valid(visual.sprite):
			var glow_mix := 0.5 + 0.5 * sin(_incubation_elapsed * 16.0)
			visual.sprite.modulate = (
				Color.WHITE.lerp(Color(0.86, 1.0, 0.65, 1.0), tension * glow_mix * 0.85)
				if near_hatch
				else Color.WHITE
			)
	if is_instance_valid(_aura_light):
		_aura_light.light_energy = 0.28 + (0.65 * tension if near_hatch else 0.0)


func _build_egg_accents() -> void:
	var shadow := SphereMesh.new()
	shadow.radius = SHADOW_RADIUS_METERS
	shadow.height = 0.01
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.06, 0.03, 0.1, 0.42)
	shadow.material = mat
	_shadow_mesh = MeshInstance3D.new()
	_shadow_mesh.name = "EggShadow"
	_shadow_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow_mesh.mesh = shadow
	_shadow_mesh.position = Vector3(0.0, SHADOW_OFFSET_Y, 0.0)
	add_child(_shadow_mesh)

	_aura_light = OmniLight3D.new()
	_aura_light.name = "EggGlowLight"
	_aura_light.light_color = Color(0.72, 1.0, 0.36)
	_aura_light.light_energy = 0.28
	_aura_light.omni_range = 1.6
	_aura_light.shadow_enabled = false
	_aura_light.position = Vector3(0.0, 0.55, 0.0)
	add_child(_aura_light)


func _spawn_burst_vfx(is_hatch: bool) -> void:
	if not is_inside_tree():
		return
	var parent := get_parent()
	if not is_instance_valid(parent) or parent.is_queued_for_deletion():
		return
	var burst := CPUParticles3D.new()
	burst.name = "MushroomEggHatchBurst" if is_hatch else "MushroomEggBreakBurst"
	burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	burst.amount = 22 if is_hatch else 16
	burst.lifetime = 0.55 if is_hatch else 0.45
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.emitting = false
	burst.local_coords = false
	burst.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	burst.emission_sphere_radius = 0.28
	burst.direction = Vector3.UP
	burst.spread = 80.0
	burst.initial_velocity_min = 1.6 if is_hatch else 1.2
	burst.initial_velocity_max = 3.4 if is_hatch else 2.6
	burst.gravity = Vector3(0.0, -2.2, 0.0)
	burst.scale_amount_min = 0.38
	burst.scale_amount_max = 0.85

	var grad := Gradient.new()
	var start_col := Color(0.72, 1.0, 0.42, 0.95) if is_hatch else Color(0.82, 0.56, 1.0, 0.9)
	grad.colors = PackedColorArray([start_col, Color(0.45, 0.22, 0.72, 0.0)])
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	burst.color_ramp = grad

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.albedo_texture = SPORE_CLOUD_SCRIPT._create_purple_spore_texture()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.44, 0.44)
	quad.material = mat
	burst.mesh = quad

	parent.add_child(burst)
	burst.global_position = global_position + Vector3.UP * 0.45
	burst.emitting = true
	var cleanup := burst.create_tween()
	cleanup.tween_interval(0.75)
	cleanup.tween_callback(burst.queue_free)
