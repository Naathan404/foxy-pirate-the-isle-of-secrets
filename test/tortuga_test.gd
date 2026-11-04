extends SceneTree


func _initialize() -> void:
	call_deferred("_verify")


func _verify() -> void:
	var catalog := load("res://data/forge/tortuga_catalog.tres") as TortugaCatalog
	assert(catalog != null and catalog.is_valid(), "catalog invalid")
	var scene := load("res://gameplay/npcs/master_tortuga/master_tortuga_npc.tscn") as PackedScene
	assert(scene != null, "scene failed to load")
	var npc := scene.instantiate() as MasterTortugaNpc
	assert(npc != null, "NPC script failed to load")
	root.add_child(npc)
	await process_frame
	assert(npc.forge_panel != null, "panel missing")
	print("TORTUGA_SCENE_OK recipes=", catalog.recipes.size())
	var bag := Inventory.new()
	root.add_child(bag)
	var wallet := GoldWallet.new()
	var opening_balance := wallet.get_balance()
	wallet.add_gold(500)
	var controller := WeaponController.new()
	root.add_child(controller)
	for recipe in catalog.recipes:
		var entry := WeaponCollectionEntry.new()
		entry.definition = recipe.weapon
		entry.blueprint_unlocked = true
		controller.collection.append(entry)
	controller._initialize_collection()
	var bow := catalog.get_recipe(&"bow")
	for ingredient in bow.ingredients:
		assert(bag.add_item(ingredient.item, ingredient.amount) == 0)
	var service := TortugaService.new(catalog, bag, wallet, controller)
	assert(service.craft(&"bow") == "")
	assert(controller.is_weapon_owned(&"bow"))
	assert(controller.is_blueprint_unlocked(&"bow"))
	assert(wallet.get_balance() == opening_balance + 400)
	assert(service.craft(&"bow") == "Weapon already owned.")
	assert(wallet.get_balance() == opening_balance + 400)
	for ingredient in bow.ingredients:
		assert(bag.count_item(StringName(ingredient.item.item_id)) == 0)
	for ingredient in catalog.forge_ingredients:
		assert(bag.add_item(ingredient.item, ingredient.amount) == 0)
	var options := service.roll_forges(&"bow")
	assert(options.size() == 2 and options[0] != options[1])
	assert(wallet.get_balance() == opening_balance + 325)
	assert(service.apply_forge(&"bow", options[1]))
	assert(controller.get_owned_weapons()[0].forge == options[1])
	assert(service.roll_forges(&"bow").is_empty())
	assert(wallet.get_balance() == opening_balance + 325)
	var harpoon := catalog.get_recipe(&"harpoon")
	for ingredient in harpoon.ingredients:
		assert(bag.add_item(ingredient.item, ingredient.amount) == 0)
	assert(service.craft(&"harpoon") == "")
	assert(controller.is_weapon_owned(&"harpoon"))
	assert(wallet.get_balance() == opening_balance + 75)
	print("TORTUGA_CRAFT_FORGE_OK")
	npc.queue_free()
	bag.queue_free()
	controller.queue_free()
	await process_frame
	var world := (load("res://world/tests/test_scene.tscn") as PackedScene).instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	var map_npc := world.get_node("MasterTortuga") as MasterTortugaNpc
	var player := world.get_node("Foxy") as Player
	assert(map_npc != null and map_npc.forge_panel != null)
	assert(map_npc.forge_panel.open_for(player), "forge panel failed to open")
	assert(map_npc.forge_panel.visible)
	var map_weapons := player.weapon_controller
	assert(map_weapons.set_blueprint_unlocked(&"bow", true))
	assert(_slot_is_dark(map_npc.forge_panel, "Dagger"))
	if not map_weapons.is_weapon_owned(&"bow"):
		assert(not _slot_is_dark(map_npc.forge_panel, "Bow"))
	if not map_weapons.is_weapon_owned(&"bow"):
		assert(map_weapons.grant_weapon(&"bow"))
	assert(_slot_is_dark(map_npc.forge_panel, "Bow"))
	map_npc.forge_panel._select_weapon(&"bow")
	assert(map_npc.forge_panel.grid.get_child_count() > 0, "crafted blueprint disappeared")
	assert(map_npc.forge_panel.status.text.contains("Crafted"))
	var weapon_details := map_npc.forge_panel.details
	assert(weapon_details.get_node("StatsGrid").get_child_count() == 8)
	assert(not weapon_details.get_node("SkillName").text.is_empty())
	assert(map_npc.forge_panel.cost_grid.get_child_count() == 3)
	assert(map_npc.forge_panel.action.disabled)
	map_npc.forge_panel._set_tab(TortugaPanel.Tab.FORGE)
	assert(not _slot_is_dark(map_npc.forge_panel, "Dagger"))
	var map_bag := player.get_node("Inventory") as Inventory
	for ingredient in catalog.forge_ingredients:
		assert(map_bag.add_item(ingredient.item, ingredient.amount) == 0)
	map_npc.forge_panel._select_weapon(&"bow")
	assert(map_npc.forge_panel.cost_grid.get_child_count() == 3)
	assert(map_weapons.set_weapon_forge(&"bow", null))
	var favorable := WeaponForge.new()
	favorable.damage_multiplier = 1.2
	favorable.windup_multiplier = 0.8
	var unfavorable := WeaponForge.new()
	unfavorable.damage_multiplier = 0.8
	unfavorable.windup_multiplier = 1.2
	var bow_instance := map_npc.forge_panel._selected_weapon()
	var good_rows: Array = map_npc.forge_panel.forge_popup.call(
		"_comparison_rows", bow_instance, favorable
	)
	var bad_rows: Array = map_npc.forge_panel.forge_popup.call(
		"_comparison_rows", bow_instance, unfavorable
	)
	assert(_trend_for(good_rows, "Base hit damage") == 1)
	assert(_trend_for(good_rows, "Windup") == 1)
	assert(_trend_for(bad_rows, "Base hit damage") == -1)
	assert(_trend_for(bad_rows, "Windup") == -1)
	map_npc.forge_panel._on_action()
	assert(map_npc.forge_panel.forge_popup.visible, "forge choice popup did not open")
	assert(not map_npc.forge_panel.book.visible, "panel remained visible behind forge popup")
	assert(
		(
			(
				map_npc
				. forge_panel
				. forge_popup
				. get_node("Window/CardA/StatsScroll/Rows")
				. get_child_count()
			)
			> 0
		)
	)
	assert(
		(
			(
				map_npc
				. forge_panel
				. forge_popup
				. get_node("Window/CardB/StatsScroll/Rows")
				. get_child_count()
			)
			> 0
		)
	)
	map_npc.forge_panel.close_panel()
	assert(map_npc.forge_panel.visible, "left before choosing a forge")
	map_npc.forge_panel._set_tab(TortugaPanel.Tab.CRAFT)
	assert(map_npc.forge_panel._tab == TortugaPanel.Tab.FORGE)
	map_npc.forge_panel._choose_option(0)
	assert(not map_npc.forge_panel.forge_popup.visible)
	assert(map_npc.forge_panel.book.visible)
	assert(map_npc.forge_panel._selected_weapon().forge != null)
	assert(weapon_details.get_node("ForgeHeading").text.contains("FORGE /"))
	print("TORTUGA_PANEL_OPEN_OK")
	map_npc.forge_panel.close_panel()
	map_npc._on_interaction_requested(player)
	await create_timer(2.0).timeout
	var dialogic := root.get_node("Dialogic")
	assert(dialogic.current_timeline != null)
	await dialogic.end_timeline(true)
	await process_frame
	assert(map_npc.forge_panel.visible, "dialogue did not open forge panel")
	print("TORTUGA_DIALOGUE_TO_PANEL_OK")
	map_npc.forge_panel.close_panel()
	quit()


func _slot_is_dark(panel: TortugaPanel, weapon_name: String) -> bool:
	for slot in panel.grid.get_children():
		if slot.tooltip_text == weapon_name:
			return slot.get_node("Button/Darken").visible
	assert(false, "Blueprint slot missing: " + weapon_name)
	return false


func _trend_for(rows: Array, title: String) -> int:
	for row in rows:
		if row.title == title:
			return int(row.trend)
	assert(false, "Forge stat missing: " + title)
	return 0
