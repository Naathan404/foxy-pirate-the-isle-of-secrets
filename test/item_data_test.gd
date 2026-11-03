extends SceneTree

const ITEM_DIRECTORY := "res://data/items"
const ENEMY_DIRECTORY := "res://data/enemies"
const CATALOG: MerchantCatalog = preload("res://data/merchants/silas_catalog.tres")
const BOW: WeaponData = preload("res://data/weapon/weapon_bow.tres")

var _failures := 0


func _initialize() -> void:
	var items := _load_items()
	_test_item_contracts(items)
	_test_catalog_contracts(items)
	_test_enemy_drop_contracts(items)
	print("Item data tests: %s" % ("passed" if _failures == 0 else "failed"))
	quit(0 if _failures == 0 else 1)


func _load_items() -> Dictionary[StringName, BaseItem]:
	var paths := PackedStringArray()
	_collect_resource_paths(ITEM_DIRECTORY, paths)
	var items: Dictionary[StringName, BaseItem] = {}
	for path in paths:
		var item := ResourceLoader.load(path) as BaseItem
		_assert_true(item != null, "item resource loads: %s" % path)
		if item == null:
			continue
		_assert_false(item.item_id.is_empty(), "item ID is not empty: %s" % path)
		_assert_false(items.has(item.item_id), "item ID is unique: %s" % item.item_id)
		items[item.item_id] = item
	return items


func _test_item_contracts(items: Dictionary[StringName, BaseItem]) -> void:
	for item: BaseItem in items.values():
		_assert_true(item.icon != null, "item has icon: %s" % item.item_id)
		_assert_false(item.display_name.is_empty(), "item has display name: %s" % item.item_id)
		_assert_false(item.description.is_empty(), "item has description: %s" % item.item_id)
		_assert_true(item.max_stack > 0, "item stack is positive: %s" % item.item_id)
		if item is Potion:
			_assert_equal(
				item.type,
				GlobalConstants.ItemType.CONSUMABLE,
				"potion has consumable type: %s" % item.item_id
			)
		if item is HealingPotion:
			_assert_true((item as HealingPotion).heal_amount > 0.0, "healing amount is positive")
		elif item is StaminaPotion:
			_assert_true((item as StaminaPotion).restore_amount > 0.0, "stamina amount is positive")
		elif item is DualEssencePotion:
			var dual := item as DualEssencePotion
			_assert_true(
				dual.heal_amount > 0.0 and dual.stamina_amount > 0.0,
				"dual potion values are positive"
			)


func _test_catalog_contracts(items: Dictionary[StringName, BaseItem]) -> void:
	_assert_true(CATALOG.validate().is_empty(), "Silas catalog is valid")
	for offer: MerchantOffer in CATALOG.offers:
		if offer.kind == MerchantOffer.Kind.ITEM:
			_assert_true(items.has(offer.item.item_id), "catalog item is in data directory")
	_assert_true(items.has(BOW.normal_attack.ammo_id), "bow normal attack ammo exists")
	_assert_true(items.has(BOW.secondary_attack.ammo_id), "bow secondary attack ammo exists")


func _test_enemy_drop_contracts(items: Dictionary[StringName, BaseItem]) -> void:
	var paths := PackedStringArray()
	_collect_resource_paths(ENEMY_DIRECTORY, paths)
	for path in paths:
		var enemy := ResourceLoader.load(path) as EnemyData
		if enemy == null or enemy.drop_item == null:
			continue
		_assert_true(
			items.has(enemy.drop_item.item_id), "enemy drop is an item resource: %s" % path
		)
		_assert_true(
			CATALOG.get_sell_offer_for_item(enemy.drop_item.item_id) != null,
			"Silas buys enemy drop: %s" % enemy.drop_item.item_id
		)


func _collect_resource_paths(path: String, paths: PackedStringArray) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		_failures += 1
		push_error("Item data test cannot read directory: %s" % path)
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if not entry.begins_with("."):
			var child_path := path.path_join(entry)
			if directory.current_is_dir():
				_collect_resource_paths(child_path, paths)
			elif entry.ends_with(".tres"):
				paths.append(child_path)
		entry = directory.get_next()
	directory.list_dir_end()


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		return
	_failures += 1
	push_error("Item data test failed: %s (expected %s, got %s)" % [message, expected, actual])


func _assert_true(value: bool, message: String) -> void:
	_assert_equal(value, true, message)


func _assert_false(value: bool, message: String) -> void:
	_assert_equal(value, false, message)
