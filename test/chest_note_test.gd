extends SceneTree

const CHEST_SCENE = preload("res://world/objects/treasure_chest.tscn")
const NOTE = preload("res://data/notes/crab.tres")
const MATERIAL = preload("res://data/items/consumables/wooden_arrow.tres")
var test_save := "res://_note_progress_test_%d.save" % Time.get_ticks_usec()
var failures := 0
var popup_count := 0

class TestPlayer extends Player:
	func _ready() -> void:
		pass
	func _exit_tree() -> void:
		pass
	func _physics_process(_delta: float) -> void:
		pass
	func is_gameplay_input_blocked() -> bool:
		return false


func _initialize() -> void:
	call_deferred("run_tests")


func check(value: bool, description: String) -> void:
	if not value:
		failures += 1
		push_error(description)


func on_pickup(item: BaseItem, amount: int) -> void:
	if item != null and item.item_id == "note" and amount == 1:
		popup_count += 1


func run_tests() -> void:
	var store = root.get_node("NoteProgress")
	var previous_path: String = store.save_path
	var previous_states: Dictionary = store._states.duplicate()
	store.save_path = test_save
	store._states.clear()
	var holder := Node3D.new()
	root.add_child(holder)
	var chest = CHEST_SCENE.instantiate()
	holder.add_child(chest)
	var item_drop := ChestItemDrop.new()
	item_drop.item = MATERIAL
	item_drop.quantity = 3
	var note_drop := ChestNoteDrop.new()
	note_drop.note = NOTE
	var never_drop := ChestItemDrop.new()
	never_drop.item = MATERIAL
	never_drop.chance = 0.0
	chest.item_drops.append(item_drop)
	chest.item_drops.append(never_drop)
	chest.note_drops.append(note_drop)
	chest.gold_min = 0
	chest.gold_max = 0
	var attack := DamageContext.new()
	attack.source_team = CombatTeams.PLAYER
	attack.amount_hp = 100.0
	chest.receive_damage(attack)
	chest.receive_damage(attack)
	var spawned: Array[ItemPickup] = []
	for node in holder.get_children():
		if node is ItemPickup:
			spawned.append(node)
	check(spawned.size() == 2, "chest opens once and creates one item pickup and one note pickup")
	var note_pickup: ItemPickup
	for pickup in spawned:
		if pickup.note != null:
			note_pickup = pickup
		else:
			check(pickup.item == MATERIAL and pickup.quantity == 3, "item quantity is preserved")
	check(note_pickup != null and note_pickup.note == NOTE, "note resource is preserved")
	var player := TestPlayer.new()
	var visual := PlayerVisual.new()
	visual.name = "Visual"
	visual.process_mode = Node.PROCESS_MODE_DISABLED
	player.add_child(visual)
	var fsm := Fsm.new()
	fsm.name = "FSM"
	player.add_child(fsm)
	var inventory := Inventory.new()
	inventory.name = "Inventory"
	player.add_child(inventory)
	holder.add_child(player)
	await process_frame
	# Fill every slot to verify the note does not require space.
	for slot in inventory.slots:
		slot.item = MATERIAL
		slot.quantity = MATERIAL.max_stack
	inventory.item_picked_up.connect(on_pickup)
	note_pickup._finish_drop_animation()
	check(note_pickup._can_attract(player), "note is collectible with a full inventory")
	note_pickup._attraction._awaiting_commit = true
	note_pickup._collect(player)
	check(store.is_unlocked(NOTE), "collecting note unlocks its linked entry")
	check(inventory.count_item(&"note") == 0, "note does not occupy inventory")
	check(popup_count == 1, "note emits the normal item pickup signal")
	var duplicate := preload("res://gameplay/inventory/item_pickup.tscn").instantiate() as ItemPickup
	duplicate.note = NOTE
	holder.add_child(duplicate)
	duplicate._attraction._awaiting_commit = true
	duplicate._collect(player)
	check(popup_count == 2 and inventory.count_item(&"note") == 0, "duplicate note still shows popup without a slot")
	check(store.load_progress() and store.is_unlocked(NOTE), "unlock survives reload")
	var tab = load("res://gameplay/inventory/notes_tab.tscn").instantiate()
	root.add_child(tab)
	await process_frame
	check(tab.is_note_unlocked(NOTE), "notes UI reads saved state")
	tab.queue_free()
	holder.queue_free()
	store.save_path = previous_path
	store._states = previous_states
	if FileAccess.file_exists(test_save):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save))
	print("Chest and note tests: ", "passed" if failures == 0 else "failed")
	quit(0 if failures == 0 else 1)
