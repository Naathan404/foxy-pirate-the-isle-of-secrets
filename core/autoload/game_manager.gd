extends Node
## Quản lý trạng thái gameplay và truy cập Player

signal player_changed(active_player: Player)
signal state_changed(new_state: State)

enum State { PLAYING, INVENTORY }

var player: Player
var inventory: Inventory
var state: State = State.PLAYING


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
