class_name EliteBarrelInkVfx
extends RefCounted
## Ink presentation of the Elite Barrel's close-range attacks: ground warnings, blast waves,
## splashes, geysers and the bubbles of a wind-up. Damage stays with EliteBarrel.

enum Zone { WARNING, SHOCKWAVE, POOL }

const ZONE_SHADER := preload("res://gameplay/enemies/barrel/elite_barrel_ink_zone.gdshader")
const SPLASH_SCENE := preload("res://gameplay/enemies/barrel/barrel_bullet_impact.tscn")
const DROP_TEXTURE: Texture2D = preload("res://assets/sprites/effects/Dust Particle.png")
const BLAST_SOUND: AudioStream = preload("res://assets/audio/combat/bow_impact.wav")
const CHARGE_SOUND: AudioStream = preload("res://assets/audio/combat/dagger_throw.wav")
const INK_LIGHT := Color(0.86, 0.5, 0.6, 1.0)
const INK_DARK := Color(0.3, 0.09, 0.19, 1.0)
const GROUND_LIFT_METERS := 0.07
const WAVE_SECONDS := 0.26
const WAVE_FADE_SECONDS := 0.22
const POOL_HOLD_SECONDS := 0.9
const POOL_FADE_SECONDS := 0.8
const POOL_SIZE_SHARE := 0.8
const RING_SPLASHES := 12
const RING_SPLASH_SHARE := 0.8
const RING_SPLASH_SCALE := 1.7
const CENTER_SPLASH_SCALE := 3.0
const CONE_SPLASHES := 4
const CONE_SPLASH_SCALE := 1.35
const GEYSER_DROPS := 90
const GEYSER_SECONDS := 0.8
const BUBBLE_COUNT := 28
const BUBBLE_SECONDS := 0.55


## A ground disc of `radius`; `direction` aims the middle of a cone narrower than a full turn.
static func zone(
	parent: Node3D,
	at: Vector3,
	radius: float,
	kind: Zone,
	direction: Vector3 = Vector3.BACK,
	half_arc: float = PI
) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * radius * 2.0
	var material := ShaderMaterial.new()
	material.shader = ZONE_SHADER
	material.set_shader_parameter("mode", int(kind))
	# Tweens can only animate parameters that already hold a value.
	material.set_shader_parameter("progress", 0.0)
	material.set_shader_parameter("opacity", 1.0)
	material.set_shader_parameter("half_arc", half_arc)
	material.set_shader_parameter("seed", randf() * 100.0)
	# The pool lies under the wave, and both under the ground telegraphs of other attacks.
	material.render_priority = -1 if kind == Zone.POOL else 0
	var disc := MeshInstance3D.new()
	disc.mesh = plane
	disc.material_override = material
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(disc)
	disc.global_position = at + Vector3.UP * GROUND_LIFT_METERS
	disc.global_rotation = Vector3(0.0, atan2(direction.x, direction.z), 0.0)
	return disc


static func set_progress(disc: MeshInstance3D, progress: float) -> void:
	if is_instance_valid(disc):
		(disc.material_override as ShaderMaterial).set_shader_parameter("progress", progress)


## The burst around the barrel: a rolling wave, a lingering pool, splashes and a geyser.
static func blast(parent: Node3D, at: Vector3, radius: float) -> void:
	_wave(parent, at, radius, Vector3.BACK, PI)
	var pool := zone(parent, at, radius * POOL_SIZE_SHARE, Zone.POOL)
	_fade(pool, POOL_HOLD_SECONDS, POOL_FADE_SECONDS)
	_splash(parent, at, CENTER_SPLASH_SCALE)
	for index in RING_SPLASHES:
		var angle := TAU * (index + randf() * 0.5) / RING_SPLASHES
		var offset := Vector3(cos(angle), 0.0, sin(angle)) * radius * RING_SPLASH_SHARE
		_splash(parent, at + offset, RING_SPLASH_SCALE)
	_geyser(parent, at)
	CharmFeel.sound(parent, BLAST_SOUND, at, -2.0, 0.55)
	CharmFeel.shake(parent, 7.0, 0.22)


## The downward spray that covers the ground under the mouth during a fan volley.
static func cone_spray(
	parent: Node3D, at: Vector3, radius: float, direction: Vector3, half_arc: float
) -> void:
	_wave(parent, at, radius, direction, half_arc)
	for index in CONE_SPLASHES:
		var share := float(index) / (CONE_SPLASHES - 1) - 0.5
		var heading := direction.rotated(Vector3.UP, share * half_arc * 1.5)
		_splash(parent, at + heading * radius * randf_range(0.6, 0.82), CONE_SPLASH_SCALE)
	CharmFeel.sound(parent, BLAST_SOUND, at, -9.0, 0.85)


## Ink boiling up around the barrel while it winds up; free the node to stop it.
static func bubbles(parent: Node3D, radius: float) -> CPUParticles3D:
	var particles := _particles(BUBBLE_COUNT, BUBBLE_SECONDS, 0.26)
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	particles.emission_ring_axis = Vector3.UP
	particles.emission_ring_radius = radius
	particles.emission_ring_inner_radius = radius * 0.45
	particles.emission_ring_height = 0.1
	particles.direction = Vector3.UP
	particles.spread = 12.0
	particles.initial_velocity_min = 1.2
	particles.initial_velocity_max = 3.0
	particles.gravity = Vector3.ZERO
	parent.add_child(particles)
	particles.position = Vector3.UP * 0.15
	CharmFeel.sound(parent, CHARGE_SOUND, parent.global_position, -7.0, 0.45)
	return particles


static func _wave(
	parent: Node3D, at: Vector3, radius: float, direction: Vector3, half_arc: float
) -> void:
	var wave := zone(parent, at, radius, Zone.SHOCKWAVE, direction, half_arc)
	var material := wave.material_override as ShaderMaterial
	var tween := wave.create_tween()
	var roll := tween.tween_property(material, "shader_parameter/progress", 1.0, WAVE_SECONDS)
	roll.from(0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "shader_parameter/opacity", 0.0, WAVE_FADE_SECONDS)
	tween.tween_callback(wave.queue_free)


static func _fade(disc: MeshInstance3D, hold_seconds: float, fade_seconds: float) -> void:
	var tween := disc.create_tween()
	tween.tween_interval(hold_seconds)
	tween.tween_property(disc.material_override, "shader_parameter/opacity", 0.0, fade_seconds)
	tween.tween_callback(disc.queue_free)


static func _splash(parent: Node3D, at: Vector3, size: float) -> void:
	var splash := SPLASH_SCENE.instantiate() as BarrelInkSplash
	parent.add_child(splash)
	splash.global_position = at + Vector3.UP * GROUND_LIFT_METERS
	splash.scale = Vector3.ONE * size
	splash.play(Vector3.UP)


static func _geyser(parent: Node3D, at: Vector3) -> void:
	var particles := _particles(GEYSER_DROPS, GEYSER_SECONDS, 0.34)
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.9
	particles.direction = Vector3.UP
	particles.spread = 48.0
	particles.initial_velocity_min = 4.0
	particles.initial_velocity_max = 10.0
	particles.gravity = Vector3(0.0, -19.0, 0.0)
	parent.add_child(particles)
	particles.global_position = at + Vector3.UP * 0.5
	particles.emitting = true
	particles.create_tween().tween_callback(particles.queue_free).set_delay(GEYSER_SECONDS + 0.2)


static func _particles(amount: int, lifetime: float, size: float) -> CPUParticles3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = DROP_TEXTURE
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	quad.material = material
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	ramp.colors = PackedColorArray([INK_LIGHT, INK_DARK, Color(INK_DARK, 0.0)])
	var particles := CPUParticles3D.new()
	particles.mesh = quad
	particles.amount = amount
	particles.lifetime = lifetime
	particles.color_ramp = ramp
	particles.scale_amount_min = 0.55
	particles.scale_amount_max = 1.35
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return particles
