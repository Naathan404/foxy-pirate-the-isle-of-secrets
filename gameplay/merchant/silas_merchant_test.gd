extends SceneTree

const CATALOG: MerchantCatalog = preload("res://data/merchants/silas_catalog.tres")
const BOW: WeaponData = preload("res://data/weapon/weapon_bow.tres")
const ARROW: BaseItem = preload("res://data/items/consumables/wooden_arrow.tres")
const HEALING: BaseItem = preload("res://data/items/consumables/small_healing_potion.tres")
const LARGE_HEALING: BaseItem = preload("res://data/items/consumables/healing_potion.tres")
const STARFISH_CORE: BaseItem = preload("res://data/items/materials/starfish_core.tres")
const NPC_TEST_SCENE_PATH := "res://test/silas_test_scene.tscn"
const SILAS_SCENE: PackedScene = preload("res://gameplay/npcs/silas/silas_npc.tscn")
const TOAST_QUEUE_SCENE: PackedScene = preload("res://gameplay/merchant/trade_toast_queue.tscn")
const SHOP_PANEL_SCENE: PackedScene = preload("res://gameplay/merchant/silas_shop_panel.tscn")
const GOLD_DISPLAY_SCENE: PackedScene = preload("res://gameplay/economy/gold_display.tscn")

var _failures := 0


func _initialize() -> void:
	_test_purchase_rejections()
	_test_successful_item_trade()
	_test_configured_trade_amount()
	_test_multiple_trade_quantities()
	_test_catalog_prices_and_sales()
	_test_random_buy_stock()
	_test_weapon_is_one_time_purchase()
	await _test_shop_scene()
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
	var single_offer := MerchantOffer.new()
	single_offer.offer_id = &"single_arrow"
	single_offer.item = ARROW
	single_offer.buy_price = 2
	bundled_catalog.offers = [bundled_offer, single_offer]
	_assert_true(bundled_catalog.validate().is_empty(), "one item can have multiple buy offers")
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
	single_offer.sell_price = 1
	_assert_false(
		bundled_catalog.validate().is_empty(), "one item cannot have two sell offers"
	)
	inventory.free()


func _test_multiple_trade_quantities() -> void:
	var service := MerchantTransactionService.new(CATALOG)
	var inventory := _make_inventory(4)
	var wallet := GoldWallet.new()
	wallet.add_gold(10)
	_assert_equal(
		service.purchase(&"wooden_arrow", inventory, wallet, null, 3),
		MerchantTransactionService.Result.SUCCESS,
		"buying three arrows succeeds"
	)
	_assert_equal(inventory.count_item(ARROW.item_id), 3, "quantity purchase adds three arrows")
	_assert_equal(wallet.get_balance(), 4, "quantity purchase spends six gold")
	_assert_equal(
		service.sell(&"wooden_arrow", inventory, wallet, 2),
		MerchantTransactionService.Result.SUCCESS,
		"selling two arrows succeeds"
	)
	_assert_equal(inventory.count_item(ARROW.item_id), 1, "quantity sale removes two arrows")
	_assert_equal(wallet.get_balance(), 6, "quantity sale adds two gold")
	_assert_equal(
		service.sell(&"wooden_arrow", inventory, wallet, 2),
		MerchantTransactionService.Result.NOT_OWNED,
		"quantity sale rejects insufficient stock"
	)
	_assert_equal(inventory.count_item(ARROW.item_id), 1, "failed sale preserves stock")
	_assert_equal(wallet.get_balance(), 6, "failed sale preserves gold")
	inventory.free()


func _test_random_buy_stock() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 42
	var source_count := CATALOG.get_buy_offers().size()
	var fixed_count := CATALOG.guaranteed_buy_offer_ids.size()
	var expected_count := fixed_count + mini(
		CATALOG.random_buy_offer_count, source_count - fixed_count
	)
	var stock := CATALOG.roll_buy_stock(random)
	_assert_equal(stock.get_buy_offers().size(), expected_count, "stock has fixed and drawn offers")
	_assert_equal(
		CATALOG.get_buy_offers().size(), source_count, "rolling leaves the source pool intact"
	)
	_assert_true(stock.validate().is_empty(), "rolled catalog remains valid")
	for offer_id: StringName in CATALOG.guaranteed_buy_offer_ids:
		_assert_true(stock.get_offer(offer_id).buy_price > 0, "guaranteed offer remains available")
	var hidden_count := 0
	var service := MerchantTransactionService.new(stock)
	for offer: MerchantOffer in CATALOG.get_buy_offers():
		if stock.get_offer(offer.offer_id).buy_price == 0:
			hidden_count += 1
			_assert_true(service._get_buy_offer(offer.offer_id) == null, "hidden offer cannot be bought")
	_assert_equal(hidden_count, source_count - expected_count, "undrawn offers are hidden")
	_assert_true(
		stock.get_sell_offer_for_item(&"starfish_core") != null,
		"buy selection does not change what Silas buys from the player"
	)
	var store := SilasProgressStore.new()
	var before := store.get_shop_stock(CATALOG)
	_assert_true(
		before == store.get_shop_stock(CATALOG), "stock stays fixed during a play session"
	)
	var after := store.reroll_shop_stock(CATALOG)
	var changed := false
	for offer: MerchantOffer in CATALOG.get_buy_offers():
		if (before.get_offer(offer.offer_id).buy_price > 0) != (
			after.get_offer(offer.offer_id).buy_price > 0
		):
			changed = true
			break
	_assert_true(changed, "manual reroll changes the stock")
	store.free()


func _test_catalog_prices_and_sales() -> void:
	for offer: MerchantOffer in CATALOG.get_buy_offers():
		_assert_true(offer.buy_price > 0, "buy offer has a price")
	var potion_sell_offer := CATALOG.get_sell_offer_for_item(HEALING.item_id)
	_assert_true(potion_sell_offer != null, "Silas buys the configured small potion")
	if potion_sell_offer == null:
		return
	var service := MerchantTransactionService.new(CATALOG)
	var inventory := _make_inventory(2)
	var wallet := GoldWallet.new()
	inventory.add_item(HEALING, 1)
	_assert_equal(
		service.sell(potion_sell_offer.offer_id, inventory, wallet),
		MerchantTransactionService.Result.SUCCESS,
		"catalog accepts the configured potion sale"
	)
	_assert_equal(inventory.count_item(HEALING.item_id), 0, "potion sale removes the item")
	_assert_equal(wallet.get_balance(), potion_sell_offer.sell_price, "sale pays catalog price")
	inventory.free()


func _test_weapon_is_one_time_purchase() -> void:
	var bow_offer := MerchantOffer.new()
	bow_offer.offer_id = &"bow"
	bow_offer.kind = MerchantOffer.Kind.WEAPON
	bow_offer.weapon = BOW
	bow_offer.buy_price = 100
	var weapon_catalog := MerchantCatalog.new()
	weapon_catalog.offers = [bow_offer]
	var service := MerchantTransactionService.new(weapon_catalog)
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


func _test_shop_scene() -> void:
	var panel := SHOP_PANEL_SCENE.instantiate() as SilasShopPanel
	_assert_true(panel != null, "Silas shop scene loads")
	if panel == null:
		return
	root.add_child(panel)
	await process_frame
	_assert_true(panel.buy_tab != null, "buy tab is connected")
	_assert_true(panel.sell_tab != null, "sell tab is connected")
	_assert_true(panel.grid != null, "item grid is connected")
	_assert_true(panel.action_button != null, "purchase button is connected")
	panel.queue_free()
	await process_frame


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
	var npc := SILAS_SCENE.instantiate() as SilasNpc
	_assert_true(npc != null, "Silas scene loads")
	if npc != null:
		_assert_equal(npc.initial_state_name, &"Idle", "Silas starts idle")
		_assert_equal(npc.data.move_speed, 0.0, "Silas cannot walk")
		_assert_true(npc.get_node_or_null("States/Wander") == null, "Silas has no wander state")
		_assert_true(npc.get_node_or_null("States/Hidden") == null, "Silas has no hidden state")
		_assert_true(
			npc.get_node("Visual/AnimatedSprite3D") is AnimatedSprite3D, "Silas art is animated"
		)
		_assert_false(
			(npc.get_node("Visual/Sprite3D") as Sprite3D).visible, "legacy art stays hidden"
		)
		npc.free()
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
		var spawn_position := silas.global_position
		await _test_stationary(silas, "spawn")
		_assert_true(panel.open_for(player, silas.catalog), "shop panel opens for the player")
		_assert_true(panel.visible, "shop panel becomes visible")
		_assert_equal(
			panel.grid.get_child_count(),
			silas.catalog.get_buy_offers().size(),
			"buy tab renders the configured catalog"
		)
		_assert_equal(
			panel.reroll_button.visible, OS.has_feature("debug"), "reroll button is debug-only"
		)
		panel.reroll_button.pressed.emit()
		var session_stock := panel._catalog
		_assert_equal(
			panel.grid.get_child_count(), session_stock.get_buy_offers().size(),
			"debug reroll updates the open shop"
		)
		panel.reroll_button.pressed.emit()
		_assert_true(panel._catalog != session_stock, "debug button creates a new stock catalog")
		_assert_equal(SilasShopPanel.GRID_COLUMNS, 4, "shop grid uses the mockup's four columns")
		var first_buy_slot := panel.grid.get_child(0) as SilasShopSlot
		_assert_true(first_buy_slot != null, "shop uses the Silas slot art")
		_assert_true(panel.buy_tab is TextureButton, "buy tab uses the supplied texture")
		panel._set_tab(SilasShopPanel.Tab.SELL)
		var inventory := player.get_node_or_null("Inventory") as Inventory
		if inventory != null:
			_assert_true(
				panel.grid.get_child_count() <= inventory.slots.size(),
				"sell tab renders occupied inventory slots"
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
		await create_timer(1.0, true).timeout
		_assert_true(silas.sprite.visible, "Silas remains visible after farewell")
		var offset := silas.global_position - spawn_position
		offset.y = 0.0
		_assert_true(offset.length() <= 0.05, "Silas stays at spawn after shop closes")
		await _test_stationary(silas, "spawn after farewell")
	# This test owns a complete Hub fixture. Free it before SceneTree.quit() so
	# GridMap physics/render resources are released while the engine is alive.
	scene.free()
	fixture = null
	await process_frame


func _test_stationary(silas: SilasNpc, location: String) -> void:
	var start := silas.global_position
	for _frame in 60:
		await process_frame
		var offset := silas.global_position - start
		offset.y = 0.0
		_assert_true(offset.length() <= 0.05, "Silas remains stationary at %s" % location)


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
