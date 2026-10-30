class_name PushableCrate
extends CharacterBody3D
## A controlled puzzle prop: one movement request per physics tick, no accumulated impulse.

@export_range(0.1, 10.0, 0.1) var push_speed: float = 2.0
@export var push_enabled: bool = true
## Optional: assigned crates can only be pushed during LOW tide.
@export var tide_controller: TideController

@export_group("Floating")
@export var float_enabled: bool = true
## Waterline above the crate's base, measured in world units.
@export_range(0.0, 2.0, 0.05) var float_draft: float = 0.2
@export_range(0.1, 20.0, 0.1) var float_speed: float = 6.0

var is_floating: bool = false

var _push_direction: Vector3 = Vector3.ZERO
var _requested_speed: float = 0.0

@onready var _body_shape: CollisionShape3D = $CollisionShape3D
@onready var _ground_snap_length: float = floor_snap_length


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		_push_direction = Vector3.ZERO


func request_push(direction: Vector3, speed_limit: float = -1.0) -> bool:
	if not _can_be_pushed():
		return false
	var horizontal := Vector3(direction.x, 0.0, direction.z)
	if horizontal.is_zero_approx():
		return false
	_push_direction = horizontal.normalized()
	_requested_speed = push_speed if speed_limit < 0.0 else minf(push_speed, maxf(0.0, speed_limit))
	return true


func _physics_process(delta: float) -> void:
	_update_float_velocity(delta)
	# Let the box touch land physically instead of snapping down before the water recedes.
	floor_snap_length = 0.0 if is_floating else _ground_snap_length
	var direction := _push_direction if _can_be_pushed() else Vector3.ZERO
	_push_direction = Vector3.ZERO
	velocity.x = direction.x * _requested_speed
	velocity.z = direction.z * _requested_speed
	_requested_speed = 0.0
	if not is_floating:
		if not is_on_floor():
			velocity += get_gravity() * delta
		elif velocity.y < 0.0:
			velocity.y = 0.0
	move_and_slide()


func _update_float_velocity(delta: float) -> void:
	var was_floating := is_floating
	is_floating = false
	if was_floating:
		velocity.y = minf(velocity.y, 0.0)
	if not float_enabled or not is_instance_valid(tide_controller) or delta <= 0.0:
		return
	var water := tide_controller.water
	if not is_instance_valid(water) or not _is_over_water(water):
		return
	var water_height := tide_controller.get_water_height()
	var bottom_height := _get_bottom_height()
	var bottom_offset := bottom_height - global_position.y
	var target_height := water_height - float_draft - bottom_offset
	if water_height <= bottom_height:
		return
	# A grounded crate starts rising only when water can support its draft.
	if is_on_floor() and target_height <= global_position.y + 0.002:
		return
	if not was_floating and target_height <= global_position.y + 0.002:
		return
	is_floating = true
	velocity.y = clampf((target_height - global_position.y) / delta, -float_speed, float_speed)


func _get_bottom_height() -> float:
	var box := _body_shape.shape as BoxShape3D
	if box == null:
		return global_position.y
	var half_size := box.size * 0.5
	var basis := _body_shape.global_basis
	var extent := absf(basis.x.y) * half_size.x + absf(basis.y.y) * half_size.y
	extent += absf(basis.z.y) * half_size.z
	return _body_shape.global_position.y - extent


func _is_over_water(water: Node3D) -> bool:
	var surface := water as MeshInstance3D
	if surface == null or surface.mesh == null:
		return true
	var point := surface.to_local(global_position)
	var bounds := surface.get_aabb()
	return (
		point.x >= bounds.position.x
		and point.x <= bounds.end.x
		and point.z >= bounds.position.z
		and point.z <= bounds.end.z
	)


func _can_be_pushed() -> bool:
	return (
		push_enabled
		and not is_floating
		and is_on_floor()
		and (
			not is_instance_valid(tide_controller)
			or tide_controller.state == TideController.State.LOW
		)
	)
