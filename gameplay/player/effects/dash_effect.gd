extends Node3D

const STREAK_SHADER: Shader = preload("res://gameplay/player/effects/dash_streak.gdshader")
const STREAK_POOL_SIZE: int = 8
const STREAK_INTERVAL_SECONDS: float = 0.035
const STREAK_LENGTH_MIN: float = 1.6
const STREAK_LENGTH_MAX: float = 2.8
const STREAK_WIDTH: float = 0.16
const STREAK_LATERAL_SPREAD: float = 0.45
const STREAK_HEIGHT_MIN: float = 0.15
const STREAK_HEIGHT_MAX: float = 1.1
const STREAK_LIFETIME_SECONDS: float = 0.22
const STREAK_COLOR := Color(0.45, 0.88, 1.0, 0.95)

@export var player: Player

@export_group("Dash Feedback")
@export_range(0.0, 3.0, 0.1) var shake_pixels: float = 1.2
@export_range(0.0, 0.3, 0.01) var ground_clearance: float = 0.04
@export_range(0.2, 2.0, 0.05) var ring_radius: float = 0.9

var _dashing: bool = false
var _rings: Array[MeshInstance3D] = []
var _ring_tweens: Array[Tween] = []
var _bursts: Array[GPUParticles3D] = []
var _streaks: Array[MeshInstance3D] = []
var _streak_tweens: Array[Tween] = []
var _next_streak: int = 0
var _streak_timer: float = 0.0

@onready var dash_particle: GPUParticles3D = $DashParticle


func _ready() -> void:
	dash_particle.local_coords = false
	# Placed at Foxy's feet every frame in _process, not on physics ticks.
	dash_particle.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	dash_particle.amount = 12
	dash_particle.lifetime = 0.15
	var dust_material := dash_particle.process_material as ParticleProcessMaterial
	if dust_material != null:
		dust_material.emission_box_extents = Vector3(0.08, 0.02, 0.06)
		dust_material.initial_velocity_min = 0.55
		dust_material.initial_velocity_max = 1.15
	_create_burst_effects()
	_create_streaks()
	set_process(false)


func _create_burst_effects() -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.82
	mesh.outer_radius = 1.0
	mesh.rings = 24
	mesh.ring_segments = 4
	_ring_tweens.resize(2)
	for index in range(2):
		var ring := MeshInstance3D.new()
		ring.name = "DashRing%d" % index
		ring.mesh = mesh
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.albedo_color = Color(0.65, 0.95, 1.0, 0.35)
		ring.material_override = material
		add_child(ring)
		ring.top_level = true
		# Placed once per dash on the rendered position; interpolation would slide it in.
		ring.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		ring.hide()
		_rings.append(ring)

		var burst := dash_particle.duplicate() as GPUParticles3D
		burst.name = "DashBurst%d" % index
		burst.process_material = dash_particle.process_material.duplicate()
		burst.one_shot = true
		burst.explosiveness = 1.0
		burst.amount = 4 if index == 0 else 3
		burst.lifetime = 0.15
		burst.emitting = false
		var process := burst.process_material as ParticleProcessMaterial
		process.spread = 32.0
		process.emission_box_extents = Vector3(0.08, 0.02, 0.06)
		process.initial_velocity_min = 0.55
		process.initial_velocity_max = 1.15
		add_child(burst)
		burst.top_level = true
		burst.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		_bursts.append(burst)


func _create_streaks() -> void:
	var mesh := QuadMesh.new()
	_streak_tweens.resize(STREAK_POOL_SIZE)
	for index in STREAK_POOL_SIZE:
		var streak := MeshInstance3D.new()
		streak.name = "DashStreak%d" % index
		streak.mesh = mesh
		streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader = STREAK_SHADER
		material.set_shader_parameter("streak_color", STREAK_COLOR)
		streak.material_override = material
		add_child(streak)
		streak.top_level = true
		streak.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		streak.hide()
		_streaks.append(streak)


## A fading speed line trailing behind Foxy, lying in the ground plane along the dash direction.
func _spawn_streak() -> void:
	var direction := player.last_facing_direction
	direction.y = 0.0
	if direction.is_zero_approx():
		return
	direction = direction.normalized()
	var index := _next_streak
	_next_streak = (_next_streak + 1) % STREAK_POOL_SIZE
	var streak := _streaks[index]
	if _streak_tweens[index] != null and _streak_tweens[index].is_valid():
		_streak_tweens[index].kill()
	var length := randf_range(STREAK_LENGTH_MIN, STREAK_LENGTH_MAX)
	var side := direction.cross(Vector3.UP)
	var offset := side * randf_range(-STREAK_LATERAL_SPREAD, STREAK_LATERAL_SPREAD)
	offset.y = randf_range(STREAK_HEIGHT_MIN, STREAK_HEIGHT_MAX)
	var basis := Basis(direction * length, Vector3.UP * STREAK_WIDTH, side)
	# The quad's head sits at the dash direction end: its centre trails Foxy by half a length.
	streak.global_transform = Transform3D(
		basis, _get_foot_position() + offset - direction * length * 0.4
	)
	var material := streak.material_override as ShaderMaterial
	material.set_shader_parameter("strength", 1.0)
	streak.show()
	var tween := streak.create_tween().set_parallel()
	_streak_tweens[index] = tween
	tween.tween_property(material, "shader_parameter/strength", 0.0, STREAK_LIFETIME_SECONDS)
	tween.tween_property(
		streak, "global_position", streak.global_position - direction * 0.8, STREAK_LIFETIME_SECONDS
	)
	tween.chain().tween_callback(streak.hide)


func _process(delta: float) -> void:
	if not _dashing:
		return
	_streak_timer -= delta
	if _streak_timer <= 0.0:
		_spawn_streak()
		_streak_timer += STREAK_INTERVAL_SECONDS
	_update_particle_direction(dash_particle)
	dash_particle.global_position = _get_foot_position() - player.last_facing_direction * 0.15


## Where Foxy's feet are drawn. The body's own position is a physics tick ahead of the
## interpolated picture, so effects placed from it drift away from the feet while moving.
func _get_foot_position() -> Vector3:
	var origin := player.get_global_transform_interpolated().origin
	var foot := origin
	var collider := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collider != null and collider.shape is CapsuleShape3D:
		var capsule := collider.shape as CapsuleShape3D
		foot = origin + (collider.global_position - player.global_position)
		foot.y -= capsule.height * collider.global_basis.y.length() * 0.5
	return foot + Vector3.UP * ground_clearance


func _update_particle_direction(particle: GPUParticles3D) -> void:
	var direction := -player.last_facing_direction
	direction.y = 0.25
	var material := particle.process_material as ParticleProcessMaterial
	if material != null:
		material.direction = particle.global_basis.inverse() * direction.normalized()


func _play_ground_burst(index: int) -> void:
	var ring: MeshInstance3D = _rings[index]
	var material := ring.material_override as StandardMaterial3D
	if _ring_tweens[index] != null and _ring_tweens[index].is_valid():
		_ring_tweens[index].kill()
	var radius: float = ring_radius if index == 0 else ring_radius * 0.7
	ring.global_position = _get_foot_position()
	ring.scale = Vector3(radius * 0.2, 0.12, radius * 0.2)
	material.albedo_color.a = 0.35 if index == 0 else 0.22
	ring.show()
	var tween := ring.create_tween().set_parallel()
	_ring_tweens[index] = tween
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "scale", Vector3(radius, 0.06, radius), 0.22)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.22)
	tween.chain().tween_callback(ring.hide)
	var burst: GPUParticles3D = _bursts[index]
	burst.global_position = ring.global_position + Vector3.UP * 0.08
	_update_particle_direction(burst)
	burst.restart()
	burst.emitting = true


### Signal dash started and finished
func _on_foxy_dash_started() -> void:
	if not is_instance_valid(player):
		return

	_update_particle_direction(dash_particle)
	dash_particle.global_position = _get_foot_position()
	dash_particle.emitting = true

	_dashing = true
	_streak_timer = 0.0
	set_process(true)
	_play_ground_burst(0)
	var shake := get_node_or_null("/root/ScreenShakeController")
	if shake != null and shake_pixels > 0.0:
		shake.request(shake_pixels, 0.1)


func _on_foxy_dash_finished(interrupted: bool) -> void:
	# Ngừng tạo bụi mới, bụi cũ vẫn tự mờ hết
	dash_particle.emitting = false
	_dashing = false
	set_process(false)
	if not interrupted and is_instance_valid(player):
		_play_ground_burst(1)
