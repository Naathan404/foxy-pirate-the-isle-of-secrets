@tool
extends RefCounted
## Read saved exit metadata without instantiating destination gameplay nodes.

const ROOM_SCRIPT := "res://world/biomes/base/base_room.gd"
const TRIGGER_SCRIPT := "res://world/components/scene_change_trigger.gd"
const DIRECTIONS := ["up", "right", "down", "left"]
const PATH_NAMES := ["UpPath", "RightPath", "DownPath", "LeftPath"]


static func get_exit_ids(scene_path: String) -> PackedStringArray:
	var ids := PackedStringArray()
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path, "PackedScene"):
		return ids
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return ids
	var nodes: Dictionary = {}
	_collect(packed.get_state(), "", nodes)
	# BaseRoom owns its four path IDs and enabled flags; saved child values may
	# still be the defaults from the path scene, so use the room's overrides.
	for path: String in nodes:
		var properties: Dictionary = nodes[path]
		if not _uses_script(properties.get("script"), ROOM_SCRIPT):
			continue
		var flags := int(properties.get("open_exits", 15))
		for index in DIRECTIONS.size():
			var child_path := _join(path, "Exits/" + PATH_NAMES[index] + "/SceneChangeTrigger")
			if nodes.has(child_path):
				nodes[child_path]["enabled"] = bool(flags & (1 << index))
				nodes[child_path]["trigger_id"] = properties.get(DIRECTIONS[index] + "_trigger_id", DIRECTIONS[index])
	for properties: Dictionary in nodes.values():
		if _uses_script(properties.get("script"), TRIGGER_SCRIPT) and properties.get("enabled", true):
			var id := String(properties.get("trigger_id", ""))
			if not id.is_empty():
				ids.append(id)
	ids.sort()
	return ids


static func configure_dropdown(property: Dictionary, scene_path: String, selected: StringName) -> void:
	var choices := PackedStringArray([""])
	for id: String in get_exit_ids(scene_path):
		if not choices.has(id):
			choices.append(id)
	# Preserve stale values so a rename does not silently rewire an existing door.
	if not choices.has(String(selected)):
		choices.append(String(selected))
	property.hint = PROPERTY_HINT_ENUM
	property.hint_string = ",".join(choices)


static func destination_warning(scene_path: String, id: StringName) -> String:
	if scene_path.is_empty():
		return "Choose a Destination Scene."
	if not ResourceLoader.exists(scene_path, "PackedScene"):
		return "Destination Scene does not exist or is not a scene."
	if id.is_empty():
		return "Choose a Destination Trigger Id; leaving it empty uses the scene's default spawn."
	var count := get_exit_ids(scene_path).count(String(id))
	if count == 0:
		return "Destination exit '%s' is missing or disabled. Save the destination scene, then refresh exits." % id
	if count > 1:
		return "Destination exit ID '%s' is duplicated. Give each exit a unique ID." % id
	return ""


static func _collect(state: SceneState, prefix: String, nodes: Dictionary) -> void:
	var base := state.get_base_scene_state()
	if base != null:
		_collect(base, prefix, nodes)
	for index in state.get_node_count():
		var path := _join(prefix, String(state.get_node_path(index)))
		var instance := state.get_node_instance(index)
		if instance != null:
			_collect(instance.get_state(), path, nodes)
		if not nodes.has(path):
			nodes[path] = {}
		for property_index in state.get_node_property_count(index):
			nodes[path][String(state.get_node_property_name(index, property_index))] = state.get_node_property_value(index, property_index)


static func _join(prefix: String, path: String) -> String:
	path = path.trim_prefix("./")
	if path == "." or path.is_empty():
		return prefix
	return path if prefix.is_empty() else prefix + "/" + path


static func _uses_script(value: Variant, path: String) -> bool:
	var script := value as Script
	while script != null:
		if script.resource_path == path:
			return true
		script = script.get_base_script()
	return false
