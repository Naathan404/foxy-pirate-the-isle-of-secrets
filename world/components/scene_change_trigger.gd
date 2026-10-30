class_name SceneChangeTrigger
extends Area3D
## Place at a map exit; GameManager owns the fade and scene replacement.

@export var trigger_id: StringName = &""
@export_file("*.tscn") var destination_scene: String = ""
@export var destination_trigger_id: StringName = &""
@export var enabled: bool = true

@onready var _exit_position: Marker3D = $ExitPosition


func _ready() -> void:
	add_to_group("scene_change_triggers")
	body_entered.connect(_on_body_entered)


func get_exit_position() -> Vector3:
	return _exit_position.global_position


func _on_body_entered(body: Node3D) -> void:
	var player := body as Player
	if not enabled or player == null or player.dead or destination_scene.is_empty():
		return
	get_node("/root/GameManager").change_scene(destination_scene, destination_trigger_id)
