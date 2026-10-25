extends Node3D
## Quản lý màn chơi Hub và hồi sinh người chơi tại Checkpoint.

@onready var _player: Player = $Foxy


func _ready() -> void:
	if is_instance_valid(_player.charm_socket_manager):
		_player.charm_socket_manager.enter_safe_location(self)
	respawn_player()


func _unhandled_input(event: InputEvent) -> void:
	# Bấm phím R để test đưa Cáo về Checkpoint (hoặc reload scene đều được)
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		respawn_player()


func respawn_player() -> void:
	for node in get_tree().get_nodes_in_group("spawn_points"):
		if node is Checkpoint and node.is_active():
			_player.global_position = node.get_spawn_position()
			_player.velocity = Vector3.ZERO
			break
