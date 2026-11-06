extends VBoxContainer
## Groups notifications for items collected from the world.

@export var entry_scene: PackedScene
@export_range(1, 20, 1) var max_visible: int = 4

var _entries: Dictionary = {}


func show_pickup(item: BaseItem, quantity: int) -> void:
	if item == null or quantity <= 0 or entry_scene == null:
		return
	if _entries.has(item.item_id):
		_entries[item.item_id].add_quantity(quantity)
		return
	if get_child_count() >= max_visible:
		_remove_entry(get_child(0))
	var entry = entry_scene.instantiate()
	add_child(entry)
	entry.expired.connect(_remove_entry)
	entry.show_item(item, quantity)
	_entries[item.item_id] = entry


func _remove_entry(entry: Control) -> void:
	_entries.erase(entry.item_id)
	remove_child(entry)
	entry.queue_free()
