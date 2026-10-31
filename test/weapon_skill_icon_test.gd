extends SceneTree

const DAGGER: WeaponData = preload("res://data/weapon/weapon_dagger.tres")
const BOW: WeaponData = preload("res://data/weapon/weapon_bow.tres")

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var player := load("res://gameplay/player/foxy.tscn").instantiate() as Player
	world.add_child(player)
	player.set_physics_process(false)
	await process_frame
	var controller := player.weapon_controller
	var hud = player.get_node("PlayerHUD")
	_check(hud.weapon_controller == controller, "Foxy HUD is wired to its actual controller")
	_check(
		player.get_node("Effects/CombatScreenFlash").weapons == controller,
		"Combat flash uses the same controller"
	)
	controller.set_weapon_owned(&"dagger", true)
	controller.set_weapon_owned(&"bow", true)
	player.inventory_ui.open_inventory()
	player.inventory_ui._select_tab(1)
	var equipment = player.inventory_ui.equipment_tab
	for definition: WeaponData in [DAGGER, BOW, DAGGER, BOW]:
		for weapon: WeaponInstance in controller.get_owned_weapons():
			if weapon.definition.weapon_id == definition.weapon_id:
				equipment._selection = weapon
				equipment._equip_selected()
				_check(
					controller.equipped == weapon,
					"Inventory equips selected " + definition.display_name
				)
				break
		var skill := definition.secondary_attack
		_check(
			hud.weapon_icon.texture == skill.skill_icon,
			"HUD skill icon follows " + definition.display_name
		)
		_check(hud.weapon_icon.visible, "Equipped skill icon is visible")
		_check(
			equipment.get_node("%SkillIcon").texture == skill.skill_icon,
			"Inventory skill icon matches HUD"
		)
		_check(
			hud.ammo_label.visible == (definition.weapon_id == &"bow"),
			"Ammo display follows equipped weapon"
		)
	controller.set_weapon_owned(&"bow", false)
	_check(
		hud.weapon_icon.texture == null and not hud.weapon_icon.visible,
		"Removing equipped weapon clears the skill icon"
	)
	_check(not hud.ammo_label.visible, "Unarmed HUD hides ammo")
	player.inventory_ui.close_inventory(true)
	world.free()
	if _failures == 0:
		print("Weapon skill HUD wiring, inventory swaps, ammo and unequip icon clearing passed")
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
