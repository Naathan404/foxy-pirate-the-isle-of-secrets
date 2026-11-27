@tool
class_name BaseRoom
extends Node3D

## Emitted after the invisible player walls were (re)built, for visuals that follow them.
signal player_boundaries_rebuilt(walls: StaticBody3D)

## Configure the four paths and choose destination exits from this room's Inspector.
## A room always keeps at least one path open.

const UP := 1
const RIGHT := 2
const DOWN := 4
const LEFT := 8
const EXIT_CATALOG := preload("res://world/components/scene_exit_catalog.gd")
# //NLVP sửa: Tách biên người chơi và biên quái.
const PLAYER_BOUNDARIES_NAME := &"GroundBoundaries"
const ENEMY_BOUNDARIES_NAME := &"EnemyGroundBoundaries"
## Slack around floor bounds so edges that merely touch another floor are still tested.
const EDGE_BOUNDS_MARGIN := 0.01
## A fall is only read as one past this downward speed, so the first tick off a ledge or a
## landing bump does not count.
const VOID_FALL_MIN_SPEED := 1.0
## How far below Foxy the void probe looks for ground to land on.
const VOID_PROBE_METERS := 4.0
## The probe starts slightly above her origin so ground she is touching still counts.
const VOID_PROBE_LIFT_METERS := 0.2

@export_tool_button("Refresh destination exits", "Reload") var refresh_destination_exits: Callable:
	get:
		return _refresh_destination_inspector

@export_group("Void")
## Foxy falling with no ground under her is a fall into the void: the screen closes on her
## and she comes back at the door she entered this room by (the nearest door when she did
## not walk in), losing `void_fall_damage` HP. If that would empty her HP she dies and
## respawns at the campfire like any other death. A dash over a gap holds its height, so it
## is not a fall.
@export var void_reload_enabled: bool = true
## Last resort: below this height (relative to the room origin) any fall is a void fall.
@export var void_height: float = -6.0
@export_range(0.0, 10.0, 0.5, "suffix:HP") var void_fall_damage: float = 1.0

@export_group("Safe room")
## Charms can be changed anywhere in this room (the hub, campfire rests). A campfire in this
## room can be rested at and save the game only while this flag is on.
@export var safe_room: bool = false

@export_group("Loot")
## Enemies killed in this room may drop their charm loot. Item, gold and note drops are not
## affected.
@export var enemy_charm_drops: bool = true

@export_group("Ground boundaries")
## Openings in room-local X/Z coordinates, for example at moving platform docks.
@export var boundary_openings: Array[Rect2] = []
@export var boundary_enabled: bool = true
# //NLVP sửa: Bật biên kín cho quái trong Inspector.
## Chặn quái ra khỏi nền đảo và đi lên các path.
@export var enemy_boundary_enabled: bool = false

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

var _exits_locked := false
## Exits (UP/RIGHT/DOWN/LEFT flags) kept shut by a gate or a secret, independent of the lock.
var _sealed_exits: int = 0
## Exits whose path is not drawn either, so a secret passage looks like plain shore.
var _hidden_exits: int = 0
var _boundary_rebuild_queued := false
## World cycle this room was built in; its records are ignored once a rest starts a new one.
var _state_cycle: int = -1


## The room that owns `node`, or null when it is not inside one (tests, tool scenes).
static func find_room(node: Node) -> BaseRoom:
	var current := node.get_parent() if node != null else null
	while current != null:
		if current is BaseRoom:
			return current as BaseRoom
		current = current.get_parent()
	return null


## A random source for `source` that repeats within a world cycle and changes on each rest,
## so the room keeps its layout between visits. Outside a game it is simply randomized.
static func create_random(source: Node) -> RandomNumberGenerator:
	var random := RandomNumberGenerator.new()
	var room := find_room(source)
	var manager := source.get_node_or_null("/root/GameManager") if source.is_inside_tree() else null
	if room == null or manager == null or room.scene_file_path.is_empty():
		random.randomize()
		return random
	random.seed = manager.room_states.seed_for(
		room.scene_file_path, String(room.get_path_to(source))
	)
	return random


func _ready() -> void:
	# Arrival placement can run as soon as scene_changed fires. Set trigger IDs
	# before that signal instead of deferring the first refresh a frame.
	_refresh_exits()
	if not Engine.is_editor_hint():
		_rebuild_ground_boundaries()
		_grant_safe_room()
		_apply_room_state()
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
	var falling_player := active_player as Player
	if falling_player.dead or falling_player.falling_into_void or falling_player.is_on_floor():
		return
	var below_floor := to_local(active_player.global_position).y < void_height
	if below_floor or _is_falling_over_void(falling_player):
		var sequence := VoidFallSequence.new(self, falling_player)
		sequence.fall_damage = void_fall_damage
		add_child(sequence)


## Dropping (not dashing) with nothing to land on within VOID_PROBE_METERS. A Tide Grapple
## pull crosses gaps in the air while gravity still builds up speed, so it never counts.
func _is_falling_over_void(falling_player: Player) -> bool:
	if falling_player.velocity.y > -VOID_FALL_MIN_SPEED or falling_player.is_grapple_pulling():
		return false
	return not _has_ground_below(
		falling_player.global_position,
		falling_player.collision_mask & ~CombatLayers.PLAYER_BOUNDARY,
		[falling_player.get_rid()]
	)


func _has_ground_below(point: Vector3, mask: int, exclude: Array[RID] = []) -> bool:
	var query := PhysicsRayQueryParameters3D.create(
		point + Vector3.UP * VOID_PROBE_LIFT_METERS,
		point + Vector3.DOWN * VOID_PROBE_METERS,
		mask,
		exclude
	)
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Where Foxy comes back after falling into the void from `fall_position`: in front of the
## door she entered this room by, else the open door nearest the fall, else the room's
## campfire. A door counts only with ground in front of it: a closed exit has its path
## hidden and would drop her straight back into the void.
func get_void_respawn_position(fall_position: Vector3, ground_mask: int) -> Vector3:
	var arrival_id: StringName = get_node("/root/GameManager").arrival_trigger_id
	var nearest: SceneChangeTrigger = null
	var nearest_distance := INF
	for node in get_tree().get_nodes_in_group("scene_change_triggers"):
		var trigger := node as SceneChangeTrigger
		if trigger == null or not is_ancestor_of(trigger):
			continue
		if not _has_ground_below(trigger.get_exit_position(), ground_mask):
			continue
		if not arrival_id.is_empty() and trigger.trigger_id == arrival_id:
			return trigger.get_exit_position()
		if not trigger.enabled:
			continue
		var offset := trigger.get_exit_position() - fall_position
		offset.y = 0.0
		if offset.length() < nearest_distance:
			nearest = trigger
			nearest_distance = offset.length()
	if nearest != null:
		return nearest.get_exit_position()
	for node in find_children("*", "CampfireRestPoint", true, false):
		return (node as CampfireRestPoint).get_spawn_position()
	push_warning("BaseRoom: no door or campfire to return Foxy to after a void fall.")
	return global_position


## Restores and starts recording one stateful object. Objects present when the room becomes
## ready are tracked automatically; call this for stateful objects spawned later, after they
## are added under the room with a stable name.
## - Enemies and breakable props stay gone until the next rest.
## - Treasure chests stay open for the whole run.
func track_object(node: Node) -> void:
	if Engine.is_editor_hint() or scene_file_path.is_empty() or not is_ancestor_of(node):
		return
	var registry: RoomStateRegistry = get_node("/root/GameManager").room_states
	var key := String(get_path_to(node))
	if node is TreasureChest:
		var chest := node as TreasureChest
		if registry.is_permanent(scene_file_path, key):
			chest.restore_opened()
		else:
			chest.destroyed.connect(registry.mark_permanent.bind(scene_file_path, key))
	elif node is DestructibleProp:
		var prop := node as DestructibleProp
		if registry.is_cleared(scene_file_path, key):
			_remove_cleared(prop)
		else:
			prop.destroyed.connect(registry.mark_cleared.bind(scene_file_path, key, _state_cycle))
	elif node is EnemyBase:
		var enemy := node as EnemyBase
		if registry.is_cleared(scene_file_path, key):
			_remove_cleared(enemy)
		else:
			enemy.died.connect(registry.mark_cleared.bind(scene_file_path, key, _state_cycle))


## Close the island's player boundary and disable transitions without hiding paths.
func set_exits_locked(locked: bool) -> void:
	if _exits_locked == locked:
		return
	_exits_locked = locked
	_queue_refresh()


## Shuts one exit (`UP`, `RIGHT`, `DOWN` or `LEFT`) on its own, for gates and secret passages:
## the transition is off and the island boundary closes across the path. With `hide_path`
## the path is not drawn either. `set_exits_locked` still shuts every exit on top of this.
func set_exit_sealed(direction: int, sealed: bool, hide_path: bool = false) -> void:
	var sealed_exits := (_sealed_exits | direction) if sealed else (_sealed_exits & ~direction)
	var hidden_exits := (
		(_hidden_exits | direction) if sealed and hide_path else (_hidden_exits & ~direction)
	)
	if sealed_exits == _sealed_exits and hidden_exits == _hidden_exits:
		return
	_sealed_exits = sealed_exits
	_hidden_exits = hidden_exits
	_queue_refresh()


func is_exit_sealed(direction: int) -> bool:
	return bool(_sealed_exits & direction)


## Foxy is a child of the room, so it has registered with GameManager before the room is
## ready. The room is the safe source: leaving the room frees it and ends the permission.
func _grant_safe_room() -> void:
	if not safe_room:
		return
	var active_player := get_node("/root/GameManager").player as Player
	if not is_instance_valid(active_player) or not is_ancestor_of(active_player):
		return
	if is_instance_valid(active_player.charm_socket_manager):
		active_player.charm_socket_manager.enter_safe_location(self)


## Children are ready first, including enemies and props spawned by random sources, so
## the whole room can be matched against the records of this cycle here.
func _apply_room_state() -> void:
	if scene_file_path.is_empty():
		return
	_state_cycle = get_node("/root/GameManager").room_states.cycle
	for node: Node in find_children("*", "", true, false):
		track_object(node)


## Removed before it can act; it never reappears until the next rest.
func _remove_cleared(node: Node3D) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	node.hide()
	node.queue_free()


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
	_apply_exit("UpPath", UP, up_trigger_id, up_destination_scene, up_destination_trigger_id)
	_apply_exit(
		"RightPath", RIGHT, right_trigger_id, right_destination_scene, right_destination_trigger_id
	)
	_apply_exit(
		"DownPath", DOWN, down_trigger_id, down_destination_scene, down_destination_trigger_id
	)
	_apply_exit(
		"LeftPath", LEFT, left_trigger_id, left_destination_scene, left_destination_trigger_id
	)
	if is_inside_tree() and is_node_ready() and not Engine.is_editor_hint():
		queue_boundary_rebuild()


## Rebuilds the boundaries once at the end of the frame, however many changes asked for it
## (an exit lock and a floor switched off by the same event cost one rebuild).
func queue_boundary_rebuild() -> void:
	if _boundary_rebuild_queued:
		return
	_boundary_rebuild_queued = true
	_rebuild_ground_boundaries.call_deferred()


## Generate walls along the exposed edges of the floors. Paths are
## included only while open, so their overlap with the ground remains walkable.
func _rebuild_ground_boundaries() -> void:
	_boundary_rebuild_queued = false
	# //NLVP sửa: Dọn cả hai lớp biên trước khi dựng lại.
	for boundary_name in [PLAYER_BOUNDARIES_NAME, ENEMY_BOUNDARIES_NAME]:
		var old := get_node_or_null(NodePath(boundary_name))
		if old:
			remove_child(old)
			old.queue_free()
	if not boundary_enabled and not enemy_boundary_enabled:
		return
	var floors: Array[Dictionary] = []
	var environment := get_node_or_null("Environment")
	if environment:
		for child in environment.get_children():
			if String(child.name).begins_with("BaseGround"):
				_collect_floors(child.get_node_or_null("StaticBody3D"), floors)
	# //NLVP sửa: Biên quái chỉ theo nền đảo, không mở cửa ra path.
	if enemy_boundary_enabled:
		_create_ground_boundaries(ENEMY_BOUNDARIES_NAME, CombatLayers.ENEMY_BOUNDARY, floors, [])
	if not boundary_enabled:
		return
	for entry in [["UpPath", UP], ["RightPath", RIGHT], ["DownPath", DOWN], ["LeftPath", LEFT]]:
		if not _exits_locked and (open_exits & entry[1]) and not (_sealed_exits & entry[1]):
			_collect_floors(get_node_or_null("Exits/%s/StaticBody3D" % entry[0]), floors)
	_create_ground_boundaries(
		PLAYER_BOUNDARIES_NAME, CombatLayers.PLAYER_BOUNDARY, floors, boundary_openings
	)


# //NLVP sửa: Dùng chung cách dựng vách cho người chơi và quái.
func _create_ground_boundaries(
	boundary_name: StringName, layer: int, floors: Array[Dictionary], openings: Array[Rect2]
) -> void:
	var walls := StaticBody3D.new()
	walls.name = boundary_name
	walls.collision_layer = layer
	walls.collision_mask = 0
	for floor_data: Dictionary in floors:
		var outline: PackedVector2Array = floor_data.outline
		for i in range(outline.size() - 1):
			_add_floor_edge(walls, floors, outline[i], outline[i + 1], floor_data.top, openings)
	# Shapes go in before the body enters the tree: a body already in the physics space rebuilds
	# its compound shape on every added wall, which made a rebuild cost tens of milliseconds.
	add_child(walls)
	if layer == CombatLayers.PLAYER_BOUNDARY:
		player_boundaries_rebuilt.emit(walls)


func _collect_floors(body: Node, floors: Array[Dictionary]) -> void:
	if body == null:
		return
	for node in body.get_children():
		if not node is CollisionShape3D or node.disabled:
			continue
		var points: PackedVector3Array
		if node.shape is BoxShape3D:
			var half: Vector3 = node.shape.size * 0.5
			points = PackedVector3Array(
				[
					Vector3(-half.x, half.y, -half.z),
					Vector3(half.x, half.y, -half.z),
					Vector3(half.x, half.y, half.z),
					Vector3(-half.x, half.y, half.z)
				]
			)
		elif node.shape is ConvexPolygonShape3D:
			points = node.shape.points
		else:
			continue
		var t: Transform3D = global_transform.affine_inverse() * node.global_transform
		if absf(t.basis.x.y) > 0.001 or absf(t.basis.z.y) > 0.001:
			push_warning("Ground boundaries require horizontal floors: %s" % node.get_path())
			continue
		var projected := PackedVector2Array()
		var top := -INF
		for point: Vector3 in points:
			var position := t * point
			projected.append(Vector2(position.x, position.z))
			top = maxf(top, position.y)
		# The hull is counterclockwise and repeats the first point at the end.
		var outline := Geometry2D.convex_hull(projected)
		if outline.size() >= 4:
			floors.append({"outline": outline, "top": top, "bounds": _outline_bounds(outline)})


func _outline_bounds(outline: PackedVector2Array) -> Rect2:
	var bounds := Rect2(outline[0], Vector2.ZERO)
	for point: Vector2 in outline:
		bounds = bounds.expand(point)
	return bounds


# //NLVP sửa: Mỗi lớp biên nhận danh sách cửa mở riêng.
func _add_floor_edge(
	walls: StaticBody3D,
	floors: Array[Dictionary],
	start: Vector2,
	end: Vector2,
	top: float,
	openings: Array[Rect2]
) -> void:
	var edge := end - start
	if edge.length_squared() < 0.0001:
		return
	var cuts: Array[float] = [0.0, 1.0]
	# Only floors whose bounds touch the edge can cut it; skipping the rest keeps a rebuild cheap.
	var edge_bounds := Rect2(start, Vector2.ZERO).expand(end).grow(EDGE_BOUNDS_MARGIN)
	for other: Dictionary in floors:
		if absf(float(other.top) - top) < 0.5 and edge_bounds.intersects(other.bounds):
			_split_edge(start, end, other.outline, cuts)
	for opening: Rect2 in openings:
		var outline := PackedVector2Array(
			[
				opening.position,
				Vector2(opening.end.x, opening.position.y),
				opening.end,
				Vector2(opening.position.x, opening.end.y),
				opening.position
			]
		)
		_split_edge(start, end, outline, cuts)
	cuts.sort()
	var outward := Vector2(edge.y, -edge.x).normalized()
	for i in range(cuts.size() - 1):
		_add_boundary(
			walls,
			floors,
			start + edge * cuts[i],
			start + edge * cuts[i + 1],
			outward,
			top,
			openings
		)


func _split_edge(
	start: Vector2, end: Vector2, outline: PackedVector2Array, cuts: Array[float]
) -> void:
	var edge := end - start
	for i in range(outline.size() - 1):
		var intersection: Variant = Geometry2D.segment_intersects_segment(
			start, end, outline[i], outline[i + 1]
		)
		if intersection != null:
			cuts.append(clampf((intersection - start).dot(edge) / edge.length_squared(), 0.0, 1.0))


# //NLVP sửa: Biên quái không bỏ trống các cửa dành cho người chơi.
func _add_boundary(
	walls: StaticBody3D,
	floors: Array[Dictionary],
	start: Vector2,
	end: Vector2,
	outward: Vector2,
	top: float,
	openings: Array[Rect2]
) -> void:
	if start.distance_to(end) < 0.01:
		return
	var midpoint := (start + end) * 0.5
	for opening: Rect2 in openings:
		if opening.has_point(midpoint):
			return
	var probe := midpoint + outward * 0.01
	for other: Dictionary in floors:
		if (
			absf(float(other.top) - top) < 0.5
			and (other.bounds as Rect2).grow(EDGE_BOUNDS_MARGIN).has_point(probe)
			and Geometry2D.is_point_in_polygon(probe, other.outline)
		):
			return
	var wall := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(start.distance_to(end), 3.0, 0.15)
	wall.shape = box
	wall.rotation.y = -(end - start).angle()
	wall.position = Vector3(
		midpoint.x + outward.x * 0.075, top + 1.45, midpoint.y + outward.y * 0.075
	)
	walls.add_child(wall)


func _apply_exit(
	path_name: String,
	direction: int,
	local_id: StringName,
	destination_scene: String,
	destination_id: StringName
) -> void:
	var path := get_node_or_null("Exits/" + path_name) as Node3D
	if path == null:
		return
	var is_open := bool(open_exits & direction)
	path.visible = is_open and not (_hidden_exits & direction)
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
	var can_transition := is_open and not _exits_locked and not (_sealed_exits & direction)
	trigger.set("enabled", can_transition)
	trigger.monitoring = can_transition
	var shape := trigger.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape != null:
		shape.disabled = not can_transition


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
