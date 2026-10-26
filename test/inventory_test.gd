extends SceneTree

var _failures: int = 0
var _changes: int = 0


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var inventory := Inventory.new()
    inventory.capacity = 2
    root.add_child(inventory)
    inventory.changed.connect(func() -> void: _changes += 1)

    var potion := BaseItem.new()
    potion.item_id = "healing_potion"
    potion.max_stack = 99
    var other := BaseItem.new()
    other.item_id = "other"
    other.max_stack = 1

    _check(inventory.get_empty_slot_count() == 2, "Inventory starts empty")
    _check(inventory.slots[0] != inventory.slots[1], "Slots are independent")
    _check(inventory.get_slot(-1) == null and inventory.get_slot(2) == null, "Invalid indices")
    _check(inventory.can_add_item(potion, 198), "Empty space includes all slots")
    _check(not inventory.can_add_item(potion, 199), "Reject amount above capacity")
    _check(inventory.add_item(potion, 120) == 0, "Add across empty slots")
    _check(inventory.slots[0].quantity == 99 and inventory.slots[1].quantity == 21, "Stack limits")
    _check(inventory.get_available_space(potion) == 78, "Remaining stack space")
    _check(inventory.get_available_space(other) == 0, "Other items cannot share stacks")
    _check(inventory.has_item(&"healing_potion", 120), "Count across slots")
    _check(inventory.add_item(potion, 80) == 2, "Return overflow when full")
    _check(_changes == 2, "Emit once per successful addition")
    _check(inventory.add_item(other, 1) == 1, "Full inventory leaves item untouched")
    _check(inventory.add_item(null, 5) == 5, "Null item leaves amount untouched")
    _check(inventory.add_item(potion, -1) == 0, "Ignore negative additions")
    _check(_changes == 2, "No signal for unchanged inventory")
    _check(inventory.remove_item(&"healing_potion", 105) == 105, "Remove across slots")
    _check(inventory.slots[0].is_empty() and inventory.count_item(&"healing_potion") == 93, "Clear exhausted slot")
    _check(inventory.remove_from_slot(1, 3) == 3, "Remove from selected slot")
    _check(inventory.remove_from_slot(-1, 2) == 0, "Ignore invalid selected slot")
    _check(inventory.remove_item(&"missing", 5) == 0, "Missing item removal")
    _check(not inventory.has_item(&"healing_potion", 91), "Insufficient quantity")
    _check(inventory.remove_item(&"healing_potion", 100) == 90, "Return actual removed quantity")
    _check(inventory.get_empty_slot_count() == 2, "All exhausted slots are empty")
    inventory.add_item(other, 1)
    var first_slot := inventory.get_slot(0)
    var changes_before_clear: int = _changes
    inventory.clear()
    _check(inventory.get_empty_slot_count() == 2 and inventory.get_slot(0) == first_slot, "Clear preserves slots")
    _check(_changes == changes_before_clear + 1, "Clear emits once")
    inventory.clear()
    _check(_changes == changes_before_clear + 1, "Empty clear emits nothing")
    inventory.free()

    if _failures == 0:
        print("Inventory checks passed")
    quit(0 if _failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
    if not condition:
        _failures += 1
        push_error(message)
