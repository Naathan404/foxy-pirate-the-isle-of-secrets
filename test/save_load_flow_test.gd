extends SceneTree
## End-to-end Save/Load through the real main menu, hub room, campfire input and Foxy.
## Writes only under user://test_saves/ and fails if the player's real saves change.

const SANDBOX := preload("res://test/fixtures/save_test_sandbox.gd")
const MAIN_MENU := preload("res://ui/main_menu/main_menu.tscn")
const HUB_SCENE := "res://world/biomes/hub/map/castaway_cove.tscn"
const CORAL_ITEM := "coral"
const CRAB_CLAW_ITEM := "crab_claw"
const TEST_CHARM := &"turtle_shell"
const TEST_WEAPON := &"harpoon"
const TEST_BLUEPRINT := &"bow"
const TEST_FORGE := &"keen_edge"
const TEST_FLAG := &"save_test_flag"
const TEST_NOTE := &"crab"
const TEST_BOSS := &"save_test_boss"
## Fractions of the maximum, so the test never kills Foxy whatever his tuning.
const DAMAGE_RATIO := 0.4
const SPENT_SP_RATIO := 0.3
const EARNED_GOLD := 250
const SPAWN_TOLERANCE := 0.75
const REPEAT_CYCLES := 3

var sandbox := SANDBOX.new()
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	sandbox.setup(self, "flow")
	var menu := await _open_main_menu()
	_check(_continue_button(menu).disabled, "no save: Continue is disabled")
	await _dirty_previous_run()
	_new_game_button(menu).pressed.emit()
	await sandbox.wait_transition()
	_check(current_scene.scene_file_path == HUB_SCENE, "New Game enters the hub")
	_check_fresh_run("New Game ignores the previous run")

	await sandbox.frames(30)
	_check(not FileAccess.file_exists(sandbox.slot_path), "entering a safe room never saves")
	var rest_point := _hub_rest_point()
	_make_progress()
	await _interact(rest_point)
	var player: Player = sandbox.manager.player
	_check(rest_point.is_menu_open() and paused, "interact opens the rest menu and pauses")
	_check(sandbox.manager.state == sandbox.manager.State.REST_MENU, "rest menu owns the pause")
	_check(
		(
			player.hp.get_current_hp() == player.hp.get_max_hp()
			and player.stamina.get_current_sp() == player.stamina.get_max_sp()
		),
		"resting restores HP and SP"
	)
	_leave_button(rest_point).pressed.emit()
	await sandbox.frames(2)
	_check(not rest_point.is_menu_open() and not paused, "Leave closes the menu and resumes")
	_check(not FileAccess.file_exists(sandbox.slot_path), "leaving without saving writes nothing")

	await _interact(rest_point)
	await sandbox.press_action(&"ui_cancel")
	var pause_menu := sandbox.manager.player.get_node("PauseMenu") as PauseMenu
	_check(
		not rest_point.is_menu_open() and not pause_menu.is_open() and not paused,
		"Escape closes the rest menu without opening the pause menu"
	)

	player.hp.take_damage(player.hp.get_max_hp() * DAMAGE_RATIO)
	await _interact(rest_point)
	_save_button(rest_point).pressed.emit()
	await sandbox.frames(1)
	var expected: Dictionary = sandbox.fingerprint()
	_check(FileAccess.file_exists(sandbox.slot_path), "Save writes the slot")
	_check(rest_point.get_node("RestMenu").get_result() == "Game saved.", "Save reports success")
	var saved: Dictionary = sandbox.read_slot_payload()
	_check(
		is_equal_approx(float(saved.player.hp), player.hp.get_max_hp()),
		"the save holds the HP after resting"
	)
	_check(saved.location.scene == HUB_SCENE, "the save names the hub room")
	_leave_button(rest_point).pressed.emit()
	await sandbox.frames(2)

	for cycle: int in REPEAT_CYCLES:
		await _change_progress_after_save()
		await _continue_from_menu(expected, "load %d" % (cycle + 1))
		var loaded_rest_point := _hub_rest_point()
		await _interact(loaded_rest_point)
		_save_button(loaded_rest_point).pressed.emit()
		await sandbox.frames(1)
		_check(
			sandbox.fingerprint() == expected,
			(
				"resave %d keeps the same progress: %s"
				% [cycle + 1, SANDBOX.describe_difference(expected, sandbox.fingerprint())]
			)
		)
		_leave_button(loaded_rest_point).pressed.emit()
		await sandbox.frames(2)

	var slot_before := sandbox.read_slot_text()
	_check(sandbox.manager.return_to_main_menu(), "return to the main menu")
	await sandbox.wait_transition()
	_new_game_button(current_scene).pressed.emit()
	await sandbox.wait_transition()
	_check_fresh_run("New Game after a save starts fresh")
	_check(sandbox.read_slot_text() == slot_before, "New Game keeps the save slot unchanged")

	_check(sandbox.teardown(), "real user saves are untouched")
	print("Save/load flow failures: ", failures)
	quit(1 if failures > 0 else 0)


func _open_main_menu() -> Control:
	var menu := MAIN_MENU.instantiate() as Control
	root.add_child(menu)
	current_scene = menu
	await sandbox.frames(3)
	return menu


## Progress left in memory and in the merchant/note files by an earlier run.
func _dirty_previous_run() -> void:
	sandbox.manager.gold_wallet.add_gold(EARNED_GOLD)
	sandbox.manager.set_story_flag(&"stale_flag")
	sandbox.notes.set_unlocked(TEST_NOTE, true)
	sandbox.merchant.mark_met_silas()
	await sandbox.frames(1)


func _check_fresh_run(label: String) -> void:
	var fresh := GoldWallet.new().get_balance()
	_check(sandbox.manager.gold_wallet.get_balance() == fresh, label + ": default gold")
	_check(sandbox.manager.story_flags.is_empty(), label + ": no story flags")
	_check(sandbox.manager.boss_encounters.is_empty(), label + ": no boss state")
	_check(sandbox.notes.get_save_data().unlocked.is_empty(), label + ": no notes")
	_check(not sandbox.merchant.has_met_silas(), label + ": merchant not met")
	var registry: CharmRegistry = sandbox.manager.player.charm_registry
	_check(not registry.is_owned(TEST_CHARM), label + ": no saved Charm")
	var weapons: WeaponController = sandbox.manager.player.weapon_controller
	_check(not weapons.is_weapon_owned(TEST_WEAPON), label + ": no saved weapon")


func _make_progress() -> void:
	var manager := sandbox.manager
	var player: Player = manager.player
	var inventory := player.get_node("Inventory") as Inventory
	inventory.add_item(SaveContentCatalog.find_item(CORAL_ITEM), 5)
	inventory.remove_item(StringName(CRAB_CLAW_ITEM), 1)
	inventory.upgrade_potion_capacity(Potion.Kind.HEALTH, 2)
	manager.gold_wallet.add_gold(EARNED_GOLD)
	manager.set_story_flag(TEST_FLAG)
	manager.boss_encounters[TEST_BOSS] = {
		"defeated": true,
		"opened": true,
		"position": Vector3(1, 0, 2),
		"items":
		{
			0:
			{
				"item": SaveContentCatalog.find_item(CORAL_ITEM),
				"quantity": 2,
				"position": Vector3(3, 0, 1)
			}
		},
	}
	sandbox.notes.set_unlocked(TEST_NOTE, true)
	sandbox.merchant.mark_met_silas()
	var weapons := player.weapon_controller
	weapons.set_blueprint_unlocked(TEST_BLUEPRINT, true)
	weapons.grant_weapon(TEST_WEAPON)
	weapons.set_weapon_forge(&"dagger", SaveContentCatalog.find_forge(TEST_FORGE))
	player.charm_registry.set_owned(TEST_CHARM, true)
	_check(
		player.charm_socket_manager.equip_charm(TEST_CHARM, CharmConstants.SocketId.Q),
		"equip a Charm in the safe hub"
	)
	player.hp.take_damage(player.hp.get_max_hp() * DAMAGE_RATIO)
	player.stamina.try_consume(player.stamina.get_max_sp() * SPENT_SP_RATIO)


func _change_progress_after_save() -> void:
	var manager := sandbox.manager
	var player: Player = manager.player
	var inventory := player.get_node("Inventory") as Inventory
	inventory.add_item(SaveContentCatalog.find_item(CORAL_ITEM), 7)
	inventory.remove_item(StringName(CRAB_CLAW_ITEM), 1)
	manager.gold_wallet.try_spend(EARNED_GOLD)
	manager.set_story_flag(&"after_save_flag")
	manager.boss_encounters.erase(TEST_BOSS)
	sandbox.notes.set_unlocked(&"barrel", true)
	sandbox.merchant.mark_bow_purchased()
	player.charm_socket_manager.unequip_charm(CharmConstants.SocketId.Q)
	player.charm_registry.set_owned(TEST_CHARM, false)
	player.weapon_controller.set_weapon_owned(TEST_WEAPON, false)
	player.hp.take_damage(player.hp.get_max_hp() * DAMAGE_RATIO)
	player.global_position += Vector3(4, 0, 4)
	await sandbox.frames(2)


func _continue_from_menu(expected: Dictionary, label: String) -> void:
	_check(sandbox.manager.return_to_main_menu(), label + ": back to the main menu")
	await sandbox.wait_transition()
	var menu := current_scene
	_check(not _continue_button(menu).disabled, label + ": Continue is enabled")
	_check(
		String(menu.get_node("%SaveStatus").text).begins_with("Slot 1"),
		label + ": menu names the save slot"
	)
	_continue_button(menu).pressed.emit()
	var load_error: Error = await sandbox.manager.saved_game_loaded
	await sandbox.frames(10)
	_check(load_error == OK, label + ": load succeeds")
	_check(current_scene.scene_file_path == HUB_SCENE, label + ": back in the saved room")
	var actual: Dictionary = sandbox.fingerprint()
	_check(
		actual == expected,
		label + ": progress restored: " + SANDBOX.describe_difference(expected, actual)
	)
	var rest_point := _hub_rest_point()
	var player: Player = sandbox.manager.player
	_check(
		player.global_position.distance_to(rest_point.get_spawn_position()) < SPAWN_TOLERANCE,
		label + ": spawned beside the saved campfire"
	)
	_check(not paused and sandbox.manager.state == sandbox.manager.State.PLAYING, label + ": play")


func _interact(rest_point: CampfireRestPoint) -> void:
	var player: Player = sandbox.manager.player
	player.global_position = rest_point.get_spawn_position()
	player.velocity = Vector3.ZERO
	await sandbox.frames(4)
	await sandbox.press_action(SANDBOX.ACTION_INTERACT)
	await sandbox.frames(1)


func _hub_rest_point() -> CampfireRestPoint:
	var rest_points: Array[CampfireRestPoint] = sandbox.find_rest_points(current_scene)
	_check(rest_points.size() == 1, "the hub has one campfire rest point")
	return rest_points[0] if not rest_points.is_empty() else null


func _continue_button(menu: Node) -> Button:
	return menu.get_node("%ContinueButton") as Button


func _new_game_button(menu: Node) -> Button:
	return menu.get_node("%NewGameButton") as Button


func _save_button(rest_point: CampfireRestPoint) -> Button:
	return rest_point.get_node("RestMenu").get_node("%SaveButton") as Button


func _leave_button(rest_point: CampfireRestPoint) -> Button:
	return rest_point.get_node("RestMenu").get_node("%LeaveButton") as Button


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
		return
	failures += 1
	push_warning("FAIL " + label)
	print("FAIL ", label)
