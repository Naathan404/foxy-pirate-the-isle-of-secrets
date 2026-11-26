class_name TideSandbar
extends Node
## A sandbar between two pieces of an island: walkable while the tide is out, gone while it is
## in. The bar is a floor shape of the room's ground, so the island boundary closes across it
## when it floods and opens again when it dries.
##
## When the water gets deep enough the bar closes. Foxy still on it is washed to the nearest
## shore first, with a hit reaction, and the bar closes behind him. Enemies left on it sink.

const PUSH_DURATION_SECONDS := 0.6
## Share of the push distance actually covered, since the push slows down as it fades.
const PUSH_DISTANCE_RATIO := 0.7
const PUSH_MARGIN_METERS := 1.2

@export var controller: FlatTideController
## Floor of the bar: a shape under the room's `Environment/BaseGround…/StaticBody3D`.
@export var bar_floor: CollisionShape3D
## Landing points on each shore; a washed-off Foxy goes to the nearest one.
@export var shores: Array[Marker3D] = []
## The bar closes once the tide covers this much of its zone, and reopens below the other.
@export_range(0.0, 1.0, 0.01) var close_coverage: float = 0.55
@export_range(0.0, 1.0, 0.01) var open_coverage: float = 0.1

var _open: bool = true
var _closing: bool = false


func _ready() -> void:
	if controller == null or bar_floor == null or shores.is_empty() or shores.has(null):
		push_error("TideSandbar: assign the controller, the bar floor and its shore points.")
		return
	controller.coverage_changed.connect(_on_coverage_changed)
	_set_bar_open(controller.coverage < close_coverage)


func is_open() -> bool:
	return _open


func _on_coverage_changed(value: float) -> void:
	if _open and not _closing and value >= close_coverage:
		_close()
	elif not _open and value <= open_coverage:
		_set_bar_open(true)


func _close() -> void:
	var player := get_node("/root/GameManager").player as Player
	if is_instance_valid(player) and not player.dead and _is_on_bar(player.global_position):
		_closing = true
		_wash_ashore(player)
		await get_tree().create_timer(PUSH_DURATION_SECONDS, false).timeout
		_closing = false
		if not is_inside_tree():
			return
	_set_bar_open(false)


func _wash_ashore(player: Player) -> void:
	var target := shores[0].global_position
	for shore in shores:
		if (
			shore.global_position.distance_to(player.global_position)
			< target.distance_to(player.global_position)
		):
			target = shore.global_position
	var offset := target - player.global_position
	offset.y = 0.0
	var distance := offset.length() + PUSH_MARGIN_METERS
	player.apply_environment_knockback(
		offset, distance / (PUSH_DURATION_SECONDS * PUSH_DISTANCE_RATIO), PUSH_DURATION_SECONDS
	)


func _set_bar_open(open: bool) -> void:
	_open = open
	bar_floor.set_deferred("disabled", not open)
	var room := BaseRoom.find_room(self)
	if room != null:
		room.queue_boundary_rebuild()


func _is_on_bar(point: Vector3) -> bool:
	var local := bar_floor.global_transform.affine_inverse() * point
	var shape := bar_floor.shape
	if shape is BoxShape3D:
		var half := (shape as BoxShape3D).size * 0.5
		return absf(local.x) <= half.x and absf(local.z) <= half.z
	if shape is ConvexPolygonShape3D:
		var outline := PackedVector2Array()
		for vertex: Vector3 in (shape as ConvexPolygonShape3D).points:
			outline.append(Vector2(vertex.x, vertex.z))
		return Geometry2D.is_point_in_polygon(
			Vector2(local.x, local.z), Geometry2D.convex_hull(outline)
		)
	return false
