class_name MapProgress
extends RefCounted
## Rooms the player has entered. Owned by GameManager so it survives scene changes;
## a new game starts empty and a loaded game restores it from the save slot.

var current_room: String = ""
var _visited: Dictionary[String, bool] = {}


func enter_room(scene_path: String) -> void:
	if scene_path.is_empty():
		return
	current_room = scene_path
	_visited[scene_path] = true


func has_visited(scene_path: String) -> bool:
	return _visited.has(scene_path)


func get_visited_rooms() -> PackedStringArray:
	var rooms := PackedStringArray(_visited.keys())
	rooms.sort()
	return rooms


## Replaces the explored rooms with saved ones.
func restore(visited_rooms: Array[String], saved_current_room: String) -> void:
	_visited.clear()
	for scene_path: String in visited_rooms:
		if not scene_path.is_empty():
			_visited[scene_path] = true
	current_room = saved_current_room
