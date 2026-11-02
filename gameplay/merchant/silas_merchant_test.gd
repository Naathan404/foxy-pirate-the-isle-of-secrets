extends SceneTree

const CATALOG: MerchantCatalog = preload("res://data/merchants/silas_catalog.tres")
const BOW: WeaponData = preload("res://data/weapon/weapon_bow.tres")
const ARROW: BaseItem = preload("res://data/items/materials/wooden_arrow.tres")
const HEALING: BaseItem = preload("res://data/items/consumables/small_healing_potion.tres")
const STARFISH_CORE: BaseItem = preload("res://data/items/materials/starfish_core.tres")
const NPC_TEST_SCENE: PackedScene = preload("res://world/tests/npc_test_scene.tscn")

var _failures := 0


func _initialize() -> void:
	_test_purchase_rejections()
	_test_successful_item_trade()
	_test_weapon_is_one_time_purchase()
	_test_persistence()
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
	potion_wallet.add_gold(20)
	_assert_equal(
		service.purchase(&"small_healing_potion", potion_inventory, potion_wallet, null),
		MerchantTransactionService.Result.INVENTORY_FULL,
		"potion capacity rejects purchase"
	)
	_assert_equal(potion_wallet.get_balance(), 20, "potion capacity keeps gold")


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


func _test_npc_scene_smoke() -> void:
	var scene := NPC_TEST_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var silas := scene.get_node_or_null("Silas") as SilasNpc
	var panel := scene.get_node_or_null("SilasShopPanel") as SilasShopPanel
	_assert_true(silas != null, "npc test scene contains Silas")
	_assert_true(panel != null, "npc test scene contains shop panel")
	if silas != null and panel != null:
		_assert_true(panel.open_for(GameManager.player, silas.catalog), "shop panel opens for the player")
		_assert_true(panel.visible, "shop panel becomes visible")
		panel.close_shop()
		_assert_false(panel.visible, "shop panel closes")
	scene.queue_free()
	await process_frame


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
