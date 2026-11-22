@tool
class_name BiomeMapData
extends Resource
## One biome on the world map. Its rooms are the scenes in
## `res://world/biomes/<biome_id>/map/`, kept in sync by WorldMapSync.

enum Status { UNCHARTED, LOCKED, UNEXPLORED, EXPLORED }

## Must match the biome folder name under the world map's biomes root.
@export var biome_id: StringName = &""
@export var display_name: String = ""
## Position on the world layer; the hub sits at (0, 0).
@export var world_cell: Vector2i = Vector2i.ZERO
@export var accent: Color = Color(0.77, 0.61, 0.53)
## Story flag that opens this biome on the map; empty means always open.
@export var unlock_flag: StringName = &""
@export var rooms: Array[RoomMapData] = []


func find_room(scene_path: String) -> RoomMapData:
	for room: RoomMapData in rooms:
		if room.scene_path == scene_path:
			return room
	return null


func get_status(progress: MapProgress, unlocked: bool) -> Status:
	if rooms.is_empty():
		return Status.UNCHARTED
	if not unlocked:
		return Status.LOCKED
	return Status.EXPLORED if count_visited(progress) > 0 else Status.UNEXPLORED


func count_visited(progress: MapProgress) -> int:
	var count := 0
	for room: RoomMapData in rooms:
		if progress.has_visited(room.scene_path):
			count += 1
	return count


## Rooms the player can know about: hidden rooms count only once entered.
func count_known(progress: MapProgress) -> int:
	var count := 0
	for room: RoomMapData in rooms:
		if not room.hidden or progress.has_visited(room.scene_path):
			count += 1
	return count
