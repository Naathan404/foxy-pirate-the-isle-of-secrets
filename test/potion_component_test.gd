extends SceneTree

var _failures: int = 0
var _used: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var inventory := Inventory.new()
	root.add_child(inventory)
	var health := HealthComponent.new()
	root.add_child(health)
	health.init(10)
	var component := PotionComponent.new()
	component.inventory = inventory
	component.health = health
	root.add_child(component)
	component.potion_used.connect(func() -> void: _used += 1)
	var healing := HealingPotion.new()
	healing.item_id = "test_healing"
	healing.max_stack = 99
	healing.heal_amount = 5
	inventory.add_item(healing, 5)
	_check(component.equip_potion(healing), "Equip owned potion")
	_check(not component.use_equipped_potion(), "Full HP does not use potion")
	_check(component.get_equipped_quantity() == 5 and _used == 0, "Full HP preserves inventory")
	health.take_damage(3)
	_check(component.use_equipped_potion(), "Injured Player uses healing potion")
	_check(health.current_hp == 10, "Healing is clamped to max HP")
	_check(component.get_equipped_quantity() == 4 and _used == 1, "Consume and notify once")
	inventory.clear()
	_check(not component.use_equipped_potion(), "Empty inventory cannot use potion")
	_check(_used == 1, "Empty inventory has no use feedback")
	var unsupported := Potion.new()
	unsupported.item_id = "unsupported_potion"
	inventory.add_item(unsupported, 1)
	component.equip_potion(unsupported)
	_check(not component.use_equipped_potion(), "Unsupported potion does not report success")
	_check(_used == 1, "Unsupported potion does not emit used signal")
	_check(inventory.count_item(unsupported.item_id) == 1, "Unsupported potion is preserved")
	inventory.add_item(healing, 1)
	component.equip_potion(healing)
	component.health = null
	_check(not component.use_equipped_potion(), "Missing health component is rejected")
	component.free()
	health.free()
	inventory.free()
	if _failures == 0:
		print("Potion use and failure feedback checks passed")
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
