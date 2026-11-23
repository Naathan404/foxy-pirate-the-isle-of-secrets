class_name MovingPlatform
extends Node3D

## Hits toggle endpoints, or follow Start -> Center -> End -> Center when enabled.
## A hit can change the destination while the platform is moving.

signal destination_reached(at_end: bool)

@export_range(0.1, 30.0, 0.1, "suffix:m/s") var move_speed := 3.0
## Start at Center; each lever hit advances the four-step route.
@export var center_stop_enabled: bool = false
## Ordered closed route. The first marker is the initial stop; overrides endpoint modes.
@export var route_marker_paths: Array[NodePath] = []

var _moving := false
var _target_end := false
var _next_center_stop_index := 0
var _target_marker: Marker3D
var _route_markers: Array[Marker3D] = []
var _route_index := 0
var _route_step_queue: Array[int] = []

@onready var platform: AnimatableBody3D = $Platform
@onready var start_marker: Marker3D = get_node_or_null("Start") as Marker3D
@onready var end_marker: Marker3D = get_node_or_null("End") as Marker3D
@onready var lever_hurtbox: HurtBox = get_node_or_null("Platform/Lever/HurtBox") as HurtBox
@onready var _lever_sprite: AnimatedSprite3D = (
	get_node_or_null("Platform/Lever/AnimatedSprite3D") as AnimatedSprite3D
)
@onready var _center_marker: Marker3D = get_node_or_null("Center") as Marker3D
@onready var _center_route: Array[Marker3D] = [
	start_marker,
	_center_marker,
	end_marker,
	_center_marker,
]


func _ready() -> void:
	if not route_marker_paths.is_empty():
		if not _load_route_markers():
			set_physics_process(false)
			return
		_target_marker = _route_markers[0]
	elif start_marker == null or end_marker == null:
		push_error("MovingPlatform: endpoint mode requires Start and End markers.")
		set_physics_process(false)
		return
	else:
		_target_marker = _center_marker if center_stop_enabled else start_marker
	if _route_markers.is_empty() and center_stop_enabled and _center_marker == null:
		push_error("MovingPlatform: center_stop_enabled requires a Center marker.")
		set_physics_process(false)
		return
	platform.position = _target_marker.position
	if lever_hurtbox != null:
		lever_hurtbox.actor = self
		lever_hurtbox.team = CombatTeams.ENEMY
		lever_hurtbox.collision_layer = CombatLayers.ENEMY_HURTBOX
		lever_hurtbox.collision_mask = CombatLayers.PLAYER_ATTACK
	if _lever_sprite != null:
		_lever_sprite.animation_finished.connect(_on_lever_animation_finished)
		_lever_sprite.play(&"idle")


func _physics_process(delta: float) -> void:
	if not _moving:
		return
	if not _route_markers.is_empty():
		_advance_route_movement(move_speed * delta)
		return
	var destination := _target_marker.position
	platform.position = platform.position.move_toward(destination, move_speed * delta)
	if platform.position.is_equal_approx(destination):
		platform.position = destination
		_moving = false
		if _target_marker != _center_marker:
			destination_reached.emit(_target_end)


func receive_damage(damage: DamageContext) -> float:
	if damage == null or damage.source_team != CombatTeams.PLAYER or damage.amount_hp <= 0.0:
		return 0.0
	if not _route_markers.is_empty():
		request_route_steps(1)
	elif center_stop_enabled:
		_request_stop(_center_route[_next_center_stop_index])
		_next_center_stop_index = (_next_center_stop_index + 1) % _center_route.size()
	else:
		request_destination(not _target_end)
	if _lever_sprite != null:
		_lever_sprite.stop()
		_lever_sprite.play(&"active")
	return damage.amount_hp


func _on_lever_animation_finished() -> void:
	if _lever_sprite.animation == &"active":
		_lever_sprite.play(&"idle")


func request_destination(at_end: bool) -> void:
	if not _route_markers.is_empty():
		var destination_index := _route_markers.size() - 1 if at_end else 0
		var planned_index := _route_index
		var current_step := _route_step_queue[0] if _moving else 0
		_route_step_queue.clear()
		# Finish a partially travelled edge before routing to an absolute endpoint.
		if current_step != 0:
			_route_step_queue.append(current_step)
			planned_index = posmod(planned_index + current_step, _route_markers.size())
		var steps := posmod(destination_index - planned_index, _route_markers.size())
		request_route_steps(steps)
		_target_end = at_end
		_moving = not _route_step_queue.is_empty()
		return
	_request_stop(end_marker if at_end else start_marker)


## Positive counts advance around the route; negative counts walk it backwards.
## Preserve intermediate corners and queue new hits after travel already requested.
func request_route_steps(count: int) -> bool:
	if count == 0 or _route_markers.size() < 2:
		return false
	var direction := 1 if count > 0 else -1
	for step in absi(count):
		_route_step_queue.append(direction)
	_moving = true
	return true


func is_targeting_end() -> bool:
	return _target_end


func _request_stop(marker: Marker3D) -> void:
	_target_marker = marker
	_target_end = marker == end_marker
	_moving = not platform.position.is_equal_approx(marker.position)


func _load_route_markers() -> bool:
	if route_marker_paths.size() < 2:
		push_error("MovingPlatform: a closed route needs at least two markers.")
		return false
	for marker_path in route_marker_paths:
		var marker := get_node_or_null(marker_path) as Marker3D
		if marker == null or marker in _route_markers:
			push_error("MovingPlatform: route marker missing or duplicated: %s" % marker_path)
			_route_markers.clear()
			return false
		_route_markers.append(marker)
	return true


func _advance_route_movement(distance_remaining: float) -> void:
	while not _route_step_queue.is_empty():
		var next_index := posmod(_route_index + _route_step_queue[0], _route_markers.size())
		var destination := _route_markers[next_index].position
		var distance := platform.position.distance_to(destination)
		if distance > distance_remaining:
			platform.position = platform.position.move_toward(destination, distance_remaining)
			return
		platform.position = destination
		distance_remaining -= distance
		_route_index = next_index
		_route_step_queue.pop_front()
	_moving = false
