@tool
class_name SceneChangeTrigger
extends Area3D
## Choose a destination scene and its exit in the Inspector.

const EXIT_CATALOG := preload("res://world/components/scene_exit_catalog.gd")

@export var trigger_id: StringName = &"":
	set(value):
		if trigger_id == value:
			return
		trigger_id = value
		_refresh_editor()
## Drag a .tscn from FileSystem here, then choose its saved exit below.
@export_file("*.tscn") var destination_scene: String = "":
	set(value):
		if destination_scene == value:
			return
		destination_scene = value
		_refresh_editor()
## Empty means the destination scene's default player spawn.
@export var destination_trigger_id: StringName = &"":
	set(value):
		if destination_trigger_id == value:
			return
		destination_trigger_id = value
		_refresh_editor()
@export var enabled: bool = true:
	set(value):
		if enabled == value:
			return
		enabled = value
		_refresh_editor()
@export_tool_button("Refresh destination exits", "Reload") var refresh_exits: Callable:
	get:
		return _refresh_editor

@onready var _exit_position: Marker3D = $ExitPosition


func _ready() -> void:
	if Engine.is_editor_hint():
		_refresh_editor()
		return
	add_to_group("scene_change_triggers")
	body_entered.connect(_on_body_entered)


func get_exit_position() -> Vector3:
	return _exit_position.global_position


func _on_body_entered(body: Node3D) -> void:
	var player := body as Player
	if not enabled or player == null or player.dead or destination_scene.is_empty():
		return
	get_node("/root/GameManager").change_scene(destination_scene, destination_trigger_id)


func _refresh_editor() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		notify_property_list_changed()
		update_configuration_warnings()


func _validate_property(property: Dictionary) -> void:
	if Engine.is_editor_hint() and property.name == "destination_trigger_id":
		EXIT_CATALOG.configure_dropdown(property, destination_scene, destination_trigger_id)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not enabled:
		return warnings
	if trigger_id.is_empty():
		warnings.append("Set a unique Trigger Id so other rooms can arrive here.")
	var warning := EXIT_CATALOG.destination_warning(destination_scene, destination_trigger_id)
	if not warning.is_empty():
		warnings.append(warning)
	return warnings
