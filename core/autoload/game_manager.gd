extends Node
## Quản lý trạng thái gameplay và truy cập Player

signal player_changed(active_player: Player)
signal state_changed(new_state: State)
signal scene_transition_finished

enum State { PLAYING, INVENTORY, TRANSITION }

const TRANSITION_OVERLAY := preload("res://ui/scene_transition.tscn")

@export_range(0.01, 2.0, 0.01) var fade_out_seconds: float = 0.25
@export_range(0.01, 2.0, 0.01) var fade_in_seconds: float = 0.25

var player: Player
var inventory: Inventory
var state: State = State.PLAYING
var _transition_pending: bool = false
var _transition_overlay: CanvasLayer
var _fade_rect: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_transition_overlay = TRANSITION_OVERLAY.instantiate() as CanvasLayer
	add_child(_transition_overlay)
	_fade_rect = _transition_overlay.get_node("Fade") as ColorRect


func register_player(active_player: Player) -> void:
	if not is_instance_valid(active_player) or player == active_player:
		return
	if is_instance_valid(player) and is_instance_valid(player.inventory_ui):
		player.inventory_ui.close_inventory(true)
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
	if _transition_pending:
		return
	var scene: Node = get_tree().current_scene
	if not is_instance_valid(scene) or scene.scene_file_path.is_empty():
		push_warning("GameManager: không có scene đã lưu để reload.")
		return
	_request_scene_transition(scene.scene_file_path, true)


## Returns whether the request was accepted; completion is signalled after fade-in.
func change_scene(scene_path: String, destination_trigger_id: StringName = &"") -> bool:
	if _transition_pending or not ResourceLoader.exists(scene_path, "PackedScene"):
		return false
	_request_scene_transition(scene_path, false, destination_trigger_id)
	return true


func _request_scene_transition(
	scene_path: String, reload_scene: bool, destination_trigger_id: StringName = &""
) -> void:
	_transition_pending = true
	# Leave the current physics/animation callback before pausing or freeing its scene.
	_transition_scene.call_deferred(scene_path, reload_scene, destination_trigger_id)


func _transition_scene(
	scene_path: String, reload_scene: bool, destination_trigger_id: StringName
) -> void:
	if is_instance_valid(player) and is_instance_valid(player.inventory_ui):
		player.inventory_ui.close_inventory(true)
	exit_inventory()
	if is_instance_valid(player):
		player.clear_gameplay_input()
	var was_paused := get_tree().paused
	state = State.TRANSITION
	get_tree().paused = true
	get_node("/root/HitstopController").cancel()
	get_node("/root/ScreenShakeController").cancel()
	_transition_overlay.show()
	state_changed.emit(state)
	await _fade_to(1.0, fade_out_seconds)
	var error: Error
	if reload_scene:
		error = get_tree().reload_current_scene()
	else:
		error = get_tree().change_scene_to_file(scene_path)
	if error == OK:
		# SceneTree signals after the new scene has entered the tree and run _ready().
		await get_tree().scene_changed
		if not destination_trigger_id.is_empty():
			_place_player_at_trigger(destination_trigger_id)
	await _fade_to(0.0, fade_in_seconds)
	_transition_overlay.hide()
	if is_instance_valid(player):
		player.clear_gameplay_input()
	state = State.PLAYING
	get_tree().paused = was_paused if error != OK else false
	_transition_pending = false
	state_changed.emit(state)
	scene_transition_finished.emit()
	if error != OK:
		push_error("GameManager: chuyển scene thất bại: %s" % error_string(error))


func _place_player_at_trigger(trigger_id: StringName) -> void:
	var destination: SceneChangeTrigger
	var scene := get_tree().current_scene
	for node: Node in get_tree().get_nodes_in_group("scene_change_triggers"):
		var trigger := node as SceneChangeTrigger
		if trigger == null or (trigger != scene and not scene.is_ancestor_of(trigger)):
			continue
		if trigger.trigger_id != trigger_id:
			continue
		if destination != null:
			push_warning("GameManager: trùng trigger ID '%s' trong scene đích." % trigger_id)
			return
		destination = trigger
	if destination == null:
		push_warning("GameManager: không tìm thấy trigger ID '%s' trong scene đích." % trigger_id)
		return
	if not is_instance_valid(player):
		push_warning("GameManager: scene đích chưa đăng ký Player để đặt tại trigger.")
		return
	player.global_position = destination.get_exit_position()
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()


func _fade_to(alpha: float, duration: float) -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_ignore_time_scale(true)
	tween.tween_property(_fade_rect, "color:a", alpha, duration)
	await tween.finished
