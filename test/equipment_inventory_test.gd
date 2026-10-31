extends SceneTree
## Run normally to capture actual rendered previews; --headless runs layout/interaction checks.

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var backdrop := ColorRect.new()
	backdrop.color = Color("213c35")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	world.add_child(backdrop)
	var player := load("res://gameplay/player/foxy.tscn").instantiate() as Player
	world.add_child(player)
	player.set_physics_process(false)
	await _frames(5)
	var controller := player.weapon_controller
	var dagger := WeaponInstance.new()
	dagger.definition = load("res://data/weapon/weapon_dagger.tres")
	dagger.forge = load("res://data/weapon/forges/keen_edge.tres").duplicate()
	dagger.forge.damage_multiplier = 0.95
	_check(controller.equip(dagger), "Owned dagger can equip")
	var ui := player.inventory_ui
	ui.open_inventory()
	ui._select_tab(1)
	await create_timer(0.3).timeout
	await _frames(4)
	var equipment = ui.equipment_tab
	_check(
		equipment._entries.size() == controller.get_owned_weapons().size(),
		"Only owned weapons are listed"
	)
	_check(equipment.get_node("%ItemTitle").text == "Dagger", "Selected weapon title is live")
	_check(equipment.get_node("%StatValue4").text == "20%", "Keen Edge critical rate is displayed")
	_check(equipment.get_node("%StatValue0").text == "0.95", "Fractional forge damage is displayed")
	_check(
		equipment.get_node("%ForgeRows").get_child_count() == 2,
		"Single forge shows its two actual effects"
	)
	var owned := controller.get_owned_weapons()
	owned.clear()
	_check(
		not controller.get_owned_weapons().is_empty(), "UI cannot mutate owned weapon collection"
	)
	for screen: Vector2i in [
		Vector2i(1280, 720), Vector2i(960, 540), Vector2i(1920, 1080), Vector2i(1024, 768)
	]:
		root.content_scale_size = Vector2i(1280, 720)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		root.size = screen
		await _frames(4)
		equipment._layout_content()
		await _frames(3)
		_check_layout(ui, equipment, screen)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute("res://.cache_local/equipment")
			root.get_texture().get_image().save_png(
				"res://.cache_local/equipment/preview_%dx%d.png" % [screen.x, screen.y]
			)
	root.size = Vector2i(1280, 720)
	equipment._set_category(true)
	await _frames(3)
	_check(
		equipment.get_node("%ItemGrid").get_child_count() == 20,
		"Both categories retain the same grid geometry"
	)
	_check(equipment.get_node("%EquipButton").disabled, "Unsafe location blocks charm changes")
	var manager := player.charm_socket_manager
	manager.set_safe_location(true)
	manager.registry.set_owned(&"arrow_rain", true)
	equipment._selection = manager.registry.get_definition(&"arrow_rain")
	equipment.refresh()
	_check(
		not equipment.get_node("%EquipButton").disabled, "Owned charm can equip at safe location"
	)
	equipment._equip_selected()
	_check(
		manager.get_equipped_charm(0) == &"arrow_rain",
		"Equipment command reaches the actual charm socket"
	)
	manager.set_safe_location(false)
	_check(equipment.get_node("%EquipButton").disabled, "Leaving safe location blocks unequipping")
	await _frames(3)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.cache_local/equipment/preview_charms.png")
	var stress := WeaponInstance.new()
	stress.definition = dagger.definition.duplicate(true)
	stress.definition.display_name = "A remarkably long named pirate dagger for layout verification"
	stress.definition.description = "A long description. ".repeat(25)
	stress.forge = load("res://data/weapon/forges/crippling_weight.tres")
	controller.equip(stress)
	equipment._set_category(false)
	await _frames(4)
	_check_layout(ui, equipment, Vector2i(1280, 720))
	for i in 20:
		var extra := WeaponInstance.new()
		extra.definition = dagger.definition
		controller.equip(extra)
	equipment._turn_page(1)
	await _frames(3)
	_check(
		equipment.get_node("%PageLabel").text == "2 / 2",
		"Collections paginate after twenty entries"
	)
	equipment._select_index(0)
	_check(
		equipment._selection == controller.get_owned_weapons()[20],
		"Second page selects the correct owned instance"
	)
	_check_layout(ui, equipment, Vector2i(1280, 720))
	ui._select_tab(0)
	await _frames(2)
	_check(ui.panel.size == Vector2(800, 500), "Materials retains its original book layout")
	ui.close_inventory(true)
	world.free()
	if _failures == 0:
		print(
			"Equipment inventory: data, forge stats, ownership, "
			+ "safe-location guard and four viewport layouts passed"
		)
	quit(0 if _failures == 0 else 1)


func _check_layout(ui: InventoryUI, equipment: Control, screen: Vector2i) -> void:
	var book := ui.panel.get_global_rect()
	_check(ui.panel.size == Vector2(800, 500), "Original book panel size is preserved")
	_check(ui.panel.scale == Vector2.ONE, "Original panel scale is preserved")
	_check(
		ui.book_background.scale.is_equal_approx(ui._book_scale),
		"Original background scale is preserved"
	)
	_check(ui.tab_buttons.position == Vector2(1040, 200), "Original side-tab position is preserved")
	_check(
		Rect2(Vector2.ZERO, ui.get_viewport().get_visible_rect().size).encloses(book),
		"Book fits viewport " + str(screen)
	)
	_check(
		Rect2(Vector2.ZERO, ui.get_viewport().get_visible_rect().size).encloses(
			ui.tab_buttons.get_global_rect()
		),
		"Side tabs fit viewport " + str(screen)
	)
	for page_name: String in ["Left", "Right"]:
		var page := equipment.get_node("Content/" + page_name) as Control
		_check(book.encloses(page.get_global_rect()), page_name + " page stays inside book")
		var paper := Rect2(
			book.position + Vector2(12 if page_name == "Left" else 420, 16), Vector2(368, 440)
		)
		_check(
			paper.grow(1).encloses(page.get_global_rect()),
			page_name + " clears original paper border"
		)
		for child: Node in page.get_children():
			if child is Control and child.visible:
				_check(
					page.get_global_rect().grow(1).encloses(child.get_global_rect()),
					child.name + " fits page"
				)
	_check(
		equipment.get_node("%ItemGrid").size.x <= equipment.get_node("Content/Left").size.x,
		"Grid fits left page"
	)
	var left := equipment.get_node("Content/Left") as Control
	var right := equipment.get_node("Content/Right") as Control
	_check(is_equal_approx(left.size.x, right.size.x), "Pages keep equal widths around book spine")
	var equipped_frame := equipment.get_node("Content/Left/EquippedFrame") as Control
	var weapon_slot := equipment.get_node("%EquippedWeapon") as Control
	for slot_name: String in ["EquippedWeapon", "EquippedQ", "EquippedSpace", "EquippedE"]:
		var equipped_slot := equipment.get_node("%" + slot_name) as Control
		_check(
			is_equal_approx(
				equipped_slot.get_global_rect().end.y, weapon_slot.get_global_rect().end.y
			),
			"Equipped slots share a bottom baseline"
		)
		_check(
			equipped_frame.get_global_rect().encloses(equipped_slot.get_global_rect()),
			"Equipped slots stay inside their frame"
		)
	var slots := equipment.get_node("%ItemGrid").get_children()
	for index in slots.size():
		var slot := slots[index] as Control
		var background := slot.get_node("TextureRect") as Control
		_check(
			(
				slot
				. get_global_rect()
				. grow(
					(
						slot.get_global_rect().size.x * (float(slot.get("hover_scale")) - 1.0) * 0.5
						+ 0.1
					)
				)
				. encloses(background.get_global_rect())
			),
			"Slot feedback stays within its allowed hover margin"
		)
		if index % 5 < 4:
			_check(
				slot.get_global_rect().end.x < slots[index + 1].get_global_rect().position.x,
				"Adjacent slot columns do not overlap"
			)
		if index + 5 < slots.size():
			_check(
				slot.get_global_rect().end.y < slots[index + 5].get_global_rect().position.y,
				"Adjacent slot rows do not overlap"
			)
	_check(
		(
			equipment.get_node("Content/Right").get_global_rect().position.x
			> equipment.get_node("Content/Left").get_global_rect().end.x
		),
		"Pages do not overlap"
	)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
