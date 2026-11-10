class_name CrabEgg
extends Node3D

const SMOKE_SCENE := preload("res://world/objects/destructible_smoke.tscn")
const CRAB_PATH := "res://gameplay/enemies/crab/crab.tscn"

@export_range(0.0, 30.0, 0.1, "suffix:s") var hatch_delay: float = 2.0
@export_range(0.0, 10.0, 0.1, "suffix:s") var warning_duration: float = 0.7
@export_range(0.0, 1.0, 0.01, "suffix:m") var shake_distance: float = 0.08
@export_range(0.0, 50.0, 0.5, "suffix:Hz") var shake_frequency: float = 15.0

var _start: Vector3
var _ground: Vector3
var _duration: float = 0.8
var _arc_height: float = 2.0
var _elapsed: float = 0.0
var _hatched: bool = false
var _landed: bool = false
var _incubation_elapsed: float = 0.0
var _hp: float = 1.0

@onready var shadow: MeshInstance3D = $Shadow
@onready var sprite: Sprite3D = $Sprite3D
@onready var body: StaticBody3D = $Body
@onready var hurtbox: HurtBox = $HurtBox
@onready var _sprite_origin: Vector3 = sprite.position


func setup(start: Vector3, ground: Vector3, duration: float, arc_height: float) -> void:
	_start = start
	_ground = ground
	_duration = maxf(0.1, duration)
	_arc_height = maxf(0.0, arc_height)


func _ready() -> void:
	global_position = _start
	hurtbox.actor = self
	hurtbox.team = CombatTeams.ENEMY
	hurtbox.enabled = false
	hurtbox.collision_layer = 0
	shadow.top_level = true
	shadow.global_position = _ground + Vector3.UP * 0.025


func _physics_process(delta: float) -> void:
	if _hatched:
		return
	if _landed:
		_incubation_elapsed += maxf(0.0, delta)
		var delay := maxf(0.0, hatch_delay)
		var warning := clampf(warning_duration, 0.0, delay)
		if warning > 0.0 and _incubation_elapsed >= delay - warning:
			sprite.position.x = _sprite_origin.x + sin(_incubation_elapsed * shake_frequency * TAU) * shake_distance
		if _incubation_elapsed >= delay:
			_hatch()
		return
	_elapsed = minf(_duration, _elapsed + maxf(0.0, delta))
	var t := _elapsed / _duration
	var destination := _ground + Vector3.UP * 0.5
	global_position = _start.lerp(destination, t) + Vector3.UP * sin(PI * t) * _arc_height
	var height := maxf(0.0, global_position.y - _ground.y)
	var shadow_size := clampf(1.0 - height * 0.12, 0.45, 1.0)
	shadow.scale = Vector3(0.8, 0.02, 0.45) * shadow_size
	if t >= 1.0:
		_landed = true
		hurtbox.enabled = true
		hurtbox.collision_layer = CombatLayers.ENEMY_HURTBOX
		if hatch_delay <= 0.0:
			_hatch()


func receive_damage(damage: DamageContext) -> float:
	if not _landed or _hatched or damage == null or damage.source_team != CombatTeams.PLAYER or damage.amount_hp <= 0.0:
		return 0.0
	var applied := minf(_hp, damage.amount_hp)
	_hp -= applied
	if _hp <= 0.0:
		_hatched = true
		hurtbox.enabled = false
		_spawn_smoke(global_position)
		queue_free()
	return applied


func _hatch() -> void:
	if _hatched:
		return
	_hatched = true
	var parent := get_parent()
	if not is_instance_valid(parent) or parent.is_queued_for_deletion():
		queue_free()
		return
	if _landing_is_clear():
		var crab_scene := load(CRAB_PATH) as PackedScene
		if crab_scene != null:
			var crab := crab_scene.instantiate() as Crab
			parent.add_child(crab)
			crab.global_position = _ground
			crab.home_position = _ground
		_spawn_smoke(_ground + Vector3.UP * 0.2)
	queue_free()


func _spawn_smoke(position: Vector3) -> void:
	var parent := get_parent()
	if not is_instance_valid(parent) or parent.is_queued_for_deletion():
		return
	var smoke := SMOKE_SCENE.instantiate() as GPUParticles3D
	parent.add_child(smoke)
	smoke.global_position = position
	smoke.restart()
	smoke.emitting = true


func _landing_is_clear() -> bool:
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(
		_ground + Vector3.UP * 0.5, _ground - Vector3.UP * 0.5, CombatLayers.WORLD
	)
	if space.intersect_ray(ray).is_empty():
		return false
	var shape := CylinderShape3D.new()
	shape.radius = 0.85
	shape.height = 1.7
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, _ground + Vector3.UP * 0.9)
	query.collision_mask = CombatLayers.WORLD | CombatLayers.ENEMY_BODY | CombatLayers.PLAYER_BODY
	query.exclude = [body.get_rid()]
	return space.intersect_shape(query, 1).is_empty()
