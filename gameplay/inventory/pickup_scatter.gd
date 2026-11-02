class_name PickupScatter
extends Node
## Shared landing-safe flight; pickup owners decide when collection and idle behavior resume.

signal landed

@export var visual: Node3D
@export var trail_pool: LootTrailPool
@export_range(0.0, 4.0, 0.05) var distance_min: float = 1.0
@export_range(0.0, 4.0, 0.05) var distance_max: float = 2.2
@export var trail_color: Color = Color(0.35, 0.8, 1.0, 1.0)
@export_range(0.01, 0.3, 0.005) var trail_width: float = 0.08

@export_group("Flight Feel")
@export_range(0.0, 1.0, 0.05) var launch_height: float = 0.35
@export_range(0.5, 2.0, 0.05) var arc_height_multiplier: float = 1.35
@export_range(0.0, 0.5, 0.01) var height_variation: float = 0.2
@export_range(0.0, 0.4, 0.01) var duration_variation: float = 0.12
@export_range(0.0, 1.0, 0.05) var tumble_strength: float = 0.18
@export_range(0.0, 0.5, 0.01) var bounce_height: float = 0.16
@export_range(0.0, 0.4, 0.01) var bounce_seconds: float = 0.16

var _trail: LootTrail
var _trail_lease: int = 0
var _origin: Vector3
var _destination: Vector3
var _height: float = 0.9
var _duration: float = 0.5
var _elapsed: float = 0.0
var _bouncing: bool = false
var _spin_turns: float = 1.0
var _visual_rest_scale: Vector3 = Vector3.ONE
var _has_visual_scale: bool = false

@onready var _pickup: Node3D = get_parent() as Node3D


func _ready() -> void:
	set_process(false)


func launch(height: float, duration: float, direction: Vector3 = Vector3.ZERO) -> void:
	cancel()
	_origin = _pickup.global_position
	var floor_hit := _find_floor(_origin)
	if not floor_hit.is_empty():
		_origin = floor_hit.position
	var horizontal := Vector3(direction.x, 0.0, direction.z)
	if horizontal.is_zero_approx():
		var angle := randf() * TAU
		horizontal = Vector3(cos(angle), 0.0, sin(angle))
	var distance := randf_range(minf(distance_min, distance_max), maxf(distance_min, distance_max))
	_destination = _find_destination(horizontal.normalized(), distance)
	_height = maxf(0.0, height) * arc_height_multiplier
	_height *= randf_range(1.0 - height_variation, 1.0 + height_variation)
	_duration = maxf(
		0.05, duration * randf_range(1.0 - duration_variation, 1.0 + duration_variation)
	)
	_elapsed = 0.0
	_bouncing = false
	_spin_turns = randf_range(1.25, 2.25)
	_pickup.global_position = _origin + Vector3.UP * launch_height
	if is_instance_valid(visual):
		_visual_rest_scale = visual.scale
		_has_visual_scale = true
	var pool := trail_pool if is_instance_valid(trail_pool) else LootTrailPool.for_scene(self)
	if pool != null and is_instance_valid(visual):
		_trail = pool.acquire(visual, trail_color, trail_width)
		if _trail != null:
			_trail_lease = _trail.get_lease()
	set_process(true)


func cancel() -> void:
	set_process(false)
	_bouncing = false
	_stop_trail(false)
	if _has_visual_scale and is_instance_valid(visual):
		visual.scale = _visual_rest_scale
	_has_visual_scale = false


func _stop_trail(show_impact: bool) -> void:
	if is_instance_valid(_trail):
		_trail.finish(_trail_lease, show_impact)
	_trail = null


func _process(delta: float) -> void:
	if _bouncing:
		_update_bounce(delta)
		return
	_elapsed = minf(_duration, _elapsed + maxf(0.0, delta))
	var progress := _elapsed / _duration
	var travel := 1.0 - pow(1.0 - progress, 1.5)
	var arc := maxf(0.0, sin(PI * pow(progress, 0.7)))
	_pickup.global_position = (
		_origin.lerp(_destination, travel)
		+ Vector3.UP * (launch_height * (1.0 - progress) + _height * arc)
	)
	_update_flight_visual(progress)
	if _elapsed >= _duration:
		_pickup.global_position = _destination
		_stop_trail(true)
		if bounce_seconds > 0.0 and bounce_height > 0.0:
			_bouncing = true
			_elapsed = 0.0
		else:
			_complete_landing()


func _update_flight_visual(progress: float) -> void:
	if not is_instance_valid(visual):
		return
	var pop := 1.0 + sin(progress * PI) * 0.12
	var tumble := 0.3 + absf(cos(progress * TAU * _spin_turns)) * 0.7
	visual.scale = (
		_visual_rest_scale
		* Vector3(
			lerpf(1.0, tumble, tumble_strength) * pop,
			(1.0 + exp(-progress * 14.0) * 0.18) * pop,
			1.0
		)
	)


func _update_bounce(delta: float) -> void:
	_elapsed = minf(bounce_seconds, _elapsed + maxf(0.0, delta))
	var progress := _elapsed / bounce_seconds
	_pickup.global_position = (
		_destination + Vector3.UP * (4.0 * bounce_height * progress * (1.0 - progress))
	)
	if is_instance_valid(visual):
		visual.scale = (
			_visual_rest_scale
			* Vector3(lerpf(1.22, 1.0, progress), lerpf(0.72, 1.0, progress), 1.0)
		)
	if _elapsed >= bounce_seconds:
		_complete_landing()


func _complete_landing() -> void:
	_pickup.global_position = _destination
	cancel()
	landed.emit()


func _find_destination(direction: Vector3, distance: float) -> Vector3:
	var space := _pickup.get_world_3d().direct_space_state
	for attempt in 3:
		var candidate := _origin + direction * distance * pow(0.5, attempt)
		var wall_query := PhysicsRayQueryParameters3D.create(
			_origin + Vector3.UP * 0.4, candidate + Vector3.UP * 0.4, CombatLayers.WORLD
		)
		var wall_hit := space.intersect_ray(wall_query)
		if not wall_hit.is_empty():
			var normal: Vector3 = wall_hit.normal
			candidate = wall_hit.position + normal * 0.25
			candidate.y = _origin.y
		var floor_hit := _find_floor(candidate)
		if not floor_hit.is_empty():
			var floor_position: Vector3 = floor_hit.position
			if absf(floor_position.y - _origin.y) <= 1.0:
				return floor_position
	return _origin


func _find_floor(at: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(
		at + Vector3.UP, at + Vector3.DOWN * 3.0, CombatLayers.WORLD
	)
	var hit := _pickup.get_world_3d().direct_space_state.intersect_ray(query)
	var normal: Vector3 = hit.get("normal", Vector3.ZERO)
	return hit if normal.y >= 0.65 else {}


func _exit_tree() -> void:
	cancel()
