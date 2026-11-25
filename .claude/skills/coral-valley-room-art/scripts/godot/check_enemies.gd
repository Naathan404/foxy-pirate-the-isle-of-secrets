extends SceneTree
## Checks every place an enemy can appear in a Coral Valley room against
## docs/world/coral_valley_enemy_placement.md and prints PASS/FAIL. Exit code 1 if anything fails.
##
## Covered: hand-placed EnemyBase nodes and every candidate position of random_props spawners
## whose pool holds enemies, including each layout a selector such as RandomEmptyType can pick.
## Not covered: enemies spawned during play by tide or raid spawners (they have their own
## spacing rules in FlatTideEnemySpawner).
##
## godot --headless --path . --script <this> -- res://world/biomes/coral_valley/map/room_XX.tscn

const RANDOM_PROPS := preload("res://world/biomes/coral_valley/objects/random_props.gd")
## Extra distance beyond an enemy's detection radius at entrances and the campfire (rule E2).
const ENTRY_MARGIN_METERS := 1.0
## Distance between two enemy spawn points; matches FlatTideEnemySpawner.minimum_spacing (E4).
const ENEMY_SPACING_METERS := 3.0
## Ground needed around a spawn point; matches FlatTideEnemySpawner.edge_clearance (E3).
const EDGE_CLEARANCE_METERS := 2.0
## Free space between an enemy spawn point and a blocking prop (E3).
const BLOCKER_CLEARANCE_METERS := 1.5
const GROUND_STEP_TOLERANCE_METERS := 0.5
const RAY_HEIGHT_METERS := 3.0
const RAY_DEPTH_METERS := 6.0
const WORLD_LAYER := 1
const MAX_RAY_PASSES := 8
const FALLBACK_DETECTION_METERS := 6.5
const SETTLE_SECONDS := 1.0

var _failures := 0
## Each entry: {label, position, radius, group}
var _spawns: Array[Dictionary] = []
var _blockers: Array[Vector3] = []


func _initialize() -> void:
	var path: String = OS.get_cmdline_user_args()[0]
	change_scene_to_file(path)
	await create_timer(SETTLE_SECONDS).timeout
	await physics_frame
	var room := current_scene
	# Positions come from a detached copy: in the running room, enemies already walk around.
	# The running room is only used for its ground collision.
	var authored := (load(path) as PackedScene).instantiate()
	_collect(authored, Transform3D.IDENTITY, "")
	authored.free()
	print(
		"%d enemy spawn point(s), %d blocking prop position(s)" % [_spawns.size(), _blockers.size()]
	)
	if room.get("safe_room") == true:
		_check(_spawns.is_empty(), "safe room has no enemies (E1)")
	var exits := _exit_positions(room)
	var fires := _campfire_positions(room)
	for spawn: Dictionary in _spawns:
		_check_spawn(spawn, exits, fires)
	_check_spacing()
	print("%d failure(s)" % _failures)
	quit(1 if _failures > 0 else 0)


## `parent_global` maps the node's parent space to the world, so detached layout scenes
## (never added to the tree) can be measured where a selector would place them.
func _collect(node: Node, parent_global: Transform3D, label: String) -> void:
	var global := parent_global
	if node is Node3D:
		global = parent_global * (node as Node3D).transform
	var name_path := label.path_join(node.name) if not label.is_empty() else String(node.name)
	if node.get_script() == RANDOM_PROPS:
		_collect_random(node, global, name_path)
		return
	if node is EnemyBase:
		(
			_spawns
			. append(
				{
					"label": name_path,
					"position": global.origin,
					"radius": _detection_radius(node),
					"group": name_path,
				}
			)
		)
		return
	if node is DestructibleProp and _blocks_movement(node):
		_blockers.append(global.origin)
	for child: Node in node.get_children():
		_collect(child, global, name_path)


## Runtime-spawned children are skipped: every candidate position is checked instead.
func _collect_random(node: Node, global: Transform3D, name_path: String) -> void:
	var radius := 0.0
	var layouts: Array[PackedScene] = []
	var blocking := false
	for scene: PackedScene in _unique_scenes(node):
		var probe := scene.instantiate()
		if probe is EnemyBase:
			radius = maxf(radius, _detection_radius(probe))
		elif probe is DestructibleProp:
			blocking = blocking or _blocks_movement(probe)
		else:
			layouts.append(scene)
		probe.free()
	var positions: PackedVector3Array = node.get("spawn_positions")
	for index: int in positions.size():
		var at := global * Transform3D(Basis(), positions[index])
		if radius > 0.0:
			(
				_spawns
				. append(
					{
						"label": "%s[%d]" % [name_path, index],
						"position": at.origin,
						"radius": radius,
						"group": name_path,
					}
				)
			)
		if blocking:
			_blockers.append(at.origin)
		for layout: PackedScene in layouts:
			var instance := layout.instantiate()
			_collect(instance, at * (instance as Node3D).transform.affine_inverse(), name_path)
			instance.free()


func _unique_scenes(node: Node) -> Array[PackedScene]:
	var result: Array[PackedScene] = []
	var scenes: Array = node.get("prop_scenes")
	if node.get("include_coral") == true:
		scenes = scenes + Array(RANDOM_PROPS.CORAL_SCENES)
	for scene: Variant in scenes:
		if scene is PackedScene and not result.has(scene):
			result.append(scene)
	return result


## The radius at which this enemy notices Foxy when he arrives. A Coral Skeleton that starts
## asleep only wakes inside its smaller sleep radius.
func _detection_radius(enemy: Node) -> float:
	if enemy.get("can_sleep") == true and enemy.get("sleep_detection_radius") != null:
		return float(enemy.get("sleep_detection_radius"))
	for property: String in ["player_detection_radius", "detection_radius"]:
		if enemy.get(property) != null:
			return float(enemy.get(property))
	return FALLBACK_DETECTION_METERS


func _blocks_movement(prop: Node) -> bool:
	var shape := prop.get_node_or_null("MovementBody/CollisionShape3D") as CollisionShape3D
	return shape != null and not shape.disabled


func _exit_positions(room: Node) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for node: Node in room.find_children("*", "", true, false):
		var trigger := node as SceneChangeTrigger
		if trigger != null and trigger.enabled:
			result.append(trigger.get_exit_position())
	return result


func _campfire_positions(room: Node) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for node: Node in room.find_children("*", "", true, false):
		if node is CampfireRestPoint:
			result.append((node as CampfireRestPoint).get_spawn_position())
	return result


func _check_spawn(spawn: Dictionary, exits: Array[Vector3], fires: Array[Vector3]) -> void:
	var position: Vector3 = spawn.position
	var needed: float = spawn.radius + ENTRY_MARGIN_METERS
	for exit: Vector3 in exits:
		var distance := _flat_distance(position, exit)
		_check(
			distance >= needed,
			(
				"%s is %.1f m from an entrance (needs %.1f: detection + margin)"
				% [spawn.label, distance, needed]
			)
		)
	for fire: Vector3 in fires:
		var distance := _flat_distance(position, fire)
		_check(
			distance >= needed,
			"%s is %.1f m from the campfire spawn (needs %.1f)" % [spawn.label, distance, needed]
		)
	var ground: Variant = _ground_height(position)
	_check(ground != null, "%s stands on ground" % spawn.label)
	_check(
		not _is_on_path(position),
		"%s stands on the island, not on a path or pier (E3)" % spawn.label
	)
	if ground != null:
		for direction: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
			var edge: Variant = _ground_height(position + direction * EDGE_CLEARANCE_METERS)
			_check(
				edge != null and absf(float(edge) - float(ground)) <= GROUND_STEP_TOLERANCE_METERS,
				(
					"%s: ground ends or changes height within %.1f m to the %s"
					% [spawn.label, EDGE_CLEARANCE_METERS, _direction_name(direction)]
				)
			)
	for blocker: Vector3 in _blockers:
		var distance := _flat_distance(position, blocker)
		_check(
			distance >= BLOCKER_CLEARANCE_METERS,
			(
				"%s is %.1f m from a blocking prop (needs %.1f)"
				% [spawn.label, distance, BLOCKER_CLEARANCE_METERS]
			)
		)


## Spawn points of the same group can be picked together, so they must not overlap.
func _check_spacing() -> void:
	for first: int in _spawns.size():
		for second: int in range(first + 1, _spawns.size()):
			var a: Dictionary = _spawns[first]
			var b: Dictionary = _spawns[second]
			var distance := _flat_distance(a.position, b.position)
			_check(
				distance >= ENEMY_SPACING_METERS,
				(
					"%s and %s are %.1f m apart (needs %.1f)"
					% [a.label, b.label, distance, ENEMY_SPACING_METERS]
				)
			)


func _ground_height(position: Vector3) -> Variant:
	var hit := _ground_hit(position)
	return null if hit.is_empty() else (hit.position as Vector3).y


## Paths and piers live under the room's Exits node; the enemy boundary keeps enemies off them.
func _is_on_path(position: Vector3) -> bool:
	var hit := _ground_hit(position)
	var exits := current_scene.get_node_or_null("Exits")
	return not hit.is_empty() and exits != null and exits.is_ancestor_of(hit.collider as Node)


func _ground_hit(position: Vector3) -> Dictionary:
	var space := current_scene.get_viewport().world_3d.direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		position + Vector3.UP * RAY_HEIGHT_METERS,
		position + Vector3.DOWN * RAY_DEPTH_METERS,
		WORLD_LAYER
	)
	# Props spawned at random, enemies and Foxy share the World layer; look through them.
	for attempt: int in MAX_RAY_PASSES:
		var hit := space.intersect_ray(query)
		if hit.is_empty() or not _is_on_object(hit.collider as Node):
			return hit
		query.exclude = query.exclude + [hit.rid]
	return {}


func _is_on_object(node: Node) -> bool:
	while node != null:
		if node is DestructibleProp or node is EnemyBase or node is Player:
			return true
		node = node.get_parent()
	return false


## North is away from the camera (-Z), as on the room diagram.
func _direction_name(direction: Vector3) -> String:
	if direction.z < 0.0:
		return "north"
	if direction.z > 0.0:
		return "south"
	return "east" if direction.x > 0.0 else "west"


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	_failures += 1
	print("FAIL ", label)
