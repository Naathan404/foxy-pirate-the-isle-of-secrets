extends SceneTree

const ROOM := "res://test/fixtures/scene_transition_arrival.tscn"
const FORGE := preload("res://data/weapon/forges/keen_edge.tres")
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()
	create_timer(25.0, true, false, true).timeout.connect(
		func() -> void:
			push_error("Death progression test timed out")
			quit(1)
	)


func _run() -> void:
	var manager := root.get_node("GameManager")
	manager.fade_out_seconds = 0.03
	manager.fade_in_seconds = 0.03
	change_scene_to_file(ROOM)
	await scene_changed
	var player := manager.player as Player
	var inventory := player.get_node("Inventory") as Inventory
	var item_id := StringName(inventory.slots[0].item.item_id)
	inventory.remove_item(item_id, 1)
	var item_count := inventory.count_item(item_id)
	var potion := load("res://data/items/consumables/small_healing_potion.tres") as Potion
	_check(player.potion.equip_potion(potion), "equip test potion")
	_check(player.weapon_controller.grant_weapon(&"bow"), "grant bow")
	_check(player.weapon_controller.set_blueprint_unlocked(&"bow", true), "unlock blueprint")
	_check(player.weapon_controller.set_weapon_forge(&"bow", FORGE), "forge bow")
	var bow: WeaponInstance
	for weapon: WeaponInstance in player.weapon_controller.get_owned_weapons():
		if weapon.definition.weapon_id == &"bow":
			bow = weapon
	_check(player.weapon_controller.equip(bow), "equip bow")
	player.charm_registry.set_owned(&"arrow_rain", true)
	var equipped: Dictionary[int, StringName] = {0: &"arrow_rain"}
	player.charm_socket_manager.restore_progression(2, equipped)
	player.stamina.try_consume(13.0)
	player.hp.take_damage(player.hp.get_max_hp())
	_check(player.dead, "lethal damage enters death")
	await manager.scene_transition_finished
	player = manager.player as Player
	inventory = player.get_node("Inventory") as Inventory
	_check(not player.dead and player.hp.is_alive(), "respawned player is alive")
	_check(is_equal_approx(player.hp.current_hp, player.hp.get_max_hp()), "health restored")
	_check(
		is_equal_approx(player.stamina.current_sp, player.stamina.get_max_sp()), "stamina restored"
	)
	_check(inventory.count_item(item_id) == item_count, "inventory preserved")
	_check(player.potion.equipped_potion == potion, "equipped potion preserved")
	_check(player.weapon_controller.is_weapon_owned(&"bow"), "weapon preserved")
	_check(player.weapon_controller.is_blueprint_unlocked(&"bow"), "blueprint preserved")
	_check(
		player.weapon_controller.equipped.definition.weapon_id == &"bow",
		"equipped weapon preserved"
	)
	_check(
		(
			player.weapon_controller.equipped.forge != null
			and player.weapon_controller.equipped.forge.forge_id == FORGE.forge_id
		),
		"forge preserved"
	)
	_check(player.charm_registry.is_owned(&"arrow_rain"), "charm preserved")
	_check(
		player.charm_socket_manager.get_equipped_charm(0) == &"arrow_rain",
		"charm loadout preserved"
	)
	for failure: String in failures:
		push_error(failure)
	if failures.is_empty():
		print("Death progression checks: PASS")
	quit(0 if failures.is_empty() else 1)


func _check(value: bool, label: String) -> void:
	if not value:
		failures.append(label)
