class_name Checkpoint
extends Area3D
## Điểm lưu tiến độ trong màn chơi, tự quản lý mốc hiện tại.

signal activated(checkpoint_id: String)

static var _current_scene: String = ""
static var _current_id: String = ""

@export var id: String = ""

@onready var _sprite: AnimatedSprite3D = $AnimatedSprite3D
@onready var _spawn_point: Marker3D = $Spawn


func _ready() -> void:
	add_to_group("spawn_points")
	body_entered.connect(_on_body_entered)
	_sprite.play("turn" if is_active() else "idle")


func is_active() -> bool:
	return (
		owner != null
		and _current_id == id
		and _current_scene == owner.scene_file_path
	)


func get_spawn_position() -> Vector3:
	return _spawn_point.global_position


func deactivate_visual() -> void:
	if _sprite != null:
		_sprite.play("idle")


func _on_body_entered(body: Node3D) -> void:
	if not (body is Player) or is_active():
		return

	if owner == null or owner.scene_file_path.is_empty():
		push_warning("Checkpoint '%s' chưa nằm trong scene hợp lệ." % id)
		return

	for node in get_tree().get_nodes_in_group("spawn_points"):
		if node is Checkpoint and node != self:
			node.deactivate_visual()

	_current_scene = owner.scene_file_path
	_current_id = id
	_sprite.play("turn")
	activated.emit(id)
