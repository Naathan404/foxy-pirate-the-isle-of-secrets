class_name PlayerAttraction
extends Node
## Reusable proximity pull. Owners provide eligibility and commit rewards on arrival.

signal attraction_started(target: Node3D)
signal attraction_cancelled
signal arrived(target: Node3D)
signal completed

@export var detector: Area3D
@export var moving_root: Node3D
@export var anchor: Node3D
@export var detection_shape: CollisionShape3D
@export var target_group: StringName = &"player"
@export_range(0.2, 8.0, 0.1) var attraction_radius: float = 2.4
@export var target_offset: Vector3 = Vector3(0.0, 0.8, 0.0)
@export_range(1.0, 30.0, 0.5) var initial_speed: float = 4.0
@export_range(1.0, 40.0, 0.5) var max_speed: float = 18.0
@export_range(1.0, 100.0, 1.0) var acceleration: float = 55.0
@export_range(0.02, 0.5, 0.01) var arrival_distance: float = 0.12
@export_range(0.05, 1.0, 0.01) var scan_interval: float = 0.12
@export var require_line_of_sight: bool = true
@export_flags_3d_physics var obstacle_mask: int = 1
@export_range(0.0, 0.3, 0.01) var capture_seconds: float = 0.1

var _permission: Callable
var _enabled: bool = false
var _target: Node3D
var _origin: Transform3D
var _speed: float = 0.0
var _scan_elapsed: float = 0.0
var _awaiting_commit: bool = false
var _finishing: bool = false
var _capture_elapsed: float = 0.0
var _rest_scale: Vector3 = Vector3.ONE
var _has_rest_scale: bool = false


func _ready() -> void:
	if detection_shape != null and detection_shape.shape is SphereShape3D:
		# The scene's original shape may be shared by every pooled instance.
		var sphere := detection_shape.shape.duplicate() as SphereShape3D
		sphere.radius = attraction_radius
		detection_shape.shape = sphere
	if is_instance_valid(detector):
		detector.body_entered.connect(_on_body_entered)
	reset()


func configure(permission: Callable) -> void:
	_permission = permission


func set_enabled(value: bool) -> void:
	if not value:
		reset()
		return
	if not is_instance_valid(detector) or not is_instance_valid(moving_root) or _finishing:
		return
	_enabled = true
	_scan_elapsed = 0.0
	_set_detection(true)
	set_physics_process(true)


func reset() -> void:
	_enabled = false
	_target = null
	_awaiting_commit = false
	_finishing = false
	_capture_elapsed = 0.0
	_scan_elapsed = 0.0
	_speed = 0.0
	if _has_rest_scale and is_instance_valid(anchor):
		anchor.scale = _rest_scale
	_has_rest_scale = false
	_set_detection(false)
	set_physics_process(false)
	set_process(false)


func try_attract(target: Node3D) -> bool:
	if not _enabled or _awaiting_commit or _finishing or is_instance_valid(_target):
		return false
	if not _is_allowed(target) or not _has_clear_path(target):
		return false
	_origin = moving_root.global_transform
	_target = target
	_speed = initial_speed
	attraction_started.emit(target)
	if not _enabled or _target != target:
		return false
	if is_instance_valid(anchor):
		_rest_scale = anchor.scale
		_has_rest_scale = true
	return true


func retry() -> void:
	if not _enabled:
		return
	moving_root.global_transform = _origin
	if _has_rest_scale and is_instance_valid(anchor):
		anchor.scale = _rest_scale
	_target = null
	_awaiting_commit = false
	_scan_elapsed = scan_interval
	_speed = 0.0
	set_physics_process(true)
	attraction_cancelled.emit()


## Called only after the owner successfully grants the item, Gold, XP, etc.
func complete() -> void:
	if not _awaiting_commit:
		return
	_awaiting_commit = false
	_enabled = false
	_finishing = true
	_capture_elapsed = 0.0
	_set_detection(false)
	set_physics_process(false)
	set_process(true)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_target):
		if _speed > 0.0:
			retry()
		_scan_elapsed -= maxf(0.0, delta)
		if _scan_elapsed <= 0.0:
			_scan_elapsed = scan_interval
			_find_target()
		return
	if not _is_allowed(_target) or not _has_clear_path(_target):
		retry()
		return
	_speed = move_toward(_speed, max_speed, acceleration * maxf(0.0, delta))
	var destination := _destination_for(_target)
	moving_root.global_position = moving_root.global_position.move_toward(
		destination, _speed * maxf(0.0, delta)
	)
	if (
		moving_root.global_position.distance_squared_to(destination)
		<= arrival_distance * arrival_distance
	):
		_awaiting_commit = true
		set_physics_process(false)
		arrived.emit(_target)


func _process(delta: float) -> void:
	if not _finishing:
		return
	_capture_elapsed += maxf(0.0, delta)
	var progress := minf(1.0, _capture_elapsed / capture_seconds) if capture_seconds > 0.0 else 1.0
	if is_instance_valid(_target):
		moving_root.global_position = _destination_for(_target)
	if _has_rest_scale and is_instance_valid(anchor):
		anchor.scale = _rest_scale * lerpf(1.0, 0.08, progress)
	if progress >= 1.0:
		_finishing = false
		_target = null
		set_process(false)
		completed.emit()


func _on_body_entered(body: Node3D) -> void:
	try_attract(body)


func _find_target() -> void:
	var nearest: Node3D
	var nearest_distance := INF
	for body: Node3D in detector.get_overlapping_bodies():
		if not _is_allowed(body):
			continue
		var distance := moving_root.global_position.distance_squared_to(body.global_position)
		if distance < nearest_distance and _has_clear_path(body):
			nearest = body
			nearest_distance = distance
	if nearest != null:
		try_attract(nearest)


func _is_allowed(target: Node3D) -> bool:
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		return false
	if not target_group.is_empty() and not target.is_in_group(target_group):
		return false
	return _permission.is_null() or (_permission.is_valid() and bool(_permission.call(target)))


func _destination_for(target: Node3D) -> Vector3:
	var anchor_offset := Vector3.ZERO
	if is_instance_valid(anchor):
		anchor_offset = anchor.global_position - moving_root.global_position
	return target.global_position + target_offset - anchor_offset


func _has_clear_path(target: Node3D) -> bool:
	if not require_line_of_sight:
		return true
	var origin := (
		anchor.global_position if is_instance_valid(anchor) else moving_root.global_position
	)
	var destination := target.global_position + target_offset
	if origin.distance_squared_to(destination) < 0.0001:
		return true
	var query := PhysicsRayQueryParameters3D.create(origin, destination, obstacle_mask)
	var excluded: Array[RID] = []
	if moving_root is CollisionObject3D:
		excluded.append((moving_root as CollisionObject3D).get_rid())
	if target is CollisionObject3D:
		excluded.append((target as CollisionObject3D).get_rid())
	query.exclude = excluded
	return moving_root.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _set_detection(value: bool) -> void:
	if is_instance_valid(detector):
		detector.set_deferred("monitoring", value)
	if is_instance_valid(detection_shape):
		detection_shape.set_deferred("disabled", not value)
