extends Node
## Quản lý trạng thái gameplay và truy cập Player

signal player_changed(active_player: Player)
signal state_changed(new_state: State)

enum State { PLAYING, INVENTORY }

var player: Player
var inventory: Inventory
var state: State = State.PLAYING
var _reload_pending: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func register_player(active_player: Player) -> void:
	if not is_instance_valid(active_player) or player == active_player:
		return
	if is_instance_valid(player) and is_instance_valid(player.inventory_ui):
		player.inventory_ui.close_inventory()
	player = active_player
	inventory = player.get_node_or_null("Inventory") as Inventory
	player_changed.emit(player)


func unregister_player(departing_player: Player) -> void:
	# Player cũ rời scene không được xóa tham chiếu đến Player mới
	if player != departing_player:
		return
	exit_inventory()
	player = null
	inventory = null
	player_changed.emit(null)


func enter_inventory() -> bool:
	if state != State.PLAYING or get_tree().paused:
		return false
	if is_instance_valid(player):
		player.clear_gameplay_input()
	state = State.INVENTORY
	get_tree().paused = true
	state_changed.emit(state)
	return true


func exit_inventory() -> void:
	if state != State.INVENTORY:
		return
	state = State.PLAYING
	get_tree().paused = false
	state_changed.emit(state)


func reload_current_scene() -> void:
	if _reload_pending:
		return
	var scene: Node = get_tree().current_scene
	if not is_instance_valid(scene) or scene.scene_file_path.is_empty():
		push_warning("GameManager: không có scene đã lưu để reload.")
		return
	_reload_pending = true
	# Đổi scene sau khi callback physics/animation hiện tại đã xử lý xong
	_reload_scene.call_deferred()


func _reload_scene() -> void:
	if is_instance_valid(player) and is_instance_valid(player.inventory_ui):
		player.inventory_ui.close_inventory()
	exit_inventory()
	get_tree().paused = false
	get_node("/root/HitstopController").cancel()
	get_node("/root/ScreenShakeController").cancel()
	var error: Error = get_tree().reload_current_scene()
	_reload_pending = false
	if error != OK:
		push_error("GameManager: reload scene thất bại: %s" % error_string(error))
