class_name MushroomGreatSpore
extends Node3D
## Đại Bào Tử của EliteMushroom: cụm nhiều hạt sáng hội tụ bay vồng rộng và cao trên không,
## để lại vệt bụi phấn nhấp nháy tự do dọc quỹ đạo trước khi đáp xuống thành bãi độc hoặc Trứng Nấm.

signal landed(landing_position: Vector3, outcome: int, spawned_node: Node)

enum OutcomeKind { SPORE_CLOUD, MUSHROOM_EGG }
enum FlightPhase { DELAY, LAUNCH, HOVER, LANDING, FADE }

const SPORE_CLOUD_SCRIPT := preload("res://gameplay/enemies/mushroom/mushroom_spore_cloud.gd")
const SPARK_MOTE_TEXTURE := preload("res://assets/sprites/enemies/firefly/firefly_spark_mote.png")
const EGG_SCENE := preload("res://gameplay/enemies/mushroom/mushroom_egg.tscn")
const GREAT_SPORE_GROUP := &"mushroom_great_spore"
const LAUNCH_SECONDS := 0.95
const FADE_CLEANUP_SECONDS := 1.85
const LAUNCH_REACH_FRACTION := 0.68
const LAUNCH_APEX_LIFT_METERS := 1.45
const SHADOW_BASE_RADIUS := 0.56
const SHADOW_MIN_SCALE := 0.34
const SHADOW_GROUND_OFFSET_Y := 0.03
const HOVER_BOB_AMP_METERS := 0.52
const HOVER_BOB_FREQ := 3.8
const HOVER_WEAVE_AMP_METERS := 2.35
const FLUTTER_CYCLES := 2.5
const FLUTTER_HEIGHT_METERS := 0.24
const CORE_PARTICLE_COUNT := 48
const SPARK_PARTICLE_COUNT := 28
const TRAIL_BLINK_PARTICLE_COUNT := 190
const TRAIL_MIST_PARTICLE_COUNT := 36
const CLOUD_SPAWN_RAMP_CAP_SECONDS := 0.24

var _owner_ref: WeakRef
var _fallback_parent_ref: WeakRef
var _outcome: OutcomeKind = OutcomeKind.SPORE_CLOUD
var _phase: FlightPhase = FlightPhase.LAUNCH
var _start_position: Vector3 = Vector3.ZERO
var _hover_origin_xz: Vector3 = Vector3.ZERO
var _landing_position: Vector3 = Vector3.ZERO
var _hover_altitude: float = 4.3
var _hover_seconds: float = 2.6
var _land_seconds: float = 0.72
var _launch_delay_seconds: float = 0.0
var _cloud_radius: float = 2.6
var _cloud_duration: float = 3.5
var _cloud_ramp: float = 0.8
var _poison_interval: float = 0.85
var _poison_damage: float = 0.5
var _egg_hatch_seconds: float = 5.5
var _weave_sign: float = 1.0
var _weave_phase: float = 0.0

var _elapsed: float = 0.0
var _total_clock: float = 0.0
var _land_start_altitude: float = 4.3
var _finished: bool = false
var _emitters_started: bool = false

var _glow_light: OmniLight3D
var _shadow_mesh: MeshInstance3D
var _emitters: Array[GPUParticles3D] = []


func setup(config: Dictionary) -> void:
	var owner_raw: Variant = config.get("owner", null)
	_owner_ref = (
		weakref(owner_raw)
		if owner_raw != null and is_instance_valid(owner_raw) and owner_raw is MushroomEnemy
		else null
	)
	var live_owner := _resolve_owner_elite()
	if live_owner != null and is_instance_valid(live_owner.get_parent()):
		_fallback_parent_ref = weakref(live_owner.get_parent())
	_outcome = int(config.get("outcome", OutcomeKind.SPORE_CLOUD)) as OutcomeKind
	_start_position = config.get("start_pos", Vector3.ZERO) as Vector3
	_landing_position = config.get("landing_pos", _start_position) as Vector3
	_hover_altitude = maxf(1.8, float(config.get("hover_altitude", 4.3)))
	_hover_seconds = maxf(0.8, float(config.get("hover_seconds", 2.6)))
	_land_seconds = maxf(0.25, float(config.get("land_seconds", 0.72)))
	_launch_delay_seconds = maxf(0.0, float(config.get("launch_delay", 0.0)))
	_cloud_radius = maxf(0.6, float(config.get("cloud_radius", 2.6)))
	_cloud_duration = maxf(0.5, float(config.get("cloud_duration", 3.5)))
	_cloud_ramp = maxf(0.05, float(config.get("cloud_ramp", 0.8)))
	_poison_interval = maxf(0.15, float(config.get("poison_interval", 0.85)))
	_poison_damage = maxf(0.0, float(config.get("poison_damage", 0.5)))
	_egg_hatch_seconds = maxf(1.5, float(config.get("egg_hatch_seconds", 5.5)))
	_weave_sign = -1.0 if randf() < 0.5 else 1.0
	_weave_phase = randf_range(0.0, TAU)
	var mid_lerp := _start_position.lerp(_landing_position, LAUNCH_REACH_FRACTION)
	_hover_origin_xz = Vector3(mid_lerp.x, _landing_position.y, mid_lerp.z)


func _ready() -> void:
	add_to_group(GREAT_SPORE_GROUP)
	_build_visuals()
	global_position = _start_position
	if _launch_delay_seconds > 0.005:
		_phase = FlightPhase.DELAY
		_set_active_visuals(false)
	else:
		_phase = FlightPhase.LAUNCH
		_set_active_visuals(true)
	_update_visual_animation(0.0)


func _physics_process(delta: float) -> void:
	var step := maxf(0.0, delta)
	_elapsed += step
	_total_clock += step
	match _phase:
		FlightPhase.DELAY:
			_step_delay()
		FlightPhase.LAUNCH:
			_step_launch()
		FlightPhase.HOVER:
			_step_hover()
		FlightPhase.LANDING:
			_step_landing()
		FlightPhase.FADE:
			_step_fade()
			return
	_update_visual_animation(step)


func is_finished() -> bool:
	return _finished


func get_outcome() -> OutcomeKind:
	return _outcome


func get_landing_position() -> Vector3:
	return _landing_position


func get_flight_phase() -> FlightPhase:
	return _phase


func _step_delay() -> void:
	var live_owner := _resolve_owner_elite()
	if live_owner != null:
		global_position = live_owner.global_position + Vector3.UP * 1.65
	if _elapsed >= _launch_delay_seconds:
		_start_position = global_position
		var mid_lerp := _start_position.lerp(_landing_position, LAUNCH_REACH_FRACTION)
		_hover_origin_xz = Vector3(mid_lerp.x, _landing_position.y, mid_lerp.z)
		_elapsed = 0.0
		_phase = FlightPhase.LAUNCH
		_set_active_visuals(true)


func _step_launch() -> void:
	var t := clampf(_elapsed / LAUNCH_SECONDS, 0.0, 1.0)
	var ease_out := 1.0 - pow(1.0 - t, 2.2)
	var travel := Vector3(
		_hover_origin_xz.x - _start_position.x, 0.0, _hover_origin_xz.z - _start_position.z
	)
	var perp := (
		Vector3(-travel.z, 0.0, travel.x).normalized()
		if not travel.is_zero_approx()
		else Vector3.RIGHT
	)
	var curve_sway := sin(t * PI) * (HOVER_WEAVE_AMP_METERS * 0.75) * _weave_sign
	var xz := _start_position.lerp(_hover_origin_xz, ease_out) + perp * curve_sway
	var ground_y := lerpf(_start_position.y, _landing_position.y, ease_out)
	var target_y := _landing_position.y + _hover_altitude
	var y := lerpf(_start_position.y, target_y, ease_out) + LAUNCH_APEX_LIFT_METERS * sin(t * PI)
	global_position = Vector3(xz.x, maxf(ground_y + 0.3, y), xz.z)
	if t >= 1.0:
		_phase = FlightPhase.HOVER
		_elapsed = 0.0


func _step_hover() -> void:
	var t := clampf(_elapsed / _hover_seconds, 0.0, 1.0)
	var smooth := t * t * (3.0 - 2.0 * t)
	var base_xz := _hover_origin_xz.lerp(_landing_position, smooth)
	var travel := Vector3(
		_landing_position.x - _hover_origin_xz.x, 0.0, _landing_position.z - _hover_origin_xz.z
	)
	var perp := (
		Vector3(-travel.z, 0.0, travel.x).normalized()
		if not travel.is_zero_approx()
		else Vector3.RIGHT
	)
	var drift_forward := (
		sin(_total_clock * 1.65 + _weave_phase * 1.4)
		* (1.0 - smooth)
		* (HOVER_WEAVE_AMP_METERS * 0.55)
	)
	var weave := (
		(sin(_total_clock * 2.2 + _weave_phase) + 0.38 * cos(_total_clock * 3.5 + _weave_phase))
		* (1.0 - smooth * 0.72)
		* HOVER_WEAVE_AMP_METERS
		* _weave_sign
	)
	var bob := sin(_total_clock * HOVER_BOB_FREQ + _weave_phase) * HOVER_BOB_AMP_METERS
	var fwd_dir := travel.normalized() if not travel.is_zero_approx() else Vector3.BACK
	global_position = Vector3(
		base_xz.x + perp.x * weave + fwd_dir.x * drift_forward,
		_landing_position.y + _hover_altitude + bob,
		base_xz.z + perp.z * weave + fwd_dir.z * drift_forward
	)
	if t >= 1.0:
		_phase = FlightPhase.LANDING
		_elapsed = 0.0
		_land_start_altitude = maxf(0.35, global_position.y - _landing_position.y)


func _step_landing() -> void:
	var t := clampf(_elapsed / _land_seconds, 0.0, 1.0)
	var smooth := t * t * (3.0 - 2.0 * t)
	var flutter := sin(t * PI * FLUTTER_CYCLES) * (1.0 - t) * FLUTTER_HEIGHT_METERS
	var altitude := maxf(0.0, lerpf(_land_start_altitude, 0.0, smooth) + flutter)
	var spiral := sin(t * PI * 2.0) * (1.0 - t) * 0.45 * _weave_sign
	var dir_to_end := Vector3(
		_landing_position.x - global_position.x, 0.0, _landing_position.z - global_position.z
	)
	var side := (
		Vector3(-dir_to_end.z, 0.0, dir_to_end.x).normalized()
		if not dir_to_end.is_zero_approx()
		else Vector3.RIGHT
	)
	var next_x := lerpf(global_position.x, _landing_position.x, smooth) + side.x * spiral
	var next_z := lerpf(global_position.z, _landing_position.z, smooth) + side.z * spiral
	global_position = Vector3(next_x, _landing_position.y + altitude, next_z)
	if t >= 1.0:
		_resolve_landing()


func _step_fade() -> void:
	if _elapsed >= FADE_CLEANUP_SECONDS:
		queue_free()


func _resolve_landing() -> void:
	if _finished:
		return
	_finished = true
	if is_in_group(GREAT_SPORE_GROUP):
		remove_from_group(GREAT_SPORE_GROUP)
	var parent := _resolve_spawn_parent()
	var spawned: Node = null
	if is_instance_valid(parent) and not parent.is_queued_for_deletion():
		var actual_outcome := _resolve_actual_outcome()
		if actual_outcome == OutcomeKind.MUSHROOM_EGG:
			spawned = _spawn_egg(parent)
		else:
			spawned = _spawn_poison_cloud(parent)
		_spawn_landing_burst(parent, actual_outcome == OutcomeKind.MUSHROOM_EGG)
		landed.emit(_landing_position, actual_outcome, spawned)
	else:
		landed.emit(_landing_position, _outcome, null)

	_phase = FlightPhase.FADE
	_elapsed = 0.0
	for emitter: GPUParticles3D in _emitters:
		if is_instance_valid(emitter):
			emitter.emitting = false
	if is_instance_valid(_glow_light):
		_glow_light.visible = false
	if is_instance_valid(_shadow_mesh):
		_shadow_mesh.visible = false


func _resolve_owner_elite() -> MushroomEnemy:
	if _owner_ref == null:
		return null
	var obj: Variant = _owner_ref.get_ref()
	if obj == null or not is_instance_valid(obj):
		return null
	var mushroom := obj as MushroomEnemy
	if mushroom == null or mushroom.is_queued_for_deletion():
		return null
	return mushroom


func _resolve_spawn_parent() -> Node:
	var direct_parent := get_parent()
	var live_owner := _resolve_owner_elite()
	if (
		is_instance_valid(direct_parent)
		and not direct_parent.is_queued_for_deletion()
		and direct_parent.is_inside_tree()
		and direct_parent != live_owner
	):
		return direct_parent
	if _fallback_parent_ref != null:
		var cached: Variant = _fallback_parent_ref.get_ref()
		if (
			cached is Node
			and is_instance_valid(cached)
			and not (cached as Node).is_queued_for_deletion()
			and (cached as Node).is_inside_tree()
		):
			return cached as Node
	if not is_inside_tree() or get_tree() == null:
		return null
	var current_scene := get_tree().current_scene
	if (
		is_instance_valid(current_scene)
		and not current_scene.is_queued_for_deletion()
		and current_scene.is_inside_tree()
	):
		return current_scene
	var root_node := get_tree().root
	if is_instance_valid(root_node) and not root_node.is_queued_for_deletion():
		return root_node
	return null


func _resolve_actual_outcome() -> OutcomeKind:
	if _outcome != OutcomeKind.MUSHROOM_EGG:
		return OutcomeKind.SPORE_CLOUD
	var live_owner := _resolve_owner_elite()
	if (
		live_owner != null
		and not live_owner.dead
		and live_owner.has_method("can_spawn_more_minions")
	):
		if not bool(live_owner.call("can_spawn_more_minions")):
			return OutcomeKind.SPORE_CLOUD
	return OutcomeKind.MUSHROOM_EGG


func _spawn_egg(parent: Node) -> MushroomEgg:
	var egg := EGG_SCENE.instantiate() as MushroomEgg
	if egg == null:
		return null
	var live_owner := _resolve_owner_elite()
	egg.setup_spawned(live_owner, _egg_hatch_seconds)
	if live_owner != null:
		egg.show_debug_health = live_owner.show_debug_health
	egg.position = (
		(parent as Node3D).to_local(_landing_position) if parent is Node3D else _landing_position
	)
	parent.add_child(egg)
	egg.global_position = _landing_position
	if (
		live_owner != null
		and not live_owner.dead
		and live_owner.has_method("register_spawned_minion")
	):
		live_owner.call("register_spawned_minion", egg)
	return egg


func _spawn_poison_cloud(parent: Node) -> MushroomSporeCloud:
	var cloud := SPORE_CLOUD_SCRIPT.new() as MushroomSporeCloud
	if cloud == null:
		return null
	# Bloom quickly and linger ~5.2s so the non-egg purple spore zones stay clearly visible
	# on the ground alongside the 5.5s MushroomEgg incubation window.
	var quick_ramp := minf(_cloud_ramp, CLOUD_SPAWN_RAMP_CAP_SECONDS)
	var cloud_life := maxf(_cloud_duration, 5.2)
	var live_owner := _resolve_owner_elite()
	cloud.setup(live_owner, _cloud_radius, cloud_life, quick_ramp, _poison_interval, _poison_damage)
	if live_owner != null:
		cloud.configure_visuals(
			live_owner.spore_particle_count,
			live_owner.mist_particle_count,
			live_owner.spore_particle_lifetime,
			live_owner.mist_particle_lifetime,
			maxf(live_owner.ground_mist_opacity, 0.36),
			live_owner.ground_mist_scale,
			live_owner.visual_spread_scale
		)
	if parent is Node3D:
		cloud.position = (parent as Node3D).to_local(_landing_position)
	else:
		cloud.position = _landing_position
	parent.add_child(cloud)
	cloud.global_position = _landing_position
	cloud.activate_poison()
	return cloud


func _set_active_visuals(active: bool) -> void:
	_emitters_started = active
	for emitter: GPUParticles3D in _emitters:
		if is_instance_valid(emitter):
			emitter.emitting = active
	if is_instance_valid(_glow_light):
		_glow_light.visible = active
	if is_instance_valid(_shadow_mesh):
		_shadow_mesh.visible = active


func _update_visual_animation(_step: float) -> void:
	if not _emitters_started:
		return
	if is_instance_valid(_shadow_mesh):
		var altitude := maxf(0.0, global_position.y - _landing_position.y)
		var height_ratio := clampf(altitude / maxf(0.5, _hover_altitude), 0.0, 1.0)
		var shadow_scale := lerpf(1.0, SHADOW_MIN_SCALE, height_ratio)
		_shadow_mesh.global_position = Vector3(
			global_position.x, _landing_position.y + SHADOW_GROUND_OFFSET_Y, global_position.z
		)
		_shadow_mesh.scale = Vector3(shadow_scale, 1.0, shadow_scale)
	if is_instance_valid(_glow_light):
		var landing_boost := 0.8 if _phase == FlightPhase.LANDING else 0.0
		var twinkle := 0.65 + 0.55 * sin(_total_clock * 14.0 + _weave_phase)
		_glow_light.light_energy = maxf(0.25, twinkle + landing_boost)


func _build_visuals() -> void:
	# Keep all 5 airborne spores visually unified (enchanted lime-violet shimmer) so players
	# cannot tell which clusters hold Eggs vs purple poison clouds until landing.
	var main_color := Color(0.76, 1.0, 0.44, 0.98)
	var blink_flash := Color(0.98, 0.86, 1.0, 1.0)
	var mist_color := Color(0.7, 0.42, 0.98, 0.48)

	_glow_light = OmniLight3D.new()
	_glow_light.name = "GreatSporeLight"
	_glow_light.light_color = Color(0.84, 0.96, 0.56)
	_glow_light.light_energy = 1.0
	_glow_light.omni_range = 3.2
	_glow_light.shadow_enabled = false
	add_child(_glow_light)

	var spark_tex := SPARK_MOTE_TEXTURE
	var spore_tex := SPORE_CLOUD_SCRIPT._create_purple_spore_texture()
	var mist_tex := SPORE_CLOUD_SCRIPT._create_soft_mist_texture()

	# Layer 1: Clustered luminous particles forming the airborne spore head ("gom nhieu hat sang").
	var core_cluster := _create_particle_layer(
		{
			"name": "GreatSporeCoreCluster",
			"amount": CORE_PARTICLE_COUNT,
			"lifetime": 0.52,
			"life_random": 0.35,
			"local_coords": false,
			"radius": 0.28,
			"speed_min": 0.12,
			"speed_max": 0.48,
			"gravity": Vector3(0.0, 0.25, 0.0),
			"turb_strength": 1.35,
			"scale_min": 0.42,
			"scale_max": 0.92,
			"scale_curve": _create_blink_scale_curve(),
			"color_ramp": _create_blink_ramp(main_color, blink_flash, 3),
			"texture": spark_tex,
			"quad_size": Vector2(0.42, 0.42),
			"additive": true,
		}
	)
	add_child(core_cluster)
	_emitters.append(core_cluster)

	# Layer 2: Inner fast-blinking orbiting pollen motes bound tightly inside the head cluster.
	var spark_cluster := _create_particle_layer(
		{
			"name": "GreatSporeSparkCluster",
			"amount": SPARK_PARTICLE_COUNT,
			"lifetime": 0.42,
			"life_random": 0.4,
			"local_coords": true,
			"radius": 0.22,
			"speed_min": 0.18,
			"speed_max": 0.52,
			"gravity": Vector3(0.0, 0.15, 0.0),
			"turb_strength": 1.5,
			"scale_min": 0.32,
			"scale_max": 0.78,
			"scale_curve": _create_blink_scale_curve(),
			"color_ramp": _create_blink_ramp(blink_flash, main_color, 4),
			"texture": spore_tex,
			"quad_size": Vector2(0.46, 0.46),
			"additive": true,
		}
	)
	add_child(spark_cluster)
	_emitters.append(spark_cluster)

	# Layer 3: Free-drifting world-space blinking pollen dust trail along the wide flight arc.
	var blink_trail := _create_particle_layer(
		{
			"name": "GreatSporeBlinkTrail",
			"amount": TRAIL_BLINK_PARTICLE_COUNT,
			"lifetime": 2.0,
			"life_random": 0.45,
			"local_coords": false,
			"radius": 0.22,
			"speed_min": 0.3,
			"speed_max": 0.95,
			"gravity": Vector3(0.0, 0.36, 0.0),
			"turb_strength": 2.05,
			"scale_min": 0.28,
			"scale_max": 0.76,
			"scale_curve": _create_blink_scale_curve(),
			"color_ramp": _create_blink_ramp(main_color, blink_flash, 5),
			"texture": spark_tex,
			"quad_size": Vector2(0.32, 0.32),
			"additive": true,
		}
	)
	add_child(blink_trail)
	_emitters.append(blink_trail)

	# Layer 4: Subtle translucent mist ribbon along trajectory so all 5-6 paths read clearly.
	var mist_trail := _create_particle_layer(
		{
			"name": "GreatSporeMistTrail",
			"amount": TRAIL_MIST_PARTICLE_COUNT,
			"lifetime": 0.95,
			"life_random": 0.25,
			"local_coords": false,
			"radius": 0.22,
			"speed_min": 0.08,
			"speed_max": 0.28,
			"gravity": Vector3(0.0, 0.18, 0.0),
			"turb_strength": 1.1,
			"scale_min": 0.55,
			"scale_max": 1.1,
			"scale_curve": null,
			"color_ramp": _create_soft_fade_ramp(mist_color),
			"texture": mist_tex,
			"quad_size": Vector2(1.05, 1.05),
			"additive": false,
		}
	)
	add_child(mist_trail)
	_emitters.append(mist_trail)

	var shadow := SphereMesh.new()
	shadow.radius = SHADOW_BASE_RADIUS
	shadow.height = 0.01
	var smat := StandardMaterial3D.new()
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = Color(0.05, 0.02, 0.1, 0.38)
	shadow.material = smat
	_shadow_mesh = MeshInstance3D.new()
	_shadow_mesh.name = "GreatSporeShadow"
	_shadow_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow_mesh.mesh = shadow
	add_child(_shadow_mesh)


func _create_particle_layer(cfg: Dictionary) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = String(cfg["name"])
	particles.emitting = false
	particles.amount = int(cfg["amount"])
	particles.lifetime = float(cfg["lifetime"])
	particles.local_coords = bool(cfg["local_coords"])
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.visibility_aabb = AABB(Vector3(-28.0, -10.0, -28.0), Vector3(56.0, 24.0, 56.0))

	var process := ParticleProcessMaterial.new()
	process.lifetime_randomness = float(cfg["life_random"])
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = float(cfg["radius"])
	process.direction = Vector3.UP
	process.spread = 180.0
	process.initial_velocity_min = float(cfg["speed_min"])
	process.initial_velocity_max = float(cfg["speed_max"])
	process.gravity = cfg["gravity"] as Vector3
	process.turbulence_enabled = true
	process.turbulence_noise_strength = float(cfg["turb_strength"])
	process.turbulence_noise_scale = 1.35
	process.turbulence_noise_speed = Vector3(0.75, 0.55, 0.75)
	process.turbulence_noise_speed_random = 0.65
	process.scale_min = float(cfg["scale_min"])
	process.scale_max = float(cfg["scale_max"])
	if cfg["scale_curve"] != null:
		process.scale_curve = cfg["scale_curve"] as CurveTexture
	process.color_ramp = cfg["color_ramp"] as GradientTexture1D
	particles.process_material = process

	var qmat := StandardMaterial3D.new()
	qmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qmat.vertex_color_use_as_albedo = true
	qmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	qmat.albedo_texture = cfg["texture"] as Texture2D
	if bool(cfg["additive"]):
		qmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var quad := QuadMesh.new()
	quad.size = cfg["quad_size"] as Vector2
	quad.material = qmat
	particles.draw_pass_1 = quad
	return particles


func _create_blink_ramp(base_color: Color, flash_color: Color, cycles: int) -> GradientTexture1D:
	var grad := Gradient.new()
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	offsets.append(0.0)
	colors.append(Color(base_color.r, base_color.g, base_color.b, 0.0))
	var steps := maxi(2, cycles) * 2
	for i in range(1, steps):
		var t := float(i) / float(steps)
		var env := 1.0 - maxf(0.0, (t - 0.68) / 0.32)
		var is_peak := i % 2 == 1
		var c := flash_color if is_peak else base_color
		var alpha := (0.98 if is_peak else 0.14) * env
		offsets.append(t * 0.94)
		colors.append(Color(c.r, c.g, c.b, alpha))
	offsets.append(1.0)
	colors.append(Color(base_color.r * 0.5, base_color.g * 0.5, base_color.b * 0.7, 0.0))
	grad.offsets = offsets
	grad.colors = colors
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	return ramp


func _create_soft_fade_ramp(peak_color: Color) -> GradientTexture1D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.12, 0.6, 1.0])
	grad.colors = PackedColorArray(
		[
			Color(peak_color.r, peak_color.g, peak_color.b, 0.0),
			peak_color,
			Color(peak_color.r, peak_color.g, peak_color.b, peak_color.a * 0.45),
			Color(peak_color.r, peak_color.g, peak_color.b, 0.0),
		]
	)
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	return ramp


func _create_blink_scale_curve() -> CurveTexture:
	var curve := Curve.new()
	curve.max_value = 1.4
	curve.add_point(Vector2(0.0, 0.25))
	curve.add_point(Vector2(0.14, 1.25))
	curve.add_point(Vector2(0.32, 0.42))
	curve.add_point(Vector2(0.52, 1.15))
	curve.add_point(Vector2(0.72, 0.35))
	curve.add_point(Vector2(0.86, 0.9))
	curve.add_point(Vector2(1.0, 0.0))
	var tex := CurveTexture.new()
	tex.curve = curve
	return tex


func _spawn_landing_burst(parent: Node, is_egg: bool) -> void:
	var burst := CPUParticles3D.new()
	burst.name = "GreatSporeTouchdown"
	burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	burst.amount = 24 if is_egg else 46
	burst.lifetime = 0.52 if is_egg else 0.72
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.emitting = false
	burst.local_coords = false
	burst.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	burst.emission_ring_axis = Vector3.UP
	burst.emission_ring_radius = 0.35 if is_egg else 0.55
	burst.emission_ring_inner_radius = 0.08
	burst.direction = Vector3.UP
	burst.spread = 82.0 if is_egg else 96.0
	burst.initial_velocity_min = 1.6 if is_egg else 3.2
	burst.initial_velocity_max = 3.4 if is_egg else 6.4
	burst.gravity = Vector3(0.0, -2.8 if is_egg else 0.45, 0.0)
	burst.scale_amount_min = 0.35 if is_egg else 0.55
	burst.scale_amount_max = 0.78 if is_egg else 1.25
	var grad := Gradient.new()
	grad.colors = PackedColorArray(
		[
			Color(0.74, 1.0, 0.42, 0.96) if is_egg else Color(0.88, 0.52, 1.0, 0.98),
			Color(0.35, 0.16, 0.65, 0.0),
		]
	)
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	burst.color_ramp = grad
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.albedo_texture = (
		SPARK_MOTE_TEXTURE if is_egg else SPORE_CLOUD_SCRIPT._create_purple_spore_texture()
	)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.42 if is_egg else 0.75, 0.42 if is_egg else 0.75)
	quad.material = mat
	burst.mesh = quad
	parent.add_child(burst)
	burst.global_position = _landing_position + Vector3.UP * 0.22
	burst.emitting = true
	var cleanup := burst.create_tween()
	cleanup.tween_interval(0.95)
	cleanup.tween_callback(burst.queue_free)
