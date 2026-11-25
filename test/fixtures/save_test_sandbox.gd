extends RefCounted
## Shared setup for the save/load tests. Every file a test writes goes to its own folder
## under user://test_saves/, and teardown() proves the player's real files were untouched.

const SANDBOX_ROOT := "user://test_saves"
const REAL_SLOT_PATH := "user://saves/slot_1.json"
const REAL_MERCHANT_PATH := "user://silas_progress.save"
const REAL_NOTES_PATH := "user://monster_notes.save"
const TEST_FADE_SECONDS := 0.01
const ACTION_INTERACT := &"dialogic_default_action"
const REST_MENU_TIMEOUT_MSEC := 5000

var directory: String
var slot_path: String
var manager: Node
var merchant: SilasProgressStore
var notes: Node
var _tree: SceneTree
var _real_files: Dictionary[String, String] = {}
var _previous_slot: SaveGameFile
var _previous_merchant_path: String
var _previous_notes_path: String
var _previous_fades: Array[float] = []


func setup(tree: SceneTree, test_name: String) -> void:
	_tree = tree
	manager = tree.root.get_node("GameManager")
	merchant = tree.root.get_node("SilasProgress") as SilasProgressStore
	notes = tree.root.get_node("NoteProgress")
	for real_path: String in [REAL_SLOT_PATH, REAL_MERCHANT_PATH, REAL_NOTES_PATH]:
		_real_files[real_path] = _fingerprint_file(real_path)
	directory = "%s/%s_%d" % [SANDBOX_ROOT, test_name, Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	slot_path = directory.path_join("slot_1.json")
	_previous_slot = manager.save_slot
	manager.save_slot = SaveGameFile.new(slot_path)
	_previous_merchant_path = merchant.save_path
	merchant.save_path = directory.path_join("silas_progress.save")
	_previous_notes_path = notes.save_path
	notes.save_path = directory.path_join("monster_notes.save")
	_previous_fades = [manager.fade_out_seconds, manager.fade_in_seconds]
	manager.fade_out_seconds = TEST_FADE_SECONDS
	manager.fade_in_seconds = TEST_FADE_SECONDS


## Returns false when any real save file changed while the test ran.
func teardown() -> bool:
	manager.save_slot = _previous_slot
	merchant.save_path = _previous_merchant_path
	notes.save_path = _previous_notes_path
	manager.fade_out_seconds = _previous_fades[0]
	manager.fade_in_seconds = _previous_fades[1]
	_remove_tree(directory)
	# Only succeeds when no other test run still owns a folder in it.
	DirAccess.remove_absolute(SANDBOX_ROOT)
	var untouched := true
	for real_path: String in _real_files:
		if _fingerprint_file(real_path) != _real_files[real_path]:
			untouched = false
	return untouched


func read_slot_text() -> String:
	return FileAccess.get_file_as_string(slot_path) if FileAccess.file_exists(slot_path) else ""


func write_slot_text(text: String) -> void:
	var file := FileAccess.open(slot_path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func write_slot_payload(payload: Dictionary) -> void:
	write_slot_text(JSON.stringify(payload, "\t"))


func read_slot_payload() -> Dictionary:
	var json := JSON.new()
	if json.parse(read_slot_text()) != OK or not json.data is Dictionary:
		return {}
	return json.data


func find_rest_points(scene: Node) -> Array[CampfireRestPoint]:
	var result: Array[CampfireRestPoint] = []
	for node: Node in scene.find_children("*", "", true, false):
		if node is CampfireRestPoint:
			result.append(node as CampfireRestPoint)
	return result


## Presses and releases an action through the root viewport, so it reaches GUI and
## _unhandled_input like a key press. Headless Input.parse_input_event never reaches it.
func press_action(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		_tree.root.push_input(event)
		await _tree.process_frame


## Resting fades to black before the Campfire menu opens. Returns whether it opened.
func wait_rest_menu(rest_point: CampfireRestPoint) -> bool:
	var deadline := Time.get_ticks_msec() + REST_MENU_TIMEOUT_MSEC
	while not rest_point.is_menu_open() and Time.get_ticks_msec() < deadline:
		await _tree.process_frame
	return rest_point.is_menu_open()


func frames(count: int) -> void:
	for _frame in count:
		await _tree.physics_frame


## Waits for one GameManager transition started by the caller.
func wait_transition() -> void:
	await manager.scene_transition_finished
	await frames(2)


## Plain values describing all saved progress, read through public gameplay APIs only,
## so a test can compare state before saving and after loading.
func fingerprint() -> Dictionary:
	var player: Player = manager.player
	var inventory := player.get_node("Inventory") as Inventory
	var slots: Array[String] = []
	for slot: InventorySlot in inventory.slots:
		slots.append("" if slot.is_empty() else "%s x%d" % [slot.item.item_id, slot.quantity])
	var capacities: Array[int] = []
	for kind: int in Potion.Kind.values():
		capacities.append(inventory.get_potion_capacity(kind))
	var weapons: Array[String] = []
	var controller := player.weapon_controller
	for entry: WeaponCollectionEntry in controller.collection:
		var weapon_id := entry.definition.weapon_id
		var forge := ""
		for weapon: WeaponInstance in controller.get_owned_weapons():
			if weapon.definition.weapon_id == weapon_id and weapon.forge != null:
				forge = String(weapon.forge.forge_id)
		(
			weapons
			. append(
				(
					"%s owned=%s blueprint=%s forge=%s"
					% [
						weapon_id,
						controller.is_weapon_owned(weapon_id),
						controller.is_blueprint_unlocked(weapon_id),
						forge,
					]
				)
			)
		)
	var sockets: Array[String] = []
	for socket_id: int in range(CharmConstants.MAX_SOCKET_COUNT):
		sockets.append(String(player.charm_socket_manager.get_equipped_charm(socket_id)))
	var bosses := {}
	for encounter_id: StringName in manager.boss_encounters:
		var state: Dictionary = manager.boss_encounters[encounter_id]
		var items: Array[String] = []
		for index: int in state.get("items", {}):
			var entry: Dictionary = state.items[index]
			items.append("%d:%s x%d" % [index, entry.item.item_id, entry.quantity])
		items.sort()
		bosses[String(encounter_id)] = (
			"defeated=%s opened=%s at=%s items=%s"
			% [state.get("defeated"), state.get("opened"), state.get("position"), items]
		)
	var flags: Array[String] = []
	for flag: StringName in manager.story_flags:
		flags.append(String(flag))
	flags.sort()
	return {
		"hp": player.hp.get_current_hp(),
		"max_hp": player.hp.get_max_hp(),
		"sp": player.stamina.get_current_sp(),
		"max_sp": player.stamina.get_max_sp(),
		"slots": slots,
		"potion_capacities": capacities,
		"primary_potion": _item_id(player.potion.equipped_potion),
		"secondary_potion": _item_id(player.potion.secondary_potion),
		"weapons": weapons,
		"equipped_weapon": String(controller.equipped.definition.weapon_id),
		"owned_charms": player.charm_registry.get_owned_ids(),
		"unlocked_sockets": player.charm_socket_manager.get_unlocked_socket_count(),
		"sockets": sockets,
		"gold": manager.gold_wallet.get_balance(),
		"visited_rooms": manager.map_progress.get_visited_rooms(),
		"story_flags": flags,
		"bosses": bosses,
		"notes": notes.get_save_data(),
		"merchant": merchant.get_save_data(),
	}


## Lists the keys whose values differ, for readable failure messages.
static func describe_difference(expected: Dictionary, actual: Dictionary) -> String:
	var differences: Array[String] = []
	for key: String in expected:
		if var_to_str(expected[key]) != var_to_str(actual.get(key)):
			differences.append("%s: expected %s, got %s" % [key, expected[key], actual.get(key)])
	return "; ".join(differences)


func _item_id(item: BaseItem) -> String:
	return item.item_id if item != null else ""


func _fingerprint_file(file_path: String) -> String:
	if not FileAccess.file_exists(file_path):
		return "<missing>"
	return "%s:%d" % [FileAccess.get_md5(file_path), FileAccess.get_modified_time(file_path)]


func _remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for sub_directory: String in dir.get_directories():
		_remove_tree(path.path_join(sub_directory))
	for file_name: String in dir.get_files():
		DirAccess.remove_absolute(path.path_join(file_name))
	DirAccess.remove_absolute(path)
