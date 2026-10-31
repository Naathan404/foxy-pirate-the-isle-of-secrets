extends Node3D
## Screen-facing energy, deterministic particle motion, and a staged release envelope.
## Existing set_progress/burst and Inspector fields remain compatible with the bow scenes.

enum Presentation { CHARGE, IMPACT }

const ENERGY_SHADER: Shader = preload("res://gameplay/weapons/bow_energy.gdshader")
const GOLDEN_RATIO: float = 1.61803398875
const HALO: int = 0
const GLINT: int = 1
const MOTE: int = 2
const BLOOM: int = 3
const IMPACT_CUT: int = 5
const SHADER_RING_RADIUS: float = 0.7
const MIN_RENDER_SIZE: float = 0.001

@export_group("Appearance")
@export var effect_color: Color = Color(0.16, 0.65, 1.0, 0.85)
@export var core_color: Color = Color(1.0, 0.96, 0.78, 1.0)
@export_range(0.01, 3.0, 0.01) var burst_duration: float = 0.42
@export var presentation: Presentation = Presentation.CHARGE
@export_range(0.1, 3.0, 0.05) var effect_brightness: float = 1.6
@export_range(0.01, 0.5, 0.01) var charge_smoothing_seconds: float = 0.075
@export_range(0.0, 2.0, 0.05) var focus_forward_offset: float = 0.55

@export_group("Rings")
@export_range(0, 12, 1) var ring_count: int = 3
@export_range(0.01, 2.0, 0.01) var ring_radius: float = 0.25
@export_range(0.001, 0.5, 0.001) var ring_thickness: float = 0.03
@export var ring_base_scale: float = 0.6
@export var ring_charge_scale_bonus: float = 2.0
@export var ring_scale_spacing: float = 0.22
@export var first_ring_tilt_degrees: float = 90.0
@export var ring_tilt_step_radians: float = 0.3
@export var ring_roll_step_radians: float = 0.6
@export var ring_spin_base: float = 2.0
@export var ring_spin_step: float = 2.0
@export var ring_burst_speed: float = 10.0
@export var ring_burst_charge_speed_bonus: float = 12.0
@export_range(0.0, 1.0, 0.01) var ring_base_opacity: float = 0.3
@export_range(0.0, 1.0, 0.01) var ring_charge_opacity_bonus: float = 0.6
@export_range(0.0, 0.1, 0.005) var ring_release_stagger: float = 0.025
@export_range(0.0, 1.0, 0.01) var ring_arc_breakup: float = 0.8
@export var ring_arc_frequency: float = 3.0
@export_range(0.01, 0.5, 0.01) var ring_glow_softness: float = 0.1
@export_range(0.0, 1.0, 0.01) var ring_burst_expansion_scale: float = 0.4
@export_range(0.1, 1.0, 0.05) var ring_charge_contraction: float = 0.85
@export_range(0.1, 1.0, 0.05) var ring_min_aspect: float = 0.75
@export_range(0.1, 1.0, 0.05) var ring_layer_opacity_falloff: float = 0.75

@export_group("Pulse")
@export var pulse_base_frequency: float = 8.0
@export var pulse_charge_frequency_bonus: float = 20.0
@export_range(0.0, 1.0, 0.01) var pulse_amplitude: float = 0.035

@export_group("Sparks")
@export_range(0, 64, 1) var spark_count: int = 16
@export_range(0.001, 0.5, 0.001) var spark_radius: float = 0.045
@export var spark_orbit_base_radius: float = 0.35
@export var spark_orbit_charge_radius_bonus: float = 0.7
@export var spark_orbit_base_speed: float = 2.0
@export var spark_orbit_charge_speed_bonus: float = 7.0
@export var spark_burst_speed: float = 4.0
@export var spark_burst_charge_speed_bonus: float = 8.0
@export var spark_vertical_frequency: float = 2.0
@export var spark_vertical_phase_step: float = 1.0
@export var spark_vertical_height_ratio: float = 0.65
@export var spark_base_scale: float = 0.6
@export var spark_charge_scale_bonus: float = 1.6
@export_range(0.1, 2.0, 0.05) var spark_inflow_seconds: float = 0.8
@export_range(0.0, 1.0, 0.01) var spark_focus_radius: float = 0.06
@export var spark_streak_length: float = 2.8
@export_range(0.1, 1.0, 0.05) var spark_shortest_life_ratio: float = 0.55
@export var spark_size_variation: Vector2 = Vector2(0.6, 1.3)
@export_range(0.1, 1.0, 0.05) var spark_burst_distance_multiplier: float = 0.55

@export_group("Core Flash")
@export var core_base_size: float = 0.25
@export var core_charge_size_bonus: float = 0.65
@export var core_burst_size: float = 1.8
@export_range(0.01, 0.3, 0.005) var core_flash_seconds: float = 0.09
@export var bloom_size_multiplier: float = 3.0
@export_range(0.0, 1.0, 0.01) var bloom_opacity: float = 0.3
@export_range(0.01, 0.3, 0.01) var tier_flash_seconds: float = 0.1

@export_group("Light")
@export var light_color: Color = Color(0.25, 0.75, 1.0)
@export_range(0.0, 20.0, 0.1) var light_range: float = 2.5
@export var light_base_energy: float = 0.25
@export var light_charge_energy_bonus: float = 1.0
@export var light_burst_multiplier: float = 2.0

@export_group("Charge Audio")
@export var tick_sound: AudioStream = preload("res://assets/audio/combat/bow_charge_tick.wav")
@export_range(1, 20, 1) var tick_steps: int = 5
@export_range(-80.0, 6.0, 1.0) var tick_volume_db: float = -29.0
@export var tick_charge_volume_bonus_db: float = 5.0
@export var tick_pitch_base: float = 1.3
@export var tick_charge_pitch_bonus: float = 0.6

var _progress: float = 0.0
var _target_progress: float = 0.0
var _age: float = 0.0
var _charge_age: float = 0.0
var _released: bool = false
var _tier: int = 0
var _tier_flash: float = 0.0
var _aim: Vector3 = Vector3.FORWARD
var _rings: Array[MeshInstance3D] = []
var _sparks: Array[MeshInstance3D] = []
var _core: MeshInstance3D
var _bloom: MeshInstance3D
var _light: OmniLight3D


func _ready() -> void:
	for index in ring_count:
		var ring := _make_quad(
			IMPACT_CUT if presentation == Presentation.IMPACT else HALO,
			Vector2.ONE * (ring_radius + ring_thickness) * 2.0 / SHADER_RING_RADIUS
		)
		var material := ring.material_override as ShaderMaterial
		material.set_shader_parameter("ring_width", ring_thickness)
		material.set_shader_parameter("arc_breakup", ring_arc_breakup)
		material.set_shader_parameter("arc_frequency", ring_arc_frequency)
		material.set_shader_parameter("glow_softness", ring_glow_softness)
		_rings.append(ring)
	for index in spark_count:
		_sparks.append(_make_quad(MOTE, Vector2.ONE * spark_radius * 2.0))
	_core = _make_quad(GLINT, Vector2.ONE)
	_bloom = _make_quad(BLOOM, Vector2.ONE)
	_light = OmniLight3D.new()
	_light.omni_range = light_range
	_light.light_color = light_color
	_light.light_energy = 0.0
	add_child(_light)
	_update_presentation(0.0)


func _make_quad(shape: int, size: Vector2) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size
	visual.mesh = quad
	var material := ShaderMaterial.new()
	material.shader = ENERGY_SHADER
	material.set_shader_parameter("shape", shape)
	material.set_shader_parameter("glow_color", effect_color)
	material.set_shader_parameter("core_color", core_color)
	material.set_shader_parameter("brightness", effect_brightness)
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	return visual


func set_aim(direction: Vector3) -> void:
	if not direction.is_zero_approx():
		_aim = direction.normalized()


func set_progress(progress: float) -> void:
	_target_progress = clampf(progress, 0.0, 1.0)
	var tier := floori(_target_progress * tick_steps)
	if tier > _tier:
		_tier = tier
		_tier_flash = 1.0
		get_node("/root/AudioManager").play_sfx_3d(
			tick_sound,
			global_position,
			tick_volume_db + _target_progress * tick_charge_volume_bonus_db,
			tick_pitch_base + _target_progress * tick_charge_pitch_bonus
		)


func burst(strength: float) -> void:
	_progress = clampf(strength, 0.0, 1.0)
	_target_progress = _progress
	_released = true
	_age = 0.0
	_update_presentation(0.0)


func _process(delta: float) -> void:
	_age += delta
	_charge_age += delta
	if _released and _age >= burst_duration:
		queue_free()
		return
	if not _released:
		_progress = lerpf(_progress, _target_progress, 1.0 - exp(-delta / charge_smoothing_seconds))
	_tier_flash *= exp(-delta / tier_flash_seconds)
	_update_presentation(delta)


func _update_presentation(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var right := Vector3.RIGHT
	var up := Vector3.UP
	if is_instance_valid(camera):
		right = global_basis.inverse() * camera.global_basis.x
		up = global_basis.inverse() * camera.global_basis.y
	var focus := (
		_aim * focus_forward_offset if presentation == Presentation.CHARGE else Vector3.ZERO
	)
	var fade := pow(1.0 - clampf(_age / burst_duration, 0.0, 1.0), 2.0) if _released else 1.0
	_update_rings(focus)
	_update_sparks(focus, right, up)
	_update_core(focus)
	_light.position = focus
	_light.light_energy = (light_base_energy + _progress * light_charge_energy_bonus) * fade
	if _released:
		_light.light_energy *= light_burst_multiplier


func _update_rings(focus: Vector3) -> void:
	var frequency := pulse_base_frequency + _progress * pulse_charge_frequency_bonus
	var pulse := 1.0 + sin(_charge_age * frequency) * pulse_amplitude
	for index in _rings.size():
		var ring := _rings[index]
		var material := ring.material_override as ShaderMaterial
		var size := (
			(ring_base_scale + _progress * ring_charge_scale_bonus + index * ring_scale_spacing)
			* pulse
		)
		var opacity := ring_base_opacity + _progress * ring_charge_opacity_bonus
		opacity *= pow(ring_layer_opacity_falloff, index)
		if _released:
			var time := clampf((_age - index * ring_release_stagger) / burst_duration, 0.0, 1.0)
			var expansion := 1.0 - pow(1.0 - time, 3.0)
			size += (
				expansion
				* burst_duration
				* ring_burst_expansion_scale
				* (ring_burst_speed + _progress * ring_burst_charge_speed_bonus)
			)
			opacity *= pow(1.0 - time, 2.0) if _age >= index * ring_release_stagger else 0.0
		else:
			# A contracting halo communicates stored tension rather than an expanding bubble.
			size *= lerpf(1.0, ring_charge_contraction, _progress)
		ring.position = focus
		ring.scale = Vector3.ONE * size
		material.set_shader_parameter("opacity", clampf(opacity, 0.0, 1.0))
		material.set_shader_parameter(
			"phase",
			_charge_age * (ring_spin_base + index * ring_spin_step) + index * ring_roll_step_radians
		)
		var tilt := (
			deg_to_rad(first_ring_tilt_degrees) if index == 0 else ring_tilt_step_radians * index
		)
		material.set_shader_parameter("aspect", maxf(ring_min_aspect, absf(sin(tilt))))


func _update_sparks(focus: Vector3, right: Vector3, up: Vector3) -> void:
	for index in _sparks.size():
		var seed := fposmod(index * GOLDEN_RATIO, 1.0)
		var angle := index * TAU / _sparks.size()
		var radius: float
		var alpha: float
		var stretch := 1.0
		if _released:
			var life := lerpf(spark_shortest_life_ratio, 1.0, seed) * burst_duration
			var time := clampf(_age / life, 0.0, 1.0)
			radius = (
				(1.0 - pow(1.0 - time, 3.0))
				* life
				* (spark_burst_speed + _progress * spark_burst_charge_speed_bonus)
			)
			alpha = pow(1.0 - time, 2.0)
			radius *= spark_burst_distance_multiplier
			stretch = spark_streak_length
		else:
			var time := fposmod(_charge_age / spark_inflow_seconds + seed, 1.0)
			angle += time * (spark_orbit_base_speed + _progress * spark_orbit_charge_speed_bonus)
			radius = lerpf(
				spark_orbit_base_radius + _progress * spark_orbit_charge_radius_bonus,
				spark_focus_radius,
				time * time
			)
			alpha = sin(time * PI) * (_progress + _tier_flash)
		var height := sin(angle * spark_vertical_frequency + index * spark_vertical_phase_step)
		_sparks[index].position = (
			focus
			+ right * cos(angle) * radius
			+ up * (sin(angle) + height * spark_vertical_height_ratio) * radius
		)
		var size := (
			(spark_base_scale + _progress * spark_charge_scale_bonus)
			* lerpf(spark_size_variation.x, spark_size_variation.y, seed)
		)
		_sparks[index].scale = Vector3(size * stretch, size, size)
		var material := _sparks[index].material_override as ShaderMaterial
		material.set_shader_parameter("opacity", clampf(alpha, 0.0, 1.0))
		material.set_shader_parameter("billboard_rotation", angle)


func _update_core(focus: Vector3) -> void:
	var size := core_base_size + _progress * core_charge_size_bonus
	var alpha := _progress + _tier_flash
	if _released:
		var time := clampf(_age / core_flash_seconds, 0.0, 1.0)
		size = core_burst_size * (1.0 + _progress) * (1.0 - pow(1.0 - time, 3.0))
		alpha = pow(1.0 - time, 2.0)
	_core.position = focus
	_core.scale = Vector3.ONE * maxf(size, MIN_RENDER_SIZE)
	(_core.material_override as ShaderMaterial).set_shader_parameter(
		"opacity", clampf(alpha, 0.0, 1.0)
	)
	_bloom.position = focus
	_bloom.scale = _core.scale * bloom_size_multiplier
	(_bloom.material_override as ShaderMaterial).set_shader_parameter(
		"opacity", clampf(alpha * bloom_opacity, 0.0, 1.0)
	)
