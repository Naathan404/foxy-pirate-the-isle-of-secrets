class_name MapProgress
extends RefCounted
## Rooms the player has entered this session. Owned by GameManager so it survives
## scene changes; there is no save file yet, so a new session starts empty.

var current_room: String = ""
var _visited: Dictionary[String, bool] = {}


func enter_room(scene_path: String) -> void:
	if scene_path.is_empty():
		return
	current_room = scene_path
	_visited[scene_path] = true


func has_visited(scene_path: String) -> bool:
	return _visited.has(scene_path)
