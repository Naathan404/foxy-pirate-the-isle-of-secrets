@tool
class_name WorldMapSync
extends RefCounted
## Editor-time builder: reads every `<biomes_root>/<biome>/map/*.tscn`, adds new biomes and
## rooms, refreshes exits and places new rooms on the grid next to the rooms they connect to.
## Authored values (room cell, hidden, marker; biome name, position, colour, flag) are kept.

const EXIT_CATALOG := preload("res://world/components/scene_exit_catalog.gd")
const ROOMS_FOLDER := "map"
const SCENE_EXTENSION := ".tscn"
const CHECKPOINT_ROLE := "Checkpoint"
const NPC_ROLE_PREFIX := "NPC"
## Gap left between a new disconnected group of rooms and the rooms already placed.
const ISLAND_GAP_CELLS := 2


## Updates `world` in place and returns a readable report. With `relayout_all`, every room
## is placed again from scratch; otherwise only rooms that are new to the map move.
static func sync(world: WorldMapData, relayout_all: bool = false) -> PackedStringArray:
	var report := PackedStringArray()
	for folder: String in _biome_folders(world.biomes_root):
		if world.find_biome(StringName(folder)) == null:
			world.biomes.append(_new_biome(folder, _free_world_cell(world)))
			report.append("New biome '%s' added; set its name, colour and position." % folder)
	for biome: BiomeMapData in world.biomes:
		_sync_biome(world, biome, relayout_all, report)
	_report_unknown_destinations(world, report)
	return report


static func _sync_biome(
	world: WorldMapData, biome: BiomeMapData, relayout_all: bool, report: PackedStringArray
) -> void:
	var folder := world.biomes_root.path_join(String(biome.biome_id)).path_join(ROOMS_FOLDER)
	var rooms: Array[RoomMapData] = []
	var new_rooms: Array[RoomMapData] = []
	for scene_path: String in _room_scenes(folder):
		var room := biome.find_room(scene_path)
		if room == null:
			room = RoomMapData.new()
			room.scene_path = scene_path
			room.marker = _marker_for_role(EXIT_CATALOG.get_room_role(scene_path))
			new_rooms.append(room)
		room.exits = _read_exits(scene_path)
		rooms.append(room)

	var removed := biome.rooms.size() - (rooms.size() - new_rooms.size())
	biome.rooms = rooms
	_layout(rooms, rooms if relayout_all else new_rooms)
	if not new_rooms.is_empty() or removed > 0:
		report.append(
			"%s: %d room(s) added, %d removed." % [biome.biome_id, new_rooms.size(), removed]
		)


static func _read_exits(scene_path: String) -> Dictionary[RoomMapData.Direction, String]:
	var exits: Dictionary[RoomMapData.Direction, String] = {}
	var destinations := EXIT_CATALOG.get_room_destinations(scene_path)
	for index: int in destinations:
		exits[index as RoomMapData.Direction] = destinations[index]
	return exits


## Breadth-first placement: each unplaced room goes one cell past the room that leads to
## it, in the exit's direction, sliding sideways or further out when that cell is taken.
static func _layout(rooms: Array[RoomMapData], to_place: Array[RoomMapData]) -> void:
	var by_path: Dictionary[String, RoomMapData] = {}
	var occupied: Dictionary[Vector2i, bool] = {}
	var queue: Array[RoomMapData] = []
	for room: RoomMapData in rooms:
		by_path[room.scene_path] = room
		if not to_place.has(room):
			occupied[room.cell] = true
			queue.append(room)

	var unplaced := to_place.duplicate()
	while not unplaced.is_empty():
		if queue.is_empty():
			var seed: RoomMapData = unplaced.pop_front()
			seed.cell = _island_cell(occupied)
			occupied[seed.cell] = true
			queue.append(seed)
		var room: RoomMapData = queue.pop_front()
		for direction: RoomMapData.Direction in room.exits:
			var neighbor: RoomMapData = by_path.get(room.exits[direction])
			if neighbor == null or not unplaced.has(neighbor):
				continue
			neighbor.cell = _free_cell_toward(room.cell, direction, occupied)
			occupied[neighbor.cell] = true
			unplaced.erase(neighbor)
			queue.append(neighbor)


static func _free_cell_toward(
	origin: Vector2i, direction: RoomMapData.Direction, occupied: Dictionary[Vector2i, bool]
) -> Vector2i:
	var step := RoomMapData.offset_of(direction)
	var side := Vector2i(step.y, step.x)
	var distance := 1
	while true:
		var ahead := origin + step * distance
		for candidate: Vector2i in [ahead, ahead + side, ahead - side]:
			if not occupied.has(candidate):
				return candidate
		distance += 1
	return origin


## First room of a group with no placed neighbour: right of everything already placed.
static func _island_cell(occupied: Dictionary[Vector2i, bool]) -> Vector2i:
	if occupied.is_empty():
		return Vector2i.ZERO
	var right_edge: int = occupied.keys()[0].x
	for cell: Vector2i in occupied:
		right_edge = maxi(right_edge, cell.x)
	return Vector2i(right_edge + ISLAND_GAP_CELLS, 0)


static func _marker_for_role(role: String) -> RoomMapData.Marker:
	if role == CHECKPOINT_ROLE:
		return RoomMapData.Marker.CHECKPOINT
	if role.begins_with(NPC_ROLE_PREFIX):
		return RoomMapData.Marker.NPC
	return RoomMapData.Marker.NONE


static func _new_biome(folder: String, world_cell: Vector2i) -> BiomeMapData:
	var biome := BiomeMapData.new()
	biome.biome_id = StringName(folder)
	biome.display_name = folder.capitalize()
	biome.world_cell = world_cell
	return biome


## Nearest free spot around the hub, ring by ring.
static func _free_world_cell(world: WorldMapData) -> Vector2i:
	var used: Array[Vector2i] = []
	for biome: BiomeMapData in world.biomes:
		used.append(biome.world_cell)
	var radius := 1
	while true:
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				var cell := Vector2i(x, y)
				if maxi(absi(x), absi(y)) == radius and not used.has(cell):
					return cell
		radius += 1
	return Vector2i.ZERO


static func _report_unknown_destinations(world: WorldMapData, report: PackedStringArray) -> void:
	for biome: BiomeMapData in world.biomes:
		for room: RoomMapData in biome.rooms:
			for destination: String in room.exits.values():
				if world.find_biome_of_room(destination) == null:
					report.append(
						(
							"%s leads to %s, which is not in any biome map folder."
							% [room.scene_path.get_file(), destination]
						)
					)


static func _biome_folders(root: String) -> PackedStringArray:
	var folders := PackedStringArray()
	for folder: String in DirAccess.get_directories_at(root):
		if not _room_scenes(root.path_join(folder).path_join(ROOMS_FOLDER)).is_empty():
			folders.append(folder)
	return folders


static func _room_scenes(folder: String) -> PackedStringArray:
	var scenes := PackedStringArray()
	if not DirAccess.dir_exists_absolute(folder):
		return scenes
	for file: String in DirAccess.get_files_at(folder):
		if file.ends_with(SCENE_EXTENSION):
			scenes.append(folder.path_join(file))
	scenes.sort()
	return scenes
