extends Node
## Quản lý trạng thái gameplay và truy cập Player

signal player_changed(active_player: Player)
signal state_changed(new_state: State)
signal scene_transition_finished
## Emitted after a Continue transition settles; `error` is OK only when the saved room,
## campfire and progress were all restored.
signal saved_game_loaded(error: Error)

enum State { PLAYING, INVENTORY, TRANSITION, PAUSE_MENU, WORLD_MAP, REST_MENU }

const TRANSITION_OVERLAY := preload("res://ui/scene_transition.tscn")
const PLAYER_SCENE_STATE := preload("res://core/autoload/player_scene_state.gd")
const SAVE_SLOT_PATH := "user://saves/slot_1.json"
const BIOMES_ROOT := "res://world/biomes/"

@export_file("*.tscn") var main_menu_scene: String = "res://ui/main_menu/main_menu.tscn"
## Where Foxy respawns before resting at any campfire: its first campfire.
@export_file("*.tscn")
var fallback_rest_scene: String = "res://world/biomes/hub/map/castaway_cove.tscn"
@export_range(0.01, 2.0, 0.01) var fade_out_seconds: float = 0.3
@export_range(0.01, 2.0, 0.01) var fade_in_seconds: float = 0.35

var player: Player
var inventory: Inventory
var gold_wallet: GoldWallet = GoldWallet.new()
var map_progress: MapProgress = MapProgress.new()
var state: State = State.PLAYING
## Encounter state survives scene changes for the current game session.
var boss_encounters: Dictionary[StringName, Dictionary] = {}
## Story progress for this session, e.g. which biomes are open. In memory only, like Gold.
var story_flags: Dictionary[StringName, bool] = {}
# Debug-only progression flag. Each map owns a fresh Player scene, so keep the
# HUD grant state on the autoload instead of on the scene-local CharmRegistry.
var debug_all_charms_granted: bool = false
## The single save slot. Tests point its path at their own directory.
var save_slot: SaveGameFile = SaveGameFile.new(SAVE_SLOT_PATH)
## Visited-room changes and the campfire of the latest rest; see RoomStateRegistry.
var room_states: RoomStateRegistry = RoomStateRegistry.new()
var _transition_pending: bool = false
## Validated save payload consumed by the next scene transition (Continue).
var _pending_load: Dictionary = {}
## Campfire the next transition places Foxy at after a death (empty path: first one).
var _pending_respawn_point: Variant = null
var _transition_overlay: CanvasLayer
var _fade_rect: ColorRect
## Rooms the current room's exits lead to, loaded in the background after each arrival so
## walking through an exit does not wait on the disk. Only the current neighbours are kept.
var _neighbor_scenes: Dictionary[String, PackedScene] = {}
## Neighbour paths whose threaded load is still running.
var _neighbor_requests: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_transition_overlay = TRANSITION_OVERLAY.instantiate() as CanvasLayer
	add_child(_transition_overlay)
	_fade_rect = _transition_overlay.get_node("Fade") as ColorRect
	set_process(false)


## Background loads cut off by quitting fail with parse errors; let them finish first.
func _exit_tree() -> void:
	for path: String in _neighbor_requests:
		ResourceLoader.load_threaded_get(path)
	_neighbor_requests.clear()
	_neighbor_scenes.clear()


## Collects finished neighbour loads; runs only while some are in flight.
func _process(_delta: float) -> void:
	for path: String in _neighbor_requests.duplicate():
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		_neighbor_requests.erase(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var scene := ResourceLoader.load_threaded_get(path) as PackedScene
			if scene != null:
				_neighbor_scenes[path] = scene
	set_process(not _neighbor_requests.is_empty())


func register_player(active_player: Player) -> void:
	if not is_instance_valid(active_player) or player == active_player:
		return
	if is_instance_valid(player) and is_instance_valid(player.inventory_ui):
		player.inventory_ui.close_inventory(true)
	player = active_player
	inventory = player.get_node_or_null("Inventory") as Inventory
	# Foxy is instanced in each room scene, so its owner is the room the player is in.
	if is_instance_valid(player.owner):
		map_progress.enter_room(player.owner.scene_file_path)
	if (
		OS.is_debug_build()
		and debug_all_charms_granted
		and is_instance_valid(player.charm_socket_manager)
	):
		player.charm_socket_manager.debug_set_all_charms(true)
	player_changed.emit(player)


func set_debug_all_charms_granted(granted: bool) -> void:
	if not OS.is_debug_build():
		return
	debug_all_charms_granted = granted


func unregister_player(departing_player: Player) -> void:
	# Player cũ rời scene không được xóa tham chiếu đến Player mới
	if player != departing_player:
		return
	exit_inventory()
	player = null
	inventory = null
	player_changed.emit(null)


func enter_inventory() -> bool:
	if _transition_pending or state != State.PLAYING or get_tree().paused:
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


## The pause menu owns the tree pause the same way the inventory does.
func enter_pause_menu() -> bool:
	return _enter_menu_state(State.PAUSE_MENU)


func exit_pause_menu() -> void:
	_exit_menu_state(State.PAUSE_MENU)


func enter_world_map() -> bool:
	return _enter_menu_state(State.WORLD_MAP)


func exit_world_map() -> void:
	_exit_menu_state(State.WORLD_MAP)


## A campfire rest menu owns the pause like the other full-screen menus.
func enter_rest_menu() -> bool:
	return _enter_menu_state(State.REST_MENU)


func exit_rest_menu() -> void:
	_exit_menu_state(State.REST_MENU)


## Writes the slot from a campfire. Only a campfire whose room has `safe_room` enabled may
## save, and only for the Player standing in that room. The previous save is kept on error.
func save_game(rest_point: CampfireRestPoint) -> Error:
	if _transition_pending:
		return ERR_BUSY
	if not is_instance_valid(rest_point) or not rest_point.is_inside_tree():
		return ERR_INVALID_PARAMETER
	if not rest_point.is_save_allowed():
		return ERR_UNAUTHORIZED
	var room := rest_point.get_room()
	if not is_instance_valid(player) or player.dead or not room.is_ancestor_of(player):
		return ERR_UNAVAILABLE
	if room.scene_file_path.is_empty():
		return ERR_UNCONFIGURED
	var location := rest_point.get_location()
	var payload := GameSaveSnapshot.capture(
		player, location, self, _get_merchant_progress(), _get_note_progress()
	)
	var problem := GameSaveSnapshot.validate(payload)
	if not problem.is_empty():
		push_warning("GameManager: refusing to write an invalid save: %s" % problem)
		return ERR_INVALID_DATA
	return save_slot.write(payload)


## Starts the transition to the saved campfire. Returns OK when it was accepted; the result
## of the load itself arrives through `saved_game_loaded`.
func load_saved_game() -> Error:
	if _transition_pending:
		return ERR_BUSY
	var saved := save_slot.read()
	if saved.error != OK:
		return saved.error
	var scene_path := GameSaveSnapshot.get_scene_path(saved.payload)
	if not ResourceLoader.exists(scene_path, "PackedScene"):
		return ERR_FILE_NOT_FOUND
	_pending_load = saved.payload
	if not change_scene(scene_path):
		_pending_load = {}
		return ERR_CANT_OPEN
	return OK


## New Game never inherits the last run: session state and the merchant/note stores reset.
## The save slot itself is kept until the player saves again.
func start_new_game(scene_path: String) -> bool:
	if _transition_pending or not ResourceLoader.exists(scene_path, "PackedScene"):
		return false
	reset_session()
	_get_merchant_progress().reset_progress()
	_get_note_progress().reset_progress()
	return change_scene(scene_path)


func has_story_flag(flag: StringName) -> bool:
	return story_flags.get(flag, false)


func set_story_flag(flag: StringName) -> void:
	if not flag.is_empty():
		story_flags[flag] = true


## Full-screen menus pause the tree only when nothing else owns it.
func _enter_menu_state(menu_state: State) -> bool:
	if _transition_pending or state != State.PLAYING or get_tree().paused:
		return false
	if is_instance_valid(player):
		player.clear_gameplay_input()
	state = menu_state
	get_tree().paused = true
	state_changed.emit(state)
	return true


func _exit_menu_state(menu_state: State) -> void:
	if state != menu_state:
		return
	if is_instance_valid(player):
		player.clear_gameplay_input()
	state = State.PLAYING
	get_tree().paused = false
	state_changed.emit(state)


## Leaves the current run for the main menu; returns whether the transition was accepted.
func return_to_main_menu() -> bool:
	return change_scene(main_menu_scene)


## Forgets the in-memory run (wallet, explored rooms, room changes, latest rest, story
## flags, boss encounters, debug grants). Saved files are untouched.
func reset_session() -> void:
	gold_wallet = GoldWallet.new()
	map_progress = MapProgress.new()
	room_states = RoomStateRegistry.new()
	story_flags.clear()
	boss_encounters.clear()
	debug_all_charms_granted = false


## Death works like resting: the rooms start a new cycle and Foxy comes back beside the
## campfire of the latest rest (the first campfire before any rest) with full HP and SP,
## keeping all progress. Returns whether the transition was accepted.
func respawn_at_last_rest() -> bool:
	if _transition_pending:
		return false
	var location := room_states.rest_location
	var scene_path := String(location.get("scene", ""))
	var rest_point := NodePath(String(location.get("rest_point", "")))
	if not ResourceLoader.exists(scene_path, "PackedScene"):
		scene_path = fallback_rest_scene
		rest_point = NodePath()
	if not ResourceLoader.exists(scene_path, "PackedScene"):
		push_error("GameManager: không có scene lửa trại để hồi sinh.")
		return false
	room_states.begin_new_cycle(location)
	_pending_respawn_point = rest_point
	_request_scene_transition(scene_path, true)
	return true


## Returns whether the request was accepted; completion is signalled after fade-in.
func change_scene(scene_path: String, destination_trigger_id: StringName = &"") -> bool:
	if _transition_pending or not ResourceLoader.exists(scene_path, "PackedScene"):
		return false
	_request_scene_transition(scene_path, false, destination_trigger_id)
	return true


## `respawn` restores progress but starts the new Player at full health and stamina.
func _request_scene_transition(
	scene_path: String, respawn: bool, destination_trigger_id: StringName = &""
) -> void:
	_transition_pending = true
	# Leave the current physics/animation callback before pausing or freeing its scene.
	_transition_scene.call_deferred(scene_path, respawn, destination_trigger_id)


func _transition_scene(
	scene_path: String, respawn: bool, destination_trigger_id: StringName
) -> void:
	var load_payload := _pending_load
	_pending_load = {}
	var respawn_point: Variant = _pending_respawn_point
	_pending_respawn_point = null
	if is_instance_valid(player) and is_instance_valid(player.inventory_ui):
		player.inventory_ui.close_inventory(true)
	exit_inventory()
	if is_instance_valid(player):
		player.clear_gameplay_input()
	var was_paused := get_tree().paused
	# A failed transition returns to whatever owned the pause (e.g. the pause menu).
	var previous_state := state
	state = State.TRANSITION
	get_tree().paused = true
	get_node("/root/HitstopController").cancel()
	get_node("/root/ScreenShakeController").cancel()
	_transition_overlay.show()
	state_changed.emit(state)
	# A neighbour preloaded after the last arrival is ready at once. Otherwise read the
	# destination in parallel with fade-out, without blocking a frame.
	var destination: PackedScene = _neighbor_scenes.get(scene_path)
	var load_error := OK
	if destination == null and not _neighbor_requests.has(scene_path):
		load_error = ResourceLoader.load_threaded_request(scene_path, "PackedScene")
	# A neighbour load still in flight is finished here instead of by _process.
	_neighbor_requests.erase(scene_path)
	await _fade_to(1.0, fade_out_seconds)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	var player_state: RefCounted
	# A loaded game replaces the whole run, so nothing is carried over from this Player.
	if is_instance_valid(player) and load_payload.is_empty():
		player_state = PLAYER_SCENE_STATE.new()
		player_state.capture(player)
	var error: Error = load_error
	if error == OK and destination == null:
		while (
			ResourceLoader.load_threaded_get_status(scene_path)
			== ResourceLoader.THREAD_LOAD_IN_PROGRESS
		):
			await get_tree().process_frame
		if ResourceLoader.load_threaded_get_status(scene_path) == ResourceLoader.THREAD_LOAD_LOADED:
			destination = ResourceLoader.load_threaded_get(scene_path) as PackedScene
		if destination == null:
			error = ERR_CANT_OPEN
	if error == OK:
		if not load_payload.is_empty():
			error = _prepare_saved_world(destination, load_payload)
		if error == OK:
			error = get_tree().change_scene_to_packed(destination)
	if error == OK:
		# SceneTree signals after the new scene has entered the tree and run _ready().
		await get_tree().scene_changed
		if not load_payload.is_empty():
			error = _arrive_at_saved_rest_point(load_payload)
		elif player_state != null and is_instance_valid(player):
			player_state.restore(player, not respawn)
		if respawn_point != null:
			_place_player_at_rest_point(_find_rest_point(get_tree().current_scene, respawn_point))
		if not destination_trigger_id.is_empty():
			_place_player_at_trigger(destination_trigger_id)
		# _ready/process_frame do not mean rendering has finished. Keep the first
		# draw and its resource/pipeline setup behind black, including deferred UI.
		_settle_arrival_camera()
		await _prepare_arrival_render()
	# Resume before revealing the room so held movement continues during fade-in.
	if is_instance_valid(player):
		player.clear_gameplay_input()
	state = previous_state if error != OK else State.PLAYING
	get_tree().paused = was_paused if error != OK else false
	state_changed.emit(state)
	# The first active physics/animation tick can also upload new visual resources.
	# Finish that tick behind black instead of letting it stall the visible fade.
	await _prepare_arrival_render(6)
	await _fade_to(0.0, fade_in_seconds)
	_transition_overlay.hide()
	_transition_pending = false
	if error == OK:
		_get_merchant_progress().note_area_entered(_get_area_id(scene_path))
		_preload_neighbors()
	scene_transition_finished.emit()
	if not load_payload.is_empty():
		# A rejected save is an expected outcome reported to the menu, not an engine fault.
		if error != OK:
			push_warning("GameManager: không thể tải save: %s" % error_string(error))
		saved_game_loaded.emit(error)
	elif error != OK:
		push_error("GameManager: chuyển scene thất bại: %s" % error_string(error))


## Runs behind the black fade, before the saved room replaces the current scene. The saved
## campfire and a Player must exist, otherwise the current scene is kept untouched.
func _prepare_saved_world(destination: PackedScene, payload: Dictionary) -> Error:
	if destination == null:
		return ERR_CANT_OPEN
	var room := destination.instantiate()
	var has_rest_point := (
		room.get_node_or_null(GameSaveSnapshot.get_rest_point_path(payload)) is CampfireRestPoint
	)
	var has_player := _contains_player(room)
	room.free()
	if not has_rest_point:
		return ERR_DOES_NOT_EXIST
	if not has_player:
		return ERR_UNCONFIGURED
	GameSaveSnapshot.restore_world(payload, self, _get_merchant_progress(), _get_note_progress())
	return OK


func _arrive_at_saved_rest_point(payload: Dictionary) -> Error:
	var scene := get_tree().current_scene
	var rest_point := (
		scene.get_node_or_null(GameSaveSnapshot.get_rest_point_path(payload)) as CampfireRestPoint
	)
	if rest_point == null or not is_instance_valid(player) or not scene.is_ancestor_of(player):
		return ERR_DOES_NOT_EXIST
	GameSaveSnapshot.restore_player(payload, player)
	_place_player_at_rest_point(rest_point)
	return OK


## An empty path or a campfire that no longer exists falls back to the room's first one.
func _find_rest_point(scene: Node, path: NodePath) -> CampfireRestPoint:
	if not path.is_empty():
		var found := scene.get_node_or_null(path) as CampfireRestPoint
		if found != null:
			return found
	for node: Node in scene.find_children("*", "", true, false):
		if node is CampfireRestPoint:
			return node as CampfireRestPoint
	return null


func _place_player_at_rest_point(rest_point: CampfireRestPoint) -> void:
	if rest_point == null or not is_instance_valid(player):
		push_warning("GameManager: không tìm thấy lửa trại để đặt Player.")
		return
	player.global_position = rest_point.get_spawn_position()
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()


func _contains_player(node: Node) -> bool:
	if node is Player:
		return true
	for child: Node in node.get_children():
		if _contains_player(child):
			return true
	return false


## The biome folder of a room scene (`res://world/biomes/<area>/...`); empty for other scenes.
func _get_area_id(scene_path: String) -> StringName:
	if not scene_path.begins_with(BIOMES_ROOT):
		return &""
	return StringName(scene_path.trim_prefix(BIOMES_ROOT).get_slice("/", 0))


func _get_merchant_progress() -> SilasProgressStore:
	return get_node("/root/SilasProgress") as SilasProgressStore


func _get_note_progress() -> Node:
	return get_node("/root/NoteProgress")


## Starts background loads of the scenes this room's exits lead to and forgets the rest.
func _preload_neighbors() -> void:
	var scene := get_tree().current_scene
	var wanted: Array[String] = []
	for node: Node in get_tree().get_nodes_in_group("scene_change_triggers"):
		var trigger := node as SceneChangeTrigger
		if trigger == null or scene == null or not scene.is_ancestor_of(trigger):
			continue
		var path := trigger.destination_scene
		if path.is_empty() or wanted.has(path) or path == scene.scene_file_path:
			continue
		if ResourceLoader.exists(path, "PackedScene"):
			wanted.append(path)
	for path: String in _neighbor_scenes.keys():
		if not wanted.has(path):
			_neighbor_scenes.erase(path)
	for path: String in wanted:
		if _neighbor_scenes.has(path) or _neighbor_requests.has(path):
			continue
		if ResourceLoader.load_threaded_request(path, "PackedScene") == OK:
			_neighbor_requests.append(path)
	set_process(not _neighbor_requests.is_empty())


func _prepare_arrival_render(frame_count: int = 2) -> void:
	if DisplayServer.get_name() != "headless":
		for frame in frame_count:
			await RenderingServer.frame_post_draw
	# Start the fade on a fresh tick, rather than consuming the load hitch as its delta.
	await get_tree().process_frame


func _place_player_at_trigger(trigger_id: StringName) -> void:
	var destination: SceneChangeTrigger = null
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


func _settle_arrival_camera() -> void:
	if not is_instance_valid(player) or not is_instance_valid(player.camera):
		return
	var follow_camera := player.camera as BoundedFollowCamera3D
	if follow_camera != null:
		follow_camera.snap_to_follow()
	else:
		player.camera.reset_physics_interpolation()


func _fade_to(alpha: float, duration: float) -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_ignore_time_scale(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_fade_rect, "color:a", alpha, duration)
	await tween.finished
