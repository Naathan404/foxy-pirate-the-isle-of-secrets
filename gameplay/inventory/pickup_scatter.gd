class_name PickupScatter
extends Node
## Shared landing-safe flight; pickup owners decide when collection and idle behavior resume.

signal landed

@export var visual: Node3D
@export var trail_pool: LootTrailPool
@export_range(0.0, 4.0, 0.05) var distance_min: float = 0.75
@export_range(0.0, 4.0, 0.05) var distance_max: float = 1.65
@export var trail_color: Color = Color(0.35, 0.8, 1.0, 1.0)
@export_range(0.01, 0.3, 0.005) var trail_width: float = 0.08

var _trail: LootTrail
var _trail_lease: int = 0
var _origin: Vector3
var _destination: Vector3
var _height: float = 0.9
var _duration: float = 0.5
var _elapsed: float = 0.0

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
	_height = maxf(0.0, height)
	_duration = maxf(0.05, duration)
	_elapsed = 0.0
	_pickup.global_position = _origin
	var pool := trail_pool if is_instance_valid(trail_pool) else LootTrailPool.for_scene(self)
	if pool != null and is_instance_valid(visual):
		_trail = pool.acquire(visual, trail_color, trail_width)
		if _trail != null:
			_trail_lease = _trail.get_lease()
	set_process(true)


func cancel() -> void:
	set_process(false)
	if is_instance_valid(_trail):
		_trail.finish(_trail_lease)
	_trail = null


func _process(delta: float) -> void:
	_elapsed = minf(_duration, _elapsed + maxf(0.0, delta))
	var progress := _elapsed / _duration
	_pickup.global_position = (
		_origin.lerp(_destination, progress)
		+ Vector3.UP * (4.0 * _height * progress * (1.0 - progress))
	)
	if _elapsed >= _duration:
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
