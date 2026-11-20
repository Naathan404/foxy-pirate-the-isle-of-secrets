class_name FireflyEmberMote
extends Node3D
## Đốm phấn sáng đom đóm bay rơi xuống mặt đất: tạo vệt sao, bóng tròn và nở
## thành một FireflyPollenField phát quang.

signal landed(landing_position: Vector3, field: FireflyPollenField)

const FIELD_SCRIPT := preload("res://gameplay/enemies/firefly/firefly_pollen_field.gd")
const SPARK_MOTE_TEXTURE := preload("res://assets/sprites/enemies/firefly/firefly_spark_mote.png")

const MIN_FLIGHT_SECONDS := 0.16

var _source: Node
var _source_team: int = CombatTeams.ENEMY
var _start_position: Vector3 = Vector3.ZERO
var _landing_position: Vector3 = Vector3.ZERO
var _flight_duration_seconds: float = 0.42
var _arc_height_meters: float = 0.4
var _field_radius_meters: float = 0.72
var _field_duration_seconds: float = 2.6
var _tick_interval_seconds: float = 0.75
var _tick_damage_hp: float = 0.45
var _elapsed_seconds: float = 0.0
var _finished: bool = false

var _orb_sprite: Sprite3D
var _trail_sparks: GPUParticles3D
var _mote_light: OmniLight3D


static func collect_active_field_spots(tree_owner: Node) -> Array[Dictionary]:
	var spots: Array[Dictionary] = []
	if not is_instance_valid(tree_owner) or not tree_owner.is_inside_tree():
		return spots
	for node in tree_owner.get_tree().get_nodes_in_group(FIELD_SCRIPT.FIELD_GROUP):
		var field := node as FireflyPollenField
		if field == null or not is_instance_valid(field) or field.is_fading():
			continue
		spots.append({"pos": field.global_position, "radius": field.get_radius()})
	return spots


func setup(
	owner_node: Node,
	owner_team: int,
	start_position: Vector3,
	landing_position: Vector3,
	flight_seconds: float,
	arc_height_meters: float,
	field_radius_meters: float,
	field_duration_seconds: float,
	tick_interval_seconds: float,
	tick_damage_hp: float
) -> void:
	_source = owner_node
	_source_team = owner_team
	_start_position = start_position
	_landing_position = landing_position
	_flight_duration_seconds = maxf(MIN_FLIGHT_SECONDS, flight_seconds)
	_arc_height_meters = maxf(0.0, arc_height_meters)
	_field_radius_meters = field_radius_meters
	_field_duration_seconds = field_duration_seconds
	_tick_interval_seconds = tick_interval_seconds
	_tick_damage_hp = tick_damage_hp


func _ready() -> void:
	_build_visuals()
	global_position = _start_position
	_update_flight_pose(0.0)


func _physics_process(delta: float) -> void:
	if _finished:
		return
	_elapsed_seconds += maxf(0.0, delta)
	var progress := clampf(_elapsed_seconds / _flight_duration_seconds, 0.0, 1.0)
	_update_flight_pose(progress)
	if progress >= 1.0:
		_detonate_on_ground()


func _update_flight_pose(progress: float) -> void:
	var pos := _start_position.lerp(_landing_position, progress)
	var arc := 4.0 * _arc_height_meters * progress * (1.0 - progress)
	pos.y += arc
	global_position = pos
	if is_instance_valid(_orb_sprite):
		var pulse := 0.92 + 0.14 * sin(_elapsed_seconds * 18.0)
		_orb_sprite.scale = Vector3.ONE * pulse


func _detonate_on_ground() -> void:
	if _finished:
		return
	_finished = true
	var parent := get_parent()
	var spawned_field: FireflyPollenField = null
	if is_instance_valid(parent) and not parent.is_queued_for_deletion():
		spawned_field = FIELD_SCRIPT.new() as FireflyPollenField
		spawned_field.setup(
			_source,
			_source_team,
			_field_radius_meters,
			_field_duration_seconds,
			_tick_interval_seconds,
			_tick_damage_hp
		)
		parent.add_child(spawned_field)
		spawned_field.global_position = _landing_position
		_spawn_landing_twinkle(parent)
	landed.emit(_landing_position, spawned_field)
	queue_free()


func _spawn_landing_twinkle(parent: Node) -> void:
	var burst := CPUParticles3D.new()
	burst.name = "EmberLandingTwinkle"
	burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	burst.amount = 10
	burst.lifetime = 0.42
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.emitting = false
	burst.local_coords = false
	burst.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	burst.emission_sphere_radius = 0.18
	burst.direction = Vector3.UP
	burst.spread = 70.0
	burst.initial_velocity_min = 1.2
	burst.initial_velocity_max = 2.6
	burst.gravity = Vector3(0.0, -3.5, 0.0)
	burst.scale_amount_min = 0.18
	burst.scale_amount_max = 0.34
	burst.mesh = FIELD_SCRIPT.create_spark_quad(Vector2(0.38, 0.38), true)
	parent.add_child(burst)
	burst.global_position = _landing_position + Vector3.UP * 0.12
	burst.emitting = true
	var cleanup := burst.create_tween()
	cleanup.tween_interval(0.55)
	cleanup.tween_callback(burst.queue_free)


func _build_visuals() -> void:
	_orb_sprite = Sprite3D.new()
	_orb_sprite.name = "EmberOrbSprite"
	_orb_sprite.texture = SPARK_MOTE_TEXTURE
	_orb_sprite.pixel_size = 0.0024
	_orb_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_orb_sprite.shaded = false
	_orb_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_orb_sprite.modulate = Color(1.0, 0.94, 0.46, 1.0)
	add_child(_orb_sprite)

	_mote_light = OmniLight3D.new()
	_mote_light.name = "EmberMoteLight"
	_mote_light.light_color = Color(1.0, 0.85, 0.32)
	_mote_light.light_energy = 0.75
	_mote_light.omni_range = 1.8
	_mote_light.shadow_enabled = false
	add_child(_mote_light)

	_trail_sparks = GPUParticles3D.new()
	_trail_sparks.name = "EmberTrailSparks"
	_trail_sparks.amount = 14
	_trail_sparks.lifetime = 0.36
	_trail_sparks.local_coords = false
	_trail_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trail_sparks.visibility_aabb = AABB(Vector3(-8.0, -8.0, -8.0), Vector3(16.0, 16.0, 16.0))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.08
	process.direction = Vector3.UP
	process.spread = 45.0
	process.initial_velocity_min = 0.15
	process.initial_velocity_max = 0.45
	process.gravity = Vector3(0.0, 0.35, 0.0)
	process.scale_min = 0.35
	process.scale_max = 0.7
	process.color_ramp = FIELD_SCRIPT.create_fade_ramp_texture(
		Color(1.0, 0.96, 0.55, 0.92), Color(1.0, 0.65, 0.18, 0.0)
	)
	_trail_sparks.process_material = process
	_trail_sparks.draw_pass_1 = FIELD_SCRIPT.create_spark_quad(Vector2(0.24, 0.24), true)
	add_child(_trail_sparks)
