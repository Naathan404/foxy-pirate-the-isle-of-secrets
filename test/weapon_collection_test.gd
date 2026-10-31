extends SceneTree

const DAGGER: WeaponData = preload("res://data/weapon/weapon_dagger.tres")
const BOW: WeaponData = preload("res://data/weapon/weapon_bow.tres")

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var dagger := _entry(DAGGER, false, false)
	var bow := _entry(BOW, true, true)
	var initial: Array[WeaponCollectionEntry] = [dagger, bow]
	var controller := _controller(world, initial)
	_check(controller.equipped.definition == BOW, "Owned preferred weapon equips")
	_check(controller.get_owned_weapons().size() == 1, "Locked unowned dagger is absent")
	_check(controller.is_blueprint_unlocked(&"bow"), "Starting blueprint flag is loaded")
	controller.set_blueprint_unlocked(&"dagger", true)
	_check(controller.is_blueprint_unlocked(&"dagger"), "Blueprint can unlock independently")
	_check(not controller.is_weapon_owned(&"dagger"), "Blueprint never grants an item")
	controller.set_blueprint_unlocked(&"dagger", false)
	controller.set_weapon_owned(&"dagger", true)
	_check(controller.is_weapon_owned(&"dagger"), "Loot can be owned without its blueprint")
	_check(not controller.is_blueprint_unlocked(&"dagger"), "Ownership never unlocks crafting")
	controller.set_weapon_owned(&"dagger", true)
	_check(controller.get_owned_weapons().size() == 2, "Repeated flag does not duplicate a weapon")
	var instance: WeaponInstance
	for weapon: WeaponInstance in controller.get_owned_weapons():
		if weapon.definition == DAGGER:
			instance = weapon
	instance.cooldowns[&"normal"] = 0.3
	controller.set_blueprint_unlocked(&"dagger", true)
	_check(
		is_equal_approx(instance.cooldowns[&"normal"], 0.3),
		"Blueprint edits preserve the owned instance"
	)
	_check(controller.equip(instance), "Granted item equips through existing validation")
	controller.set_weapon_owned(&"dagger", false)
	_check(controller.equipped == null, "Removing equipped ownership safely clears equipment")
	_check(not controller.try_attack(AttackContext.new()), "Unarmed actor cannot attack")
	_check(controller.is_blueprint_unlocked(&"dagger"), "Removing an item retains its blueprint")
	_check(not controller.is_weapon_owned(&"dagger"), "Removed item leaves the collection")
	_check(
		not dagger.owned and not dagger.blueprint_unlocked,
		"Shared starting resources are unchanged"
	)
	_check(initial[0] == dagger and initial.size() == 2, "Caller collection array is unchanged")
	var second := _controller(world, initial)
	_check(not second.is_weapon_owned(&"dagger"), "Players do not share ownership flags")
	_check(not second.is_blueprint_unlocked(&"dagger"), "Players do not share blueprint flags")
	var empty := _controller(world, [_entry(DAGGER, true, false), _entry(BOW, false, false)])
	_check(
		empty.equipped == null and empty.get_owned_weapons().is_empty(),
		"Default weapon cannot override explicit unowned flags"
	)
	empty.collection[0].owned = true
	_check(empty.is_weapon_owned(&"dagger"), "Inspector-style checkbox edits grant inventory item")
	_check(empty.equipped == null, "Granting ownership does not force an equipment switch")
	_check(not empty.set_weapon_owned(&"missing", true), "Unknown weapon IDs are rejected")
	await _test_inventory(world)
	world.free()
	if _failures == 0:
		print(
			"Weapon collection: independent blueprint/ownership flags, grant/revoke, startup, isolation and live inventory passed"
		)
	quit(0 if _failures == 0 else 1)


func _test_inventory(world: Node3D) -> void:
	var player := load("res://gameplay/player/foxy.tscn").instantiate() as Player
	world.add_child(player)
	player.set_physics_process(false)
	await process_frame
	var controller := player.weapon_controller
	var ui := player.inventory_ui
	ui.open_inventory()
	ui._select_tab(1)
	var equipment = ui.equipment_tab
	var count: int = equipment._entries.size()
	controller.set_blueprint_unlocked(&"dagger", true)
	_check(equipment._entries.size() == count, "Blueprint-only item stays out of Equipment")
	controller.collection[0].owned = true
	_check(equipment._entries.size() == count + 1, "Ownership checkbox refreshes open inventory")
	controller.collection[0].owned = false
	_check(equipment._entries.size() == count, "Revoking ownership refreshes open inventory")
	controller.set_weapon_owned(&"bow", false)
	_check(equipment._entries.is_empty(), "Inventory handles no owned weapons")
	_check(equipment.get_node("%EquipButton").disabled, "Empty inventory cannot equip")
	ui.close_inventory(true)
	player.free()


func _controller(world: Node3D, initial: Array[WeaponCollectionEntry]) -> WeaponController:
	var actor := Node3D.new()
	world.add_child(actor)
	var controller := WeaponController.new()
	controller.default_weapon = BOW
	controller.collection = initial
	actor.add_child(controller)
	_check(controller.setup(actor), "Collection fixture sets up")
	return controller


func _entry(data: WeaponData, blueprint: bool, owned: bool) -> WeaponCollectionEntry:
	var entry := WeaponCollectionEntry.new()
	entry.definition = data
	entry.blueprint_unlocked = blueprint
	entry.owned = owned
	return entry


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
