@tool
extends Node3D

## Configure the four paths and choose destination exits from this room's Inspector.
## A room always keeps at least one path open.

const UP := 1
const RIGHT := 2
const DOWN := 4
const LEFT := 8
const EXIT_CATALOG := preload("res://world/components/scene_exit_catalog.gd")

@export_tool_button("Refresh destination exits", "Reload") var refresh_destination_exits: Callable:
	get:
		return _refresh_destination_inspector

@export_group("Void")
## Reload when Foxy falls below this height relative to the room origin.
@export var void_reload_enabled: bool = true
@export var void_height: float = -6.0

@export_group("Ground boundaries")
## Openings in room-local X/Z coordinates, for example at moving platform docks.
@export var boundary_openings: Array[Rect2] = []
@export var boundary_enabled: bool = true

@export_group("Exits")
@export_flags("Up", "Right", "Down", "Left") var open_exits: int = UP | RIGHT | DOWN | LEFT:
	set(value):
		if value == 0:
			push_warning("BaseRoom needs at least one open exit.")
			return
		open_exits = value
		_queue_refresh()

@export_subgroup("Up")
@export var up_trigger_id: StringName = &"up":
	set(value):
		up_trigger_id = value
		_queue_refresh()
@export_file("*.tscn") var up_destination_scene: String = "":
	set(value):
		up_destination_scene = value
		_queue_refresh()
@export var up_destination_trigger_id: StringName = &"down":
	set(value):
		up_destination_trigger_id = value
		_queue_refresh()

@export_subgroup("Right")
@export var right_trigger_id: StringName = &"right":
	set(value):
		right_trigger_id = value
		_queue_refresh()
@export_file("*.tscn") var right_destination_scene: String = "":
	set(value):
		right_destination_scene = value
		_queue_refresh()
@export var right_destination_trigger_id: StringName = &"left":
	set(value):
		right_destination_trigger_id = value
		_queue_refresh()

@export_subgroup("Down")
@export var down_trigger_id: StringName = &"down":
	set(value):
		down_trigger_id = value
		_queue_refresh()
@export_file("*.tscn") var down_destination_scene: String = "":
	set(value):
		down_destination_scene = value
		_queue_refresh()
@export var down_destination_trigger_id: StringName = &"up":
	set(value):
		down_destination_trigger_id = value
		_queue_refresh()

@export_subgroup("Left")
@export var left_trigger_id: StringName = &"left":
	set(value):
		left_trigger_id = value
		_queue_refresh()
@export_file("*.tscn") var left_destination_scene: String = "":
	set(value):
		left_destination_scene = value
		_queue_refresh()
@export var left_destination_trigger_id: StringName = &"right":
	set(value):
		left_destination_trigger_id = value
		_queue_refresh()


func _ready() -> void:
	# Arrival placement can run as soon as scene_changed fires. Set trigger IDs
	# before that signal instead of deferring the first refresh a frame.
	_refresh_exits()
	if not Engine.is_editor_hint():
		_rebuild_ground_boundaries()
	if Engine.is_editor_hint():
		set_physics_process(false)
		update_configuration_warnings()


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or not void_reload_enabled:
		return
	var manager := get_node("/root/GameManager")
	var active_player := manager.player as Node3D
	if not is_instance_valid(active_player) or not is_ancestor_of(active_player):
		return
	if to_local(active_player.global_position).y < void_height:
		manager.reload_current_scene()


func _queue_refresh() -> void:
	if is_inside_tree():
		call_deferred("_refresh_exits")
		if Engine.is_editor_hint():
			notify_property_list_changed()
			update_configuration_warnings()


func _refresh_destination_inspector() -> void:
	notify_property_list_changed()
	update_configuration_warnings()


func _validate_property(property: Dictionary) -> void:
	if not Engine.is_editor_hint():
		return
	for direction: String in EXIT_CATALOG.DIRECTIONS:
		if String(property.name).begins_with(direction + "_"):
			var index: int = EXIT_CATALOG.DIRECTIONS.find(direction)
			if not (open_exits & (1 << index)):
				property.usage = int(property.usage) & ~PROPERTY_USAGE_EDITOR
			elif property.name == direction + "_destination_trigger_id":
				EXIT_CATALOG.configure_dropdown(
					property, get(direction + "_destination_scene"), get(property.name)
				)
			return


func _refresh_exits() -> void:
	_apply_exit(
		"UpPath",
		bool(open_exits & UP),
		up_trigger_id,
		up_destination_scene,
		up_destination_trigger_id
	)
	_apply_exit(
		"RightPath",
		bool(open_exits & RIGHT),
		right_trigger_id,
		right_destination_scene,
		right_destination_trigger_id
	)
	_apply_exit(
		"DownPath",
		bool(open_exits & DOWN),
		down_trigger_id,
		down_destination_scene,
		down_destination_trigger_id
	)
	_apply_exit(
		"LeftPath",
		bool(open_exits & LEFT),
		left_trigger_id,
		left_destination_scene,
		left_destination_trigger_id
	)
	if is_inside_tree() and is_node_ready() and not Engine.is_editor_hint():
		_rebuild_ground_boundaries.call_deferred()


## Generate walls along the exposed edges of the union of floor boxes. Paths are
## included only while open, so their overlap with the ground remains walkable.
func _rebuild_ground_boundaries() -> void:
	var old := get_node_or_null("GroundBoundaries")
	if old:
		remove_child(old)
		old.queue_free()
	if not boundary_enabled:
		return
	var floors: Array[Dictionary] = []
	var environment := get_node_or_null("Environment")
	if environment:
		for child in environment.get_children():
			if String(child.name).begins_with("BaseGround"):
				_collect_floor_boxes(child.get_node_or_null("StaticBody3D"), floors)
	for entry in [["UpPath", UP], ["RightPath", RIGHT], ["DownPath", DOWN], ["LeftPath", LEFT]]:
		if open_exits & entry[1]:
			_collect_floor_boxes(get_node_or_null("Exits/%s/StaticBody3D" % entry[0]), floors)
	var walls := StaticBody3D.new()
	walls.name = "GroundBoundaries"
	# Only Foxy's body uses this layer; combat and other actors ignore the walls.
	walls.collision_layer = 1 << 8
	walls.collision_mask = 0
	add_child(walls)
	for floor_data: Dictionary in floors:
		var rect: Rect2 = floor_data.rect
		var xs: Array[float] = [rect.position.x, rect.end.x]
		var zs: Array[float] = [rect.position.y, rect.end.y]
		for other: Dictionary in floors:
			if absf(float(other.top) - float(floor_data.top)) < 0.5:
				var r: Rect2 = other.rect
				for x in [r.position.x, r.end.x]:
					if x > rect.position.x and x < rect.end.x:
						xs.append(x)
				for z in [r.position.y, r.end.y]:
					if z > rect.position.y and z < rect.end.y:
						zs.append(z)
		for opening: Rect2 in boundary_openings:
			for x in [opening.position.x, opening.end.x]:
				if x > rect.position.x and x < rect.end.x:
					xs.append(x)
			for z in [opening.position.y, opening.end.y]:
				if z > rect.position.y and z < rect.end.y:
					zs.append(z)
		xs.sort()
		zs.sort()
		for i in range(xs.size() - 1):
			_add_boundary(
				walls,
				floors,
				Vector2(xs[i], rect.position.y),
				Vector2(xs[i + 1], rect.position.y),
				Vector2(0, -1),
				floor_data.top
			)
			_add_boundary(
				walls,
				floors,
				Vector2(xs[i], rect.end.y),
				Vector2(xs[i + 1], rect.end.y),
				Vector2(0, 1),
				floor_data.top
			)
		for i in range(zs.size() - 1):
			_add_boundary(
				walls,
				floors,
				Vector2(rect.position.x, zs[i]),
				Vector2(rect.position.x, zs[i + 1]),
				Vector2(-1, 0),
				floor_data.top
			)
			_add_boundary(
				walls,
				floors,
				Vector2(rect.end.x, zs[i]),
				Vector2(rect.end.x, zs[i + 1]),
				Vector2(1, 0),
				floor_data.top
			)


func _collect_floor_boxes(body: Node, floors: Array[Dictionary]) -> void:
	if body == null:
		return
	for node in body.get_children():
		if not node is CollisionShape3D or node.disabled or not node.shape is BoxShape3D:
			continue
		var t: Transform3D = global_transform.affine_inverse() * node.global_transform
		var half: Vector3 = node.shape.size * 0.5
		# Room floors must be horizontal, axis-aligned boxes (quarter turns are fine).
		if (
			absf(t.basis.x.y) > 0.001
			or absf(t.basis.z.y) > 0.001
			or (absf(t.basis.x.x) > 0.001 and absf(t.basis.x.z) > 0.001)
		):
			push_warning("Ground boundaries require axis-aligned floor boxes: %s" % node.get_path())
			continue
		var extent := Vector2(
			absf(t.basis.x.x) * half.x + absf(t.basis.z.x) * half.z,
			absf(t.basis.x.z) * half.x + absf(t.basis.z.z) * half.z
		)
		floors.append(
			{
				"rect": Rect2(Vector2(t.origin.x, t.origin.z) - extent, extent * 2.0),
				"top": t.origin.y + absf(t.basis.y.y) * half.y
			}
		)


func _add_boundary(
	walls: StaticBody3D,
	floors: Array[Dictionary],
	start: Vector2,
	end: Vector2,
	outward: Vector2,
	top: float
) -> void:
	if start.distance_to(end) < 0.01:
		return
	var midpoint := (start + end) * 0.5
	for opening: Rect2 in boundary_openings:
		if opening.has_point(midpoint):
			return
	for other: Dictionary in floors:
		if (
			absf(float(other.top) - top) < 0.5
			and (other.rect as Rect2).has_point(midpoint + outward * 0.01)
		):
			return
	var wall := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(
		absf(end.x - start.x) + absf(outward.x) * 0.15,
		3.0,
		absf(end.y - start.y) + absf(outward.y) * 0.15
	)
	wall.shape = box
	wall.position = Vector3(
		midpoint.x + outward.x * 0.075, top + 1.45, midpoint.y + outward.y * 0.075
	)
	walls.add_child(wall)


func _apply_exit(
	path_name: String,
	is_open: bool,
	local_id: StringName,
	destination_scene: String,
	destination_id: StringName
) -> void:
	var path := get_node_or_null("Exits/" + path_name) as Node3D
	if path == null:
		return
	path.visible = is_open
	var body := path.get_node_or_null("StaticBody3D") as StaticBody3D
	if body != null:
		for child in body.get_children():
			if child is CollisionShape3D:
				child.disabled = not is_open
	var trigger := path.get_node_or_null("SceneChangeTrigger") as Area3D
	if trigger == null:
		return
	trigger.set("trigger_id", local_id)
	trigger.set("destination_scene", destination_scene)
	trigger.set("destination_trigger_id", destination_id)
	trigger.set("enabled", is_open)
	trigger.monitoring = is_open
	var shape := trigger.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape != null:
		shape.disabled = not is_open


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if open_exits == 0:
		warnings.append("Keep at least one exit open.")
	_check_exit(warnings, UP, "Up", up_trigger_id, up_destination_scene, up_destination_trigger_id)
	_check_exit(
		warnings,
		RIGHT,
		"Right",
		right_trigger_id,
		right_destination_scene,
		right_destination_trigger_id
	)
	_check_exit(
		warnings, DOWN, "Down", down_trigger_id, down_destination_scene, down_destination_trigger_id
	)
	_check_exit(
		warnings, LEFT, "Left", left_trigger_id, left_destination_scene, left_destination_trigger_id
	)
	return warnings


func _check_exit(
	warnings: PackedStringArray,
	flag: int,
	label: String,
	local_id: StringName,
	destination_scene: String,
	destination_id: StringName
) -> void:
	if not (open_exits & flag):
		return
	if local_id.is_empty():
		warnings.append("%s exit needs a trigger ID." % label)
	var warning := EXIT_CATALOG.destination_warning(destination_scene, destination_id)
	if not warning.is_empty():
		warnings.append("%s: %s" % [label, warning])
