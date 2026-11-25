extends SceneTree
## Save/Load edge cases on real rooms: missing or damaged saves, unsupported versions,
## missing scene or campfire, write failures, unsafe campfires, per-system boundary values,
## unknown IDs and the spawn beside every campfire in the project.
## Writes only under user://test_saves/ and fails if the player's real saves change.

const SANDBOX := preload("res://test/fixtures/save_test_sandbox.gd")
const MAIN_MENU := preload("res://ui/main_menu/main_menu.tscn")
const CORAL_ROOM := "res://world/biomes/coral_valley/map/room_00.tscn"
## Every room that currently places a campfire.
const CAMPFIRE_ROOMS: Array[String] = [
	"res://world/biomes/hub/map/castaway_cove.tscn",
	"res://world/biomes/hub/map/room_02.tscn",
	"res://world/biomes/coral_valley/map/room_00.tscn",
	"res://world/biomes/coral_valley/map/room_05.tscn",
]
const TEST_CHARM := &"turtle_shell"
const UNKNOWN_ID := "save_test_unknown_id"
## The campfire's MovementBody radius in world units (1.0 local at the campfire's scale 2).
const CAMPFIRE_BODY_RADIUS := 2.0
const SETTLE_FRAMES := 60
const SPAWN_TOLERANCE := 0.75
const FALL_TOLERANCE := 0.5
const DAMAGE_RATIO := 0.5
const LOW_STAMINA_RATIO := 0.1

var sandbox := SANDBOX.new()
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	sandbox.setup(self, "edge")
	await _check_no_save()
	var good := await _create_good_save()
	await _check_rejected_files(good)
	await _check_menu_with_damaged_save()
	await _check_missing_targets(good)
	await _check_write_failure()
	_check_interrupted_write()
	await _check_unsafe_campfire()
	await _check_data_groups(good)
	await _check_campfire_spawns()
	_check(sandbox.teardown(), "real user saves are untouched")
	print("Save/load edge failures: ", failures)
	quit(1 if failures > 0 else 0)


func _check_no_save() -> void:
	var manager := sandbox.manager
	_check(manager.save_slot.read().error == ERR_FILE_NOT_FOUND, "no save: read reports none")
	_check(not manager.save_slot.exists(), "no save: slot file is absent")
	_check(manager.load_saved_game() == ERR_FILE_NOT_FOUND, "no save: load is refused")
	_check(manager.state == manager.State.PLAYING, "no save: no transition starts")
	await sandbox.frames(1)


## A real save from the Coral Valley safe room; later cases mutate copies of it.
func _create_good_save() -> Dictionary:
	_check(sandbox.manager.start_new_game(CORAL_ROOM), "start a new game in Coral Valley")
	await sandbox.wait_transition()
	var rest_point := _only_rest_point()
	_check(rest_point.is_save_allowed(), "room_00 is a safe room")
	_check(rest_point.rest(sandbox.manager.player), "rest at the room_00 campfire")
	await sandbox.wait_rest_menu(rest_point)
	_check(rest_point.request_save() == OK, "save at the room_00 campfire")
	rest_point.close_menu()
	var payload: Dictionary = sandbox.read_slot_payload()
	_check(not payload.is_empty() and GameSaveSnapshot.validate(payload).is_empty(), "valid save")
	return payload


func _check_rejected_files(good: Dictionary) -> void:
	var good_text := sandbox.read_slot_text()
	var cases := {
		"garbage text": "{not json",
		"empty file": "",
		"JSON array": "[1, 2]",
	}
	for label: String in cases:
		await _expect_rejected(label, cases[label], ERR_PARSE_ERROR)
	var payload_cases := {
		"wrong format": _with(good, ["format"], "other_game"),
		"version 0": _with(good, ["version"], 0),
		"missing player": _without(good, ["player"]),
		"missing world": _without(good, ["world"]),
		"missing location": _without(good, ["location"]),
		"HP zero": _with(good, ["player", "hp"], 0),
		"HP text": _with(good, ["player", "hp"], "full"),
		"negative quantity":
		_with(good, ["player", "inventory", "slots"], [{"item": "coral", "quantity": -3}]),
		"fractional quantity":
		_with(good, ["player", "inventory", "slots"], [{"item": "coral", "quantity": 1.5}]),
		"negative gold": _with(good, ["world", "gold"], -1),
		"gold beyond JSON precision": _with(good, ["world", "gold"], 1e300),
		"short facing": _with(good, ["player", "facing"], [1, 2]),
		"too many sockets":
		_with(
			good, ["player", "charms", "unlocked_socket_count"], CharmConstants.MAX_SOCKET_COUNT + 1
		),
		"note not bool": _with(good, ["notes", "unlocked"], {"crab": "yes"}),
		"merchant missing flag": _without(good, ["merchant", "met_silas"]),
	}
	for label: String in payload_cases:
		await _expect_rejected(label, JSON.stringify(payload_cases[label]), ERR_INVALID_DATA)
	await _expect_rejected(
		"newer version", JSON.stringify(_with(good, ["version"], 999)), ERR_FILE_UNRECOGNIZED
	)
	sandbox.write_slot_text(good_text)


func _expect_rejected(label: String, text: String, expected_error: Error) -> void:
	var manager := sandbox.manager
	var before: Dictionary = sandbox.fingerprint()
	var scene := current_scene
	sandbox.write_slot_text(text)
	var result: SaveGameFile.ReadResult = manager.save_slot.read()
	_check(
		result.error == expected_error, "%s: read error %s" % [label, error_string(result.error)]
	)
	_check(not result.message.is_empty(), label + ": explains the problem")
	_check(manager.save_slot.read().error != OK, label + ": not offered as a valid save")
	_check(manager.load_saved_game() == expected_error, label + ": load is refused")
	await sandbox.frames(2)
	_check(current_scene == scene and sandbox.fingerprint() == before, label + ": nothing applied")


func _check_menu_with_damaged_save() -> void:
	var good_text := sandbox.read_slot_text()
	sandbox.write_slot_text("{damaged")
	_check(sandbox.manager.return_to_main_menu(), "damaged save: open the main menu")
	await sandbox.wait_transition()
	var continue_button := current_scene.get_node("%ContinueButton") as Button
	var status := current_scene.get_node("%SaveStatus") as Label
	_check(continue_button.disabled, "damaged save: Continue is disabled")
	_check(status.text.contains("cannot be loaded"), "damaged save: menu says why")
	continue_button.pressed.emit()
	await sandbox.frames(2)
	_check(current_scene is MainMenu, "damaged save: Continue does nothing")
	sandbox.write_slot_text(good_text)
	# Back into the saved room through the real Continue path of a fresh menu.
	_check(sandbox.manager.change_scene(MAIN_MENU.resource_path), "reopen the main menu")
	await sandbox.wait_transition()
	(current_scene.get_node("%ContinueButton") as Button).pressed.emit()
	var load_error: Error = await sandbox.manager.saved_game_loaded
	await sandbox.frames(2)
	_check(load_error == OK and current_scene.scene_file_path == CORAL_ROOM, "Continue loads")


func _check_missing_targets(good: Dictionary) -> void:
	var manager := sandbox.manager
	var good_text := sandbox.read_slot_text()
	var before: Dictionary = sandbox.fingerprint()
	var scene := current_scene
	sandbox.write_slot_payload(_with(good, ["location", "scene"], "res://save_test/missing.tscn"))
	_check(manager.load_saved_game() == ERR_FILE_NOT_FOUND, "missing scene: load is refused")
	await sandbox.frames(2)
	_check(current_scene == scene, "missing scene: current room is kept")

	manager.gold_wallet.add_gold(1)
	before = sandbox.fingerprint()
	sandbox.write_slot_payload(_with(good, ["location", "rest_point"], "Nowhere/RestPoint"))
	if not _check(manager.load_saved_game() == OK, "missing campfire: transition starts"):
		return
	var load_error: Error = await manager.saved_game_loaded
	await sandbox.frames(2)
	_check(load_error == ERR_DOES_NOT_EXIST, "missing campfire: load reports the error")
	_check(current_scene == scene, "missing campfire: current room is kept")
	_check(sandbox.fingerprint() == before, "missing campfire: no progress was applied")
	_check(manager.state == manager.State.PLAYING and not paused, "missing campfire: play resumes")
	sandbox.write_slot_text(good_text)


func _check_write_failure() -> void:
	var manager := sandbox.manager
	var good_text := sandbox.read_slot_text()
	var rest_point := _only_rest_point()
	# A directory where the temporary file must go makes the first write step fail.
	var blocker: String = sandbox.slot_path + SaveGameFile.TEMP_SUFFIX
	DirAccess.make_dir_recursive_absolute(blocker)
	manager.player.hp.take_damage(manager.player.hp.get_max_hp() * DAMAGE_RATIO)
	_check(rest_point.rest(manager.player), "write failure: rest")
	await sandbox.wait_rest_menu(rest_point)
	_check(rest_point.request_save() != OK, "write failure: save reports an error")
	_check(
		rest_point.get_node("RestMenu").get_result().begins_with("Save failed"),
		"write failure: the menu says the save failed"
	)
	_check(sandbox.read_slot_text() == good_text, "write failure: previous save is unchanged")
	rest_point.close_menu()
	DirAccess.remove_absolute(blocker)
	_check(manager.save_game(null) == ERR_INVALID_PARAMETER, "save without a campfire is refused")
	_check(sandbox.read_slot_text() == good_text, "refused saves leave the slot unchanged")


func _check_interrupted_write() -> void:
	var temp_path: String = sandbox.slot_path + SaveGameFile.TEMP_SUFFIX
	var good_text := sandbox.read_slot_text()
	# The old slot was removed but the verified temporary file was never renamed.
	DirAccess.rename_absolute(sandbox.slot_path, temp_path)
	var result: SaveGameFile.ReadResult = sandbox.manager.save_slot.read()
	_check(result.error == OK, "interrupted write: the verified file is recovered")
	_check(sandbox.read_slot_text() == good_text, "interrupted write: slot holds the save")
	_check(not FileAccess.file_exists(temp_path), "interrupted write: temporary file is gone")
	# A damaged temporary file next to a good slot is ignored.
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	file.store_string("{half written")
	file.close()
	_check(sandbox.manager.save_slot.read().error == OK, "stale temporary file is ignored")
	_check(sandbox.read_slot_text() == good_text, "stale temporary file keeps the slot")
	DirAccess.remove_absolute(temp_path)


func _check_unsafe_campfire() -> void:
	var manager := sandbox.manager
	var good_text := sandbox.read_slot_text()
	var room := (load(CORAL_ROOM) as PackedScene).instantiate() as BaseRoom
	room.safe_room = false
	var previous := current_scene
	root.remove_child(previous)
	previous.free()
	root.add_child(room)
	current_scene = room
	await sandbox.frames(3)
	var player: Player = manager.player
	var rest_point := _only_rest_point()
	# A safe location for Charm swaps never grants the save permission by itself.
	player.charm_socket_manager.enter_safe_location(rest_point)
	_check(not rest_point.is_save_allowed(), "unsafe room: save is not allowed")
	player.hp.take_damage(player.hp.get_max_hp() * DAMAGE_RATIO)
	var damaged_hp := player.hp.get_current_hp()
	await sandbox.frames(2)
	player.global_position = rest_point.get_spawn_position()
	await sandbox.frames(4)
	await sandbox.press_action(SANDBOX.ACTION_INTERACT)
	await sandbox.frames(1)
	var menu := rest_point.get_node("RestMenu") as RestMenu
	_check(rest_point.is_menu_open(), "unsafe room: interacting explains the campfire")
	_check(menu.get_message() == rest_point.unsafe_message, "unsafe room: message is shown")
	_check(not menu.is_save_available(), "unsafe room: no Save choice")
	_check(player.hp.get_current_hp() == damaged_hp, "unsafe room: no rest bonus")
	_check(rest_point.request_save() == ERR_UNAVAILABLE, "unsafe room: request_save is refused")
	_check(manager.save_game(rest_point) == ERR_UNAUTHORIZED, "unsafe room: save_game is refused")
	_check(sandbox.read_slot_text() == good_text, "unsafe room: slot unchanged")
	rest_point.close_menu()
	player.charm_socket_manager.exit_safe_location(rest_point)
	_check(manager.state == manager.State.PLAYING and not paused, "unsafe room: play resumes")


func _check_data_groups(good: Dictionary) -> void:
	var manager := sandbox.manager
	var coral := SaveContentCatalog.find_item("coral")
	var slots: Array = []
	slots.append({"item": "coral", "quantity": coral.max_stack + 50})
	slots.append({"item": UNKNOWN_ID, "quantity": 3})
	slots.append(null)
	slots.append({"item": "healing_potion", "quantity": 1})
	var capacity: int = (manager.player.get_node("Inventory") as Inventory).slots.size()
	while slots.size() < capacity + 2:
		slots.append({"item": "coconut", "quantity": 1})
	var payload := _with(good, ["player", "inventory", "slots"], slots)
	payload = _with(
		payload,
		["player", "inventory", "potion_capacities"],
		{"HEALTH": 1, "STAMINA": 0, UNKNOWN_ID: 7}
	)
	payload = _with(
		payload, ["player", "potions"], {"primary": "coral", "secondary": "stamina_potion"}
	)
	await _load_ok(payload, "inventory boundaries")
	var inventory := manager.player.get_node("Inventory") as Inventory
	_check(inventory.get_slot(0).item == coral, "inventory: slot order kept")
	_check(inventory.get_slot(0).quantity == coral.max_stack, "inventory: stack clamped")
	_check(inventory.get_slot(1).is_empty(), "inventory: unknown item dropped")
	_check(inventory.count_item(&"coconut") == capacity + 2 - 4, "inventory: overflow kept")
	_check(inventory.get_potion_capacity(Potion.Kind.HEALTH) == 1, "potion capacity restored")
	_check(inventory.get_potion_capacity(Potion.Kind.STAMINA) == 0, "potion capacity zero")
	_check(manager.player.potion.equipped_potion == null, "non-potion quick slot dropped")
	_check(manager.player.potion.secondary_potion == null, "uncarried potion quick slot dropped")

	var weapons := [
		{"weapon": "dagger", "blueprint_unlocked": true, "owned": true, "forge": UNKNOWN_ID},
		{"weapon": "harpoon", "blueprint_unlocked": false, "owned": true, "forge": ""},
		{"weapon": "bow", "blueprint_unlocked": true, "owned": false, "forge": ""},
		{"weapon": UNKNOWN_ID, "blueprint_unlocked": true, "owned": true, "forge": ""},
	]
	payload = _with(good, ["player", "weapons"], {"entries": weapons, "equipped": "harpoon"})
	await _load_ok(payload, "weapon references")
	var controller: WeaponController = manager.player.weapon_controller
	_check(controller.equipped.definition.weapon_id == &"harpoon", "weapons: equipped restored")
	_check(controller.equipped.forge == null, "weapons: empty forge restored")
	_check(controller.is_weapon_owned(&"dagger"), "weapons: unknown forge keeps the weapon")
	_check(
		controller.is_blueprint_unlocked(&"bow") and not controller.is_weapon_owned(&"bow"),
		"weapons: blueprint without ownership"
	)
	payload = _with(good, ["player", "weapons", "equipped"], UNKNOWN_ID)
	await _load_ok(payload, "unknown equipped weapon")
	_check(manager.player.weapon_controller.equipped != null, "weapons: always one in hand")

	var charms := {
		"version": CharmProgressionSnapshot.VERSION,
		"unlocked_socket_count": CharmConstants.MAX_SOCKET_COUNT,
		"owned_charm_ids": [String(TEST_CHARM), UNKNOWN_ID, String(TEST_CHARM)],
		"equipped_charm_ids": [UNKNOWN_ID, String(TEST_CHARM), String(TEST_CHARM)],
	}
	payload = _with(good, ["player", "charms"], charms)
	await _load_ok(payload, "charm references")
	var registry: CharmRegistry = manager.player.charm_registry
	var sockets: CharmSocketManager = manager.player.charm_socket_manager
	_check(registry.get_owned_ids() == [TEST_CHARM], "charms: unknown and duplicate IDs dropped")
	_check(sockets.get_unlocked_socket_count() == CharmConstants.MAX_SOCKET_COUNT, "max sockets")
	_check(sockets.get_equipped_charm(0).is_empty(), "charms: unknown equipped Charm dropped")
	_check(sockets.get_equipped_charm(1) == TEST_CHARM, "charms: equipped Charm restored")
	_check(sockets.get_equipped_charm(2).is_empty(), "charms: duplicate socket dropped")
	var charmed_max_hp: float = manager.player.hp.get_max_hp()
	await _load_ok(payload, "charm references again")
	_check(manager.player.hp.get_max_hp() == charmed_max_hp, "charms: max HP does not stack")

	payload = _with(good, ["player", "hp"], 1e6)
	payload = _with(payload, ["player", "sp"], 0)
	await _load_ok(payload, "vital boundaries")
	_check(
		manager.player.hp.get_current_hp() == manager.player.hp.get_max_hp(),
		"vitals: HP clamped to max"
	)
	# Stamina regenerates during the frames after arrival, so only a near-empty bar is expected.
	_check(
		(
			manager.player.stamina.get_current_sp()
			< manager.player.stamina.get_max_sp() * LOW_STAMINA_RATIO
		),
		"vitals: SP zero restored"
	)

	for gold: int in [0, GameSaveSnapshot.MAX_JSON_INTEGER]:
		await _load_ok(_with(good, ["world", "gold"], gold), "gold %d" % gold)
		_check(manager.gold_wallet.get_balance() == gold, "gold boundary %d restored" % gold)

	var world := _with(
		good, ["world", "visited_rooms"], ["res://save_test/gone.tscn", CAMPFIRE_ROOMS[0]]
	)
	world = _with(world, ["world", "story_flags"], ["save_test_flag"])
	world = _with(
		world,
		["world", "boss_encounters"],
		{
			"save_test_boss":
			{
				"opened": false,
				"position": [1, 2, 3],
				"items":
				[
					{"index": 0, "item": UNKNOWN_ID, "quantity": 1, "position": [0, 0, 0]},
					{"index": 1, "item": "coral", "quantity": 2, "position": [4, 0, 4]}
				]
			}
		}
	)
	world = _with(world, ["notes", "unlocked"], {"crab": true, "barrel": false})
	world = _with(world, ["merchant"], {"met_silas": true, "bow_purchased": true})
	await _load_ok(world, "world references")
	var visited: PackedStringArray = manager.map_progress.get_visited_rooms()
	_check(not visited.has("res://save_test/gone.tscn"), "map: missing room dropped")
	_check(visited.has(CAMPFIRE_ROOMS[0]), "map: explored room restored")
	_check(manager.has_story_flag(&"save_test_flag"), "story flag restored")
	var boss: Dictionary = manager.boss_encounters.get(&"save_test_boss", {})
	_check(bool(boss.get("defeated", false)), "boss: defeat restored")
	_check(boss.get("position") == Vector3(1, 2, 3), "boss: chest position restored")
	_check(boss.get("items", {}).keys() == [1], "boss: unknown reward dropped")
	_check(sandbox.notes.get_save_data().unlocked == {"crab": true, "barrel": false}, "notes")
	_check(sandbox.merchant.has_met_silas() and sandbox.merchant.has_bow_purchase(), "merchant")

	sandbox.write_slot_payload(good)


## Saves and loads at every campfire, then lets physics run to prove the spawn is usable.
func _check_campfire_spawns() -> void:
	var manager := sandbox.manager
	for room_path: String in CAMPFIRE_ROOMS:
		var label := room_path.get_file()
		_check(manager.change_scene(room_path), label + ": enter")
		await sandbox.wait_transition()
		var rest_points: Array[CampfireRestPoint] = sandbox.find_rest_points(current_scene)
		_check(not rest_points.is_empty(), label + ": has a campfire rest point")
		for index: int in rest_points.size():
			await _check_spawn(room_path, index, "%s campfire %d" % [label, index])


func _check_spawn(room_path: String, index: int, label: String) -> void:
	var manager := sandbox.manager
	var rest_point: CampfireRestPoint = sandbox.find_rest_points(current_scene)[index]
	_check(rest_point.is_save_allowed(), label + ": room is safe")
	_check(rest_point.rest(manager.player), label + ": rests")
	await sandbox.wait_rest_menu(rest_point)
	_check(rest_point.request_save() == OK, label + ": saves")
	rest_point.close_menu()
	if not _check(manager.load_saved_game() == OK, label + ": load starts"):
		return
	var load_error: Error = await manager.saved_game_loaded
	_check(load_error == OK, label + ": load succeeds")
	await sandbox.frames(SETTLE_FRAMES)
	rest_point = sandbox.find_rest_points(current_scene)[index]
	var player: Player = manager.player
	var spawn := rest_point.get_spawn_position()
	_check(current_scene.scene_file_path == room_path, label + ": no scene transition fired")
	_check(manager.state == manager.State.PLAYING and not player.dead, label + ": playable")
	_check(player.global_position.y > spawn.y - FALL_TOLERANCE, label + ": did not fall")
	_check(player.is_on_floor(), label + ": standing on the floor")
	_check(
		(
			Vector2(player.global_position.x, player.global_position.z).distance_to(
				Vector2(spawn.x, spawn.z)
			)
			< SPAWN_TOLERANCE
		),
		label + ": stays beside the campfire"
	)
	var campfire := rest_point.get_parent() as Node3D
	var offset := player.global_position - campfire.global_position
	_check(
		Vector2(offset.x, offset.z).length() > CAMPFIRE_BODY_RADIUS,
		label + ": outside the campfire collision"
	)
	for node: Node in get_nodes_in_group("scene_change_triggers"):
		var trigger := node as SceneChangeTrigger
		if trigger != null and current_scene.is_ancestor_of(trigger):
			_check(not trigger.overlaps_body(player), label + ": clear of " + trigger.name)


func _load_ok(payload: Dictionary, label: String) -> void:
	sandbox.write_slot_payload(payload)
	var problem := GameSaveSnapshot.validate(JSON.parse_string(JSON.stringify(payload)))
	_check(problem.is_empty(), label + ": payload is valid " + problem)
	if not _check(sandbox.manager.load_saved_game() == OK, label + ": load starts"):
		return
	var load_error: Error = await sandbox.manager.saved_game_loaded
	await sandbox.frames(2)
	_check(load_error == OK, label + ": load succeeds")


func _only_rest_point() -> CampfireRestPoint:
	var rest_points: Array[CampfireRestPoint] = sandbox.find_rest_points(current_scene)
	_check(rest_points.size() == 1, "room has one campfire rest point")
	return rest_points[0] if not rest_points.is_empty() else null


## Deep copy of `source` with the value at `key_path` replaced.
func _with(source: Dictionary, key_path: Array, value: Variant) -> Dictionary:
	var copy := source.duplicate(true)
	var target: Dictionary = copy
	for key_index: int in key_path.size() - 1:
		target = target[key_path[key_index]]
	target[key_path[-1]] = value
	return copy


func _without(source: Dictionary, key_path: Array) -> Dictionary:
	var copy := source.duplicate(true)
	var target: Dictionary = copy
	for key_index: int in key_path.size() - 1:
		target = target[key_path[key_index]]
	target.erase(key_path[-1])
	return copy


## Returns the condition so a failed precondition can skip an await that would hang.
func _check(condition: bool, label: String) -> bool:
	if condition:
		print("PASS ", label)
		return true
	failures += 1
	push_warning("FAIL " + label)
	print("FAIL ", label)
	return false
