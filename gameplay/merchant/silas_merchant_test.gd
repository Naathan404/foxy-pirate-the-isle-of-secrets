extends SceneTree

const CATALOG: MerchantCatalog = preload("res://data/merchants/silas_catalog.tres")
const BOW: WeaponData = preload("res://data/weapon/weapon_bow.tres")
const ARROW: BaseItem = preload("res://data/items/materials/wooden_arrow.tres")
const HEALING: BaseItem = preload("res://data/items/consumables/small_healing_potion.tres")
const LARGE_HEALING: BaseItem = preload("res://data/items/consumables/healing_potion.tres")
const STARFISH_CORE: BaseItem = preload("res://data/items/materials/starfish_core.tres")
const NPC_TEST_SCENE_PATH := "res://test/silas_test_scene.tscn"
const TOAST_QUEUE_SCENE: PackedScene = preload("res://gameplay/merchant/trade_toast_queue.tscn")
const GOLD_DISPLAY_SCENE: PackedScene = preload("res://gameplay/economy/gold_display.tscn")

var _failures := 0


func _initialize() -> void:
	_test_purchase_rejections()
	_test_successful_item_trade()
	_test_configured_trade_amount()
	_test_catalog_prices_and_disabled_sales()
	_test_weapon_is_one_time_purchase()
	_test_persistence()
	await _test_toast_queue()
	await _test_gold_display_feedback()
	await _test_npc_scene_smoke()
	print("Silas merchant tests: %s" % ("passed" if _failures == 0 else "failed"))
	quit(0 if _failures == 0 else 1)


func _test_purchase_rejections() -> void:
	var service := MerchantTransactionService.new(CATALOG)
	var wallet := GoldWallet.new()
	var inventory := _make_inventory(1)
	_assert_equal(
		service.purchase(&"wooden_arrow", inventory, wallet, null),
		MerchantTransactionService.Result.INSUFFICIENT_GOLD,
		"purchase rejects insufficient gold"
	)
	_assert_equal(wallet.get_balance(), 0, "failed purchase keeps gold")

	inventory.add_item(STARFISH_CORE, 1)
	wallet.add_gold(2)
	_assert_equal(
		service.purchase(&"wooden_arrow", inventory, wallet, null),
		MerchantTransactionService.Result.INVENTORY_FULL,
		"purchase rejects a full inventory"
	)
	_assert_equal(wallet.get_balance(), 2, "full inventory keeps gold")

	var potion_inventory := _make_inventory(3)
	potion_inventory.default_potion_capacity = 0
	_assert_equal(
		service.purchase(&"small_healing_potion", potion_inventory, GoldWallet.new(), null),
		MerchantTransactionService.Result.INSUFFICIENT_GOLD,
		"potion test begins with insufficient gold"
	)
	var potion_wallet := GoldWallet.new()
	potion_wallet.add_gold(25)
	_assert_equal(
		service.purchase(&"small_healing_potion", potion_inventory, potion_wallet, null),
		MerchantTransactionService.Result.INVENTORY_FULL,
		"potion capacity rejects purchase"
	)
	_assert_equal(potion_wallet.get_balance(), 25, "potion capacity keeps gold")
	inventory.free()
	potion_inventory.free()


func _test_successful_item_trade() -> void:
	var service := MerchantTransactionService.new(CATALOG)
	var inventory := _make_inventory(4)
	var wallet := GoldWallet.new()
	wallet.add_gold(12)
	_assert_equal(
		service.purchase(&"wooden_arrow", inventory, wallet, null),
		MerchantTransactionService.Result.SUCCESS,
		"arrow purchase succeeds"
	)
	_assert_equal(inventory.count_item(ARROW.item_id), 1, "purchased arrow enters inventory")
	_assert_equal(wallet.get_balance(), 10, "purchase spends configured price")
	_assert_equal(
		service.sell(&"starfish_core", inventory, wallet),
		MerchantTransactionService.Result.NOT_OWNED,
		"cannot sell an absent item"
	)
	inventory.add_item(STARFISH_CORE, 1)
	_assert_equal(
		service.sell(&"starfish_core", inventory, wallet),
		MerchantTransactionService.Result.SUCCESS,
		"enemy drop sells successfully"
	)
	_assert_equal(inventory.count_item(STARFISH_CORE.item_id), 0, "sold item is removed")
	_assert_equal(wallet.get_balance(), 15, "sale adds configured gold")
	inventory.free()


func _test_configured_trade_amount() -> void:
	var bundled_offer := MerchantOffer.new()
	bundled_offer.offer_id = &"arrow_bundle"
	bundled_offer.item = ARROW
	bundled_offer.trade_amount = 3
	bundled_offer.buy_price = 6
	bundled_offer.sell_price = 3
	var bundled_catalog := MerchantCatalog.new()
	bundled_catalog.offers = [bundled_offer]
	var service := MerchantTransactionService.new(bundled_catalog)
	var inventory := _make_inventory(2)
	var wallet := GoldWallet.new()
	wallet.add_gold(6)
	_assert_equal(
		service.purchase(&"arrow_bundle", inventory, wallet, null),
		MerchantTransactionService.Result.SUCCESS,
		"configured trade amount purchases the whole bundle"
	)
	_assert_equal(inventory.count_item(ARROW.item_id), 3, "purchase adds configured trade amount")
	_assert_equal(wallet.get_balance(), 0, "bundle purchase spends configured price once")
	_assert_equal(
		service.sell(&"arrow_bundle", inventory, wallet),
		MerchantTransactionService.Result.SUCCESS,
		"configured trade amount sells the whole bundle"
	)
	_assert_equal(inventory.count_item(ARROW.item_id), 0, "sale removes configured trade amount")
	_assert_equal(wallet.get_balance(), 3, "bundle sale uses configured price once")
	inventory.free()


func _test_catalog_prices_and_disabled_sales() -> void:
	_assert_equal(
		CATALOG.get_offer(&"starfish_core").buy_price, 50, "starfish buy price comes from catalog"
	)
	_assert_equal(
		CATALOG.get_offer(&"starfish_core").sell_price, 5, "starfish sell price comes from catalog"
	)
	_assert_equal(
		CATALOG.get_offer(&"crab_claw").sell_price, 5, "crab sale price comes from catalog"
	)
	_assert_equal(
		CATALOG.get_offer(&"gunpowder_bag").sell_price, 5, "gunpowder sale price comes from catalog"
	)
	_assert_equal(
		CATALOG.get_offer(&"small_healing_potion").buy_price,
		25,
		"small healing price comes from catalog"
	)
	_assert_equal(
		CATALOG.get_offer(&"healing_potion").buy_price, 45, "large healing price comes from catalog"
	)
	_assert_equal(
		CATALOG.get_offer(&"small_stamina_potion").buy_price,
		15,
		"small stamina price comes from catalog"
	)
	_assert_equal(
		CATALOG.get_offer(&"stamina_potion").buy_price, 30, "large stamina price comes from catalog"
	)
	_assert_true(
		CATALOG.get_sell_offer_for_item(HEALING.item_id) == null, "small potion cannot be sold"
	)
	_assert_true(
		CATALOG.get_sell_offer_for_item(LARGE_HEALING.item_id) == null,
		"large potion cannot be sold"
	)
	var service := MerchantTransactionService.new(CATALOG)
	var inventory := _make_inventory(2)
	var wallet := GoldWallet.new()
	inventory.add_item(HEALING, 1)
	_assert_equal(
		service.sell(&"small_healing_potion", inventory, wallet),
		MerchantTransactionService.Result.INVALID_OFFER,
		"catalog prevents selling a potion without a sell price"
	)
	_assert_equal(inventory.count_item(HEALING.item_id), 1, "rejected potion sale keeps the item")
	_assert_equal(wallet.get_balance(), 0, "rejected potion sale keeps gold")
	inventory.free()


func _test_weapon_is_one_time_purchase() -> void:
	var service := MerchantTransactionService.new(CATALOG)
	var weapons := WeaponController.new()
	var entry := WeaponCollectionEntry.new()
	entry.definition = BOW
	weapons.collection = [entry]
	weapons._initialize_collection()
	var wallet := GoldWallet.new()
	wallet.add_gold(100)
	var inventory := _make_inventory(2)
	_assert_equal(
		service.purchase(&"bow", inventory, wallet, weapons),
		MerchantTransactionService.Result.SUCCESS,
		"bow purchase grants weapon"
	)
	_assert_true(weapons.is_weapon_owned(&"bow"), "bow is owned after purchase")
	_assert_equal(wallet.get_balance(), 0, "bow purchase spends 100 gold")
	_assert_equal(
		service.purchase(&"bow", inventory, wallet, weapons),
		MerchantTransactionService.Result.ALREADY_OWNED,
		"bow cannot be purchased twice"
	)
	inventory.free()
	weapons.free()


func _test_persistence() -> void:
	var path := "user://silas_merchant_test.save"
	var absolute_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(absolute_path)
	var first := SilasProgressStore.new()
	first.save_path = path
	_assert_true(first.load_progress(), "empty merchant save loads")
	_assert_false(first.has_met_silas(), "new save has no first meeting")
	_assert_true(first.mark_met_silas(), "first meeting persists")
	_assert_true(first.mark_bow_purchased(), "bow purchase persists")
	var restored := SilasProgressStore.new()
	restored.save_path = path
	_assert_true(restored.load_progress(), "saved merchant progress loads")
	_assert_true(restored.has_met_silas(), "first meeting restores")
	_assert_true(restored.has_bow_purchase(), "bow purchase restores")
	DirAccess.remove_absolute(absolute_path)
	first.free()
	restored.free()


func _test_toast_queue() -> void:
	var queue := TOAST_QUEUE_SCENE.instantiate() as TradeToastQueue
	root.add_child(queue)
	await process_frame
	_assert_equal(
		queue.process_mode, Node.PROCESS_MODE_ALWAYS, "toast queue processes while paused"
	)
	queue.enqueue_success("First trade")
	queue.enqueue_success("Second trade")
	_assert_equal(queue.pending_count(), 2, "toast queue keeps both trade messages")
	_assert_equal(queue.message.text, "First trade", "toast queue shows the first message")
	queue._kill_tween()
	queue._finish_current()
	_assert_equal(queue.message.text, "Second trade", "toast queue advances in FIFO order")
	queue._kill_tween()
	queue._finish_current()
	_assert_equal(queue.pending_count(), 0, "toast queue drains after the final message")
	queue.queue_free()
	await process_frame
	await process_frame


func _test_gold_display_feedback() -> void:
	var display := GOLD_DISPLAY_SCENE.instantiate()
	root.add_child(display)
	await process_frame
	_assert_equal(
		display.process_mode, Node.PROCESS_MODE_ALWAYS, "gold display processes while paused"
	)
	display._on_balance_changed(10, 5)
	_assert_true(display._gain.visible, "gold gain feedback becomes visible")
	_assert_equal(display._gain.text, "+5 G", "gold gain feedback uses a positive sign")
	paused = true
	display._on_balance_changed(8, -2)
	_assert_true(display._gain.visible, "gold spend feedback becomes visible")
	_assert_equal(display._gain.text, "-2 G", "gold spend feedback uses a negative sign")
	await create_timer(0.9, true).timeout
	_assert_false(display._gain.visible, "gold feedback cleans itself after its tween")
	paused = false
	display.queue_free()
	await process_frame
	await process_frame


func _test_npc_scene_smoke() -> void:
	if DisplayServer.get_name() == "headless":
		_assert_true(
			ResourceLoader.exists(NPC_TEST_SCENE_PATH, "PackedScene"),
			"Silas Hub fixture is present"
		)
		# GridMap physics/render RIDs from the complete Hub cannot be torn down
		# cleanly by Godot's headless script runner. Gameplay smoke coverage still
		# runs in the editor; CI verifies that the real Hub fixture is present.
		return
	var fixture := ResourceLoader.load(NPC_TEST_SCENE_PATH) as PackedScene
	_assert_true(fixture != null, "Silas fixture loads")
	if fixture == null:
		return
	var scene := fixture.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var silas := scene.get_node_or_null("Hub/Silas") as SilasNpc
	var panel := scene.get_node_or_null("Hub/SilasShopPanel") as SilasShopPanel
	var player := _get_game_manager_player()
	_assert_true(silas != null, "npc test scene contains Silas")
	_assert_true(panel != null, "npc test scene contains shop panel")
	_assert_true(player != null, "Hub fixture registers a player")
	if silas != null and panel != null and player != null:
		await _test_wander_bounds(silas)
		_assert_true(panel.open_for(player, silas.catalog), "shop panel opens for the player")
		_assert_true(panel.visible, "shop panel becomes visible")
		_assert_equal(
			panel.grid.get_child_count(),
			silas.catalog.get_buy_offers().size(),
			"buy tab renders the configured catalog"
		)
		_assert_equal(panel.grid.columns, 5, "shop grid keeps inventory's five-column layout")
		var first_buy_slot := panel.grid.get_child(0) as InventorySlotUI
		_assert_false(
			first_buy_slot.quantity_label.visible, "buy previews do not show redundant quantities"
		)
		_assert_true(panel.buy_tab is TextureButton, "buy tab uses an inventory-style bookmark")
		panel._set_tab(SilasShopPanel.Tab.SELL)
		var inventory := player.get_node_or_null("Inventory") as Inventory
		if inventory != null:
			_assert_equal(
				panel.grid.get_child_count(),
				inventory.slots.size(),
				"sell tab renders the real inventory"
			)
			panel._set_tab(SilasShopPanel.Tab.BAG)
			_assert_equal(
				panel.grid.get_child_count(),
				inventory.slots.size(),
				"bag tab renders the real inventory"
			)
		panel.close_shop()
		await create_timer(panel.close_duration + 0.05, true).timeout
		_assert_false(panel.visible, "shop panel closes")
		_assert_true(
			ResourceLoader.exists(silas.data.dialogue_timeline), "first-meeting timeline exists"
		)
		_assert_true(
			ResourceLoader.exists(silas.data.greeting_timeline), "greeting timeline exists"
		)
		_assert_true(
			ResourceLoader.exists(silas.data.farewell_timeline), "farewell timeline exists"
		)
		await create_timer(0.1, true).timeout
		_assert_false(panel.visible, "farewell never reopens the shop")
		await _test_hidden_departure(scene, silas)
	# This test owns a complete Hub fixture. Free it before SceneTree.quit() so
	# GridMap physics/render resources are released while the engine is alive.
	scene.free()
	fixture = null
	await process_frame


func _test_hidden_departure(scene: Node, silas: SilasNpc) -> void:
	var player := _get_game_manager_player()
	_assert_true(player != null, "Hub fixture registers a player")
	var hideouts := scene.get_tree().get_nodes_in_group(&"silas_hideouts")
	_assert_true(not hideouts.is_empty(), "Hub fixture contains Silas hideouts")
	if player == null or hideouts.is_empty():
		return
	player.global_position = Vector3.ZERO
	var chosen_hideout := silas._choose_hideout(player)
	_assert_true(chosen_hideout != null, "Silas finds a safe hideout")
	if chosen_hideout != null:
		_assert_true(
			(
				chosen_hideout.global_position.distance_to(player.global_position)
				>= silas.minimum_hideout_distance
			),
			"chosen hideout is far enough from the player"
		)
	silas.begin_departure(player)
	var destination := silas._hidden_destination
	player.global_position = destination
	await create_timer(silas.burrow_duration + 0.08, true).timeout
	_assert_true(silas._is_hidden, "Silas stays hidden while the player is near the new hideout")
	_assert_true(
		silas.global_position.distance_to(destination) <= 0.01,
		"Silas teleports exactly to the selected hideout"
	)
	_assert_false(silas.interaction_area._enabled, "hidden Silas cannot interact")
	player.global_position = (
		silas.global_position + Vector3(silas.minimum_hideout_distance + 1.0, 0.0, 0.0)
	)
	await process_frame
	await create_timer(silas.burrow_duration + 0.08, true).timeout
	_assert_false(silas._is_hidden, "Silas emerges after the player moves away")
	await process_frame
	_assert_true(silas.is_on_floor(), "Silas emerges on the Hub floor")
	var emerged_offset := silas.global_position - destination
	emerged_offset.y = 0.0
	_assert_true(
		emerged_offset.length() <= 0.75, "Silas remains at the selected hideout after emerging"
	)


func _test_wander_bounds(silas: SilasNpc) -> void:
	var maximum_distance := silas.get_silas_data().wander_radius + 0.3
	for _frame in 60:
		await process_frame
		var offset := silas.global_position - silas.get_wander_anchor()
		offset.y = 0.0
		_assert_true(
			offset.length() <= maximum_distance, "Silas wander remains within the hideout radius"
		)


func _get_game_manager_player() -> Player:
	var manager := root.get_node_or_null("GameManager")
	return manager.get("player") as Player if manager != null else null


func _make_inventory(capacity: int) -> Inventory:
	var inventory := Inventory.new()
	inventory.capacity = capacity
	inventory._ready()
	return inventory


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		return
	_failures += 1
	push_error("Silas merchant test failed: %s (expected %s, got %s)" % [message, expected, actual])


func _assert_true(value: bool, message: String) -> void:
	_assert_equal(value, true, message)


func _assert_false(value: bool, message: String) -> void:
	_assert_equal(value, false, message)
