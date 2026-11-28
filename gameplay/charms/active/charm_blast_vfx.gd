class_name CharmBlastVfx
extends Node3D
## Presentation of a charm blast area. Damage always stays with the charm; this only shows
## where and when it lands. Three ways to use it:
## - `plant`: a fuse that burns for a set time, then the owner calls `detonate`
##   (Shadow Renment, Death Bloom, the Arrow Rain landing zone);
## - `charge`: the owner drives the fill with `set_fuse` and may resize it with `set_radius`
##   (Dead Man's Salute, Abyssal Whirlpool), then calls `detonate` or `dismiss`;
## - `burst`: an explosion right away, with no warning (muzzles, impacts, landings).
## A ground ring always marks the full radius. Kinds add their own look: a trembling ghost
## of Foxy (SHADOW), a flower (BLOOM), sun rays and inward sparks (GOLD), an inward water
## spiral with a geyser (TIDE), plain shards (SPARK). Built in code, so it needs no scene;
## it frees itself once its burst has faded.

enum Kind { SHADOW, BLOOM, GOLD, TIDE, SPARK }

const GROUND_SHADER: Shader = preload("res://gameplay/charms/active/charm_blast_ground.gdshader")
const SPRITE_SHADER: Shader = preload("res://gameplay/charms/active/charm_blast_sprite.gdshader")
const GHOST_TEXTURE: Texture2D = preload("res://assets/sprites/foxy/charm_casts/shadow_lunge.png")
## Must match quad_overscan in charm_blast_ground.gdshader.
const GROUND_OVERSCAN := 1.45
const GROUND_LIFT_METERS := 0.05
const BURST_SECONDS := 0.45
const DISMISS_SECONDS := 0.2
const SHARD_SHAPE := 0
const PETAL_SHAPE := 1
const FLOWER_SHAPE := 2
const GHOST_HEIGHT_METERS := 1.1
const GHOST_PIXEL_SIZE := 0.009
const GHOST_TREMBLE_METERS := 0.035
const FLOWER_SIZE_METERS := 1.6
const FLOWER_HEIGHT_METERS := 0.8
const DEBRIS_COUNT := 32
const WISP_COUNT := 14
const INK := Color(0.1, 0.03, 0.08)
## The kind's pattern number in charm_blast_ground.gdshader.
const GROUND_PATTERN := {
	Kind.SHADOW: 0, Kind.BLOOM: 1, Kind.GOLD: 2, Kind.TIDE: 3, Kind.SPARK: 4,
}

var kind: Kind = Kind.SHADOW
var tint: Color = Color.WHITE
var radius: float = 2.0
var fuse_seconds: float = 0.5
## Set by `charge`: the owner moves the fill with `set_fuse` instead of a timer.
var manual_fuse: bool = false
## Set by `burst`: no ghost, flower or wisps, just the explosion.
var bare: bool = false

var _age: float = 0.0
var _fuse: float = 0.0
var _burst_age: float = -1.0
var _built_radius: float = 1.0
var _ground: MeshInstance3D
var _ground_material: ShaderMaterial
var _ghost: Sprite3D
var _flower: MeshInstance3D
var _flower_material: ShaderMaterial
var _wisps: GPUParticles3D
var _wisp_process: ParticleProcessMaterial
var _debris: GPUParticles3D
var _fade_tween: Tween


## A blast that goes off `fuse` seconds from now, once the owner calls `detonate`.
static func plant(
	parent: Node, at: Vector3, blast_kind: Kind, blast_radius: float, fuse: float, color: Color
) -> CharmBlastVfx:
	return _create(parent, at, blast_kind, blast_radius, fuse, color, false, false)


## A charge the owner fills with `set_fuse` (0 to 1).
static func charge(
	parent: Node, at: Vector3, blast_kind: Kind, blast_radius: float, color: Color
) -> CharmBlastVfx:
	return _create(parent, at, blast_kind, blast_radius, 1.0, color, true, false)


## An explosion right now: shockwave ring, flash and debris.
static func burst(
	parent: Node, at: Vector3, blast_kind: Kind, blast_radius: float, color: Color
) -> CharmBlastVfx:
	var vfx := _create(parent, at, blast_kind, blast_radius, 0.01, color, false, true)
	vfx.detonate()
	return vfx


static func _create(
	parent: Node,
	at: Vector3,
	blast_kind: Kind,
	blast_radius: float,
	fuse: float,
	color: Color,
	manual: bool,
	is_bare: bool
) -> CharmBlastVfx:
	var vfx := CharmBlastVfx.new()
	vfx.kind = blast_kind
	vfx.radius = maxf(0.1, blast_radius)
	vfx.fuse_seconds = maxf(0.01, fuse)
	vfx.tint = color
	vfx.manual_fuse = manual
	vfx.bare = is_bare
	parent.add_child(vfx)
	vfx.global_position = at
	return vfx


func _ready() -> void:
	# Placed by hand; interpolating its first frame would slide it in from the origin.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_built_radius = radius
	_build_ground()
	if not bare:
		if kind == Kind.SHADOW:
			_build_ghost()
		elif kind == Kind.BLOOM:
			_build_flower()
		_wisps = _make_wisps()
	_debris = _make_debris()


func _process(delta: float) -> void:
	_age += maxf(0.0, delta)
	if not manual_fuse:
		_fuse = clampf(_age / fuse_seconds, 0.0, 1.0)
	_ground_material.set_shader_parameter("progress", _fuse)
	if _burst_age < 0.0:
		_animate_fuse(_fuse)
		return
	_burst_age += maxf(0.0, delta)
	var progress := clampf(_burst_age / BURST_SECONDS, 0.0, 1.0)
	_ground_material.set_shader_parameter("burst", progress)
	_animate_burst(progress)
	if _burst_age >= BURST_SECONDS + _debris.lifetime:
		queue_free()


## Fill of a `charge`, 0 to 1.
func set_fuse(progress: float) -> void:
	_fuse = clampf(progress, 0.0, 1.0)


## Grows or shrinks the area of a `charge`.
func set_radius(blast_radius: float) -> void:
	radius = maxf(0.1, blast_radius)
	var ratio := radius / _built_radius
	if is_instance_valid(_ground):
		_ground.scale = Vector3(ratio, 1.0, ratio)
	if _wisp_process != null and _is_inward():
		_wisp_process.emission_ring_radius = radius
		_wisp_process.emission_ring_inner_radius = radius * 0.85
		_wisp_process.radial_velocity_min = -radius * 1.6
		_wisp_process.radial_velocity_max = -radius * 2.2


## The explosion: shockwave ring, flash and debris; then the node frees itself.
func detonate() -> void:
	if _burst_age >= 0.0:
		return
	_burst_age = 0.0
	if is_instance_valid(_wisps):
		_wisps.emitting = false
	_set_debris_reach()
	_debris.restart()


## Fades away without exploding (a charge cancelled, or replaced by another blast).
func dismiss() -> void:
	if _burst_age >= 0.0 or (_fade_tween != null and _fade_tween.is_valid()):
		return
	if is_instance_valid(_wisps):
		_wisps.emitting = false
	_fade_tween = create_tween()
	_fade_tween.tween_method(_set_fade, 1.0, 0.0, DISMISS_SECONDS)
	_fade_tween.tween_callback(queue_free)


func _set_fade(value: float) -> void:
	_ground_material.set_shader_parameter("fade", value)
	if is_instance_valid(_ghost):
		_ghost.modulate.a = value * 0.7
	if is_instance_valid(_flower):
		_flower.visible = value > 0.05


func _is_inward() -> bool:
	return kind == Kind.GOLD or kind == Kind.TIDE


func _animate_fuse(fuse: float) -> void:
	# Trembles harder as the blast nears.
	var tremble := sin(_age * 55.0) * GHOST_TREMBLE_METERS * fuse
	if is_instance_valid(_ghost):
		_ghost.position = Vector3(tremble, GHOST_HEIGHT_METERS, 0.0)
		_ghost.modulate.a = 0.6 + 0.15 * sin(_age * 18.0) + 0.15 * fuse
	if is_instance_valid(_flower):
		_flower_material.set_shader_parameter("open", ease(fuse, 0.6))
		_flower.position.x = tremble
		_flower.scale = Vector3.ONE * (0.6 + 0.4 * fuse)


func _animate_burst(burst_progress: float) -> void:
	var swell := 1.0 + burst_progress * 0.6
	var fade := 1.0 - burst_progress
	if is_instance_valid(_ghost):
		_ghost.scale = Vector3.ONE * swell
		_ghost.modulate = Color(1.6, 1.4, 2.0, fade * fade)
	if is_instance_valid(_flower):
		_flower.scale = Vector3.ONE * swell
		_flower_material.set_shader_parameter("tint", Color(tint.lightened(0.4), fade * fade))


func _build_ground() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * radius * 2.0 * GROUND_OVERSCAN
	quad.orientation = PlaneMesh.FACE_Y
	_ground_material = ShaderMaterial.new()
	_ground_material.shader = GROUND_SHADER
	_ground_material.set_shader_parameter("tint", tint)
	_ground_material.set_shader_parameter("kind", GROUND_PATTERN[kind])
	_ground_material.set_shader_parameter("quad_overscan", GROUND_OVERSCAN)
	_ground = MeshInstance3D.new()
	_ground.name = "Ground"
	_ground.mesh = quad
	_ground.material_override = _ground_material
	_ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ground.position.y = GROUND_LIFT_METERS
	add_child(_ground)


func _build_ghost() -> void:
	_ghost = Sprite3D.new()
	_ghost.name = "Ghost"
	_ghost.texture = GHOST_TEXTURE
	_ghost.hframes = 4
	_ghost.vframes = 2
	_ghost.pixel_size = GHOST_PIXEL_SIZE
	_ghost.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_ghost.shaded = false
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.modulate = Color(tint.r * 0.9, tint.g * 0.7, tint.b * 1.1, 0.7)
	_ghost.position.y = GHOST_HEIGHT_METERS
	add_child(_ghost)


func _build_flower() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * FLOWER_SIZE_METERS
	_flower_material = _make_sprite_material(FLOWER_SHAPE, false)
	_flower_material.set_shader_parameter("tint", tint.lightened(0.15))
	_flower_material.set_shader_parameter("open", 0.0)
	_flower = MeshInstance3D.new()
	_flower.name = "Flower"
	_flower.mesh = quad
	_flower.material_override = _flower_material
	_flower.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flower.position.y = FLOWER_HEIGHT_METERS
	add_child(_flower)


## Continuous motes during the fuse: rising smoke or petals, or sparks and droplets drawn
## in from the rim for kinds that gather power.
func _make_wisps() -> GPUParticles3D:
	_wisp_process = _make_process()
	if _is_inward():
		_wisp_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		_wisp_process.emission_ring_axis = Vector3.UP
		_wisp_process.emission_ring_height = 0.1
		_wisp_process.direction = Vector3.UP
		_wisp_process.spread = 5.0
		_wisp_process.initial_velocity_min = 0.2
		_wisp_process.initial_velocity_max = 0.5
		_wisp_process.gravity = Vector3.ZERO
		if kind == Kind.TIDE:
			_wisp_process.tangential_accel_min = radius * 3.0
			_wisp_process.tangential_accel_max = radius * 4.0
		_wisp_process.scale_min = 0.45
		_wisp_process.scale_max = 0.8
	else:
		_wisp_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		_wisp_process.emission_sphere_radius = radius * 0.55
		_wisp_process.direction = Vector3.UP
		_wisp_process.spread = 15.0
		_wisp_process.initial_velocity_min = 0.4
		_wisp_process.initial_velocity_max = 0.9
		_wisp_process.gravity = Vector3(0, 0.4, 0)
		_wisp_process.scale_min = 0.35
		_wisp_process.scale_max = 0.6
	var wisps := _make_particles(
		"Wisps", WISP_COUNT * (2 if _is_inward() else 1), _wisp_process, 0.3, 0.7, false
	)
	wisps.position.y = 0.2
	set_radius(radius)
	wisps.emitting = true
	return wisps


func _make_debris() -> GPUParticles3D:
	var process := _make_process()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.2
	process.direction = Vector3(0, 0.35, 0)
	process.spread = 180.0
	process.flatness = 0.75
	process.angular_velocity_min = -540.0
	process.angular_velocity_max = 540.0
	process.scale_min = 0.6
	process.scale_max = 1.2
	if kind == Kind.TIDE:
		# A geyser: water thrown up out of the eye, falling back.
		process.direction = Vector3.UP
		process.spread = 28.0
		process.flatness = 0.0
	var debris := _make_particles("Debris", DEBRIS_COUNT, process, 0.5, 0.65, true)
	debris.position.y = 0.4
	return debris


## Throws the debris out to the current radius.
func _set_debris_reach() -> void:
	var process := _debris.process_material as ParticleProcessMaterial
	if kind == Kind.TIDE:
		process.initial_velocity_min = 6.0 + radius
		process.initial_velocity_max = 9.0 + radius * 1.5
		process.gravity = Vector3(0, -16.0, 0)
		process.damping_min = 0.5
		process.damping_max = 1.0
	else:
		process.initial_velocity_min = radius * 2.2
		process.initial_velocity_max = radius * 3.4
		process.damping_min = radius * 3.0
		process.damping_max = radius * 4.0
		process.gravity = Vector3(0, -6.0 if kind == Kind.BLOOM else -2.0, 0)
	_debris.visibility_aabb = AABB(
		Vector3(-radius * 2.0, -1.0, -radius * 2.0), Vector3(radius * 4.0, 8.0, radius * 4.0)
	)


func _make_process() -> ParticleProcessMaterial:
	var process := ParticleProcessMaterial.new()
	process.angle_min = -180.0
	process.angle_max = 180.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.7, 1.0])
	var bright := Color(tint.lightened(0.25), 1.0)
	ramp.colors = PackedColorArray(
		[Color(bright, 0.0), bright, Color(tint, 0.85), Color(tint.darkened(0.3), 0.0)]
	)
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp
	process.color_ramp = ramp_texture
	return process


func _make_particles(
	label: String,
	count: int,
	process: ParticleProcessMaterial,
	size: float,
	lifetime: float,
	one_shot: bool
) -> GPUParticles3D:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	var shape := PETAL_SHAPE if kind == Kind.BLOOM or kind == Kind.TIDE else SHARD_SHAPE
	quad.material = _make_sprite_material(shape, true)
	var particles := GPUParticles3D.new()
	particles.name = label
	particles.amount = count
	particles.lifetime = lifetime
	particles.one_shot = one_shot
	particles.explosiveness = 1.0 if one_shot else 0.0
	particles.emitting = false
	particles.process_material = process
	particles.draw_pass_1 = quad
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Placed by hand with the blast; never slide in.
	particles.interpolate = false
	particles.visibility_aabb = AABB(
		Vector3(-radius * 2.0, -1.0, -radius * 2.0), Vector3(radius * 4.0, 8.0, radius * 4.0)
	)
	add_child(particles)
	return particles


func _make_sprite_material(shape: int, particles: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SPRITE_SHADER
	material.set_shader_parameter("shape", shape)
	material.set_shader_parameter("ink", INK)
	material.set_shader_parameter("billboard_particles", particles)
	return material
