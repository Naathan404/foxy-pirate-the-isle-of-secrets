extends SceneTree

const ENEMY_SCENE := preload("res://gameplay/enemies/war_lord_turtle/war_lord_turtle.tscn")
const PICKUP_SCENE := preload("res://gameplay/inventory/item_pickup.tscn")
const DIARY := preload("res://data/items/quest/boss_diary.tres")
const MONSTER_NOTE := preload("res://data/notes/crab.tres")
const MATERIAL := preload("res://data/items/materials/skeleton_bone.tres")

var failures := 0
var popup_item: BaseItem
var popup_count := 0


class TestPlayer:
	extends Player
	func _ready() -> void:
		pass
	func _exit_tree() -> void:
		pass
	func _physics_process(_delta: float) -> void:
		pass
	func is_gameplay_input_blocked() -> bool:
		return false


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func _on_pickup(item: BaseItem, _amount: int) -> void:
	popup_item = item
	popup_count += 1


func run() -> void:
	var store = root.get_node("NoteProgress")
	var old_path: String = store.save_path
	var old_states: Dictionary = store._states.duplicate()
	var test_path := "res://_boss_diary_test_%d.save" % Time.get_ticks_usec()
	store.save_path = test_path
	store._states.clear()
	var world := Node3D.new()
	root.add_child(world)
	var note := MonsterNote.new()
	note.note_id = &"test_boss_diary"
	note.layout = MonsterNote.Layout.BOSS
	note.story = "A story about the boss."
	var enemy := ENEMY_SCENE.instantiate() as EnemyBase
	enemy.note_drop = note
	world.add_child(enemy)
	enemy.die()
	enemy.die()
	await process_frame
	var pickups: Array[ItemPickup] = []
	for child in world.get_children():
		if child is ItemPickup and child.note == note:
			pickups.append(child)
	check(pickups.size() == 1, "Boss defeat drops one diary")
	if pickups.size() == 1:
		var pickup := pickups[0]
		check(pickup.item == DIARY and pickup.sprite.texture == DIARY.icon, "Boss icon selected")
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
		world.add_child(player)
		for slot in inventory.slots:
			slot.item = MATERIAL
			slot.quantity = MATERIAL.max_stack
		inventory.item_picked_up.connect(_on_pickup)
		pickup._finish_drop_animation()
		check(pickup._can_attract(player), "Diary can be collected with full inventory")
		pickup._attraction._awaiting_commit = true
		pickup._collect(player)
		check(store.is_unlocked(note), "Collecting diary unlocks the linked boss")
		check(popup_count == 1 and popup_item == DIARY, "Pickup popup uses boss diary")
		check(inventory.count_item(&"boss_diary") == 0, "Diary does not use an inventory slot")
	var ordinary := PICKUP_SCENE.instantiate()
	ordinary.note = MONSTER_NOTE
	world.add_child(ordinary)
	check(ordinary.item == ItemPickup.NOTE_ITEM, "Monster entries keep their normal icon")
	var notes_tab = load("res://gameplay/inventory/notes_tab.tscn").instantiate()
	root.add_child(notes_tab)
	for region in ["ember", "tide", "flora", "gale"]:
		var diary_note := load("res://data/notes/diary_%s.tres" % region) as MonsterNote
		var diary := load("res://data/items/quest/diary_%s.tres" % region) as BaseItem
		check(diary_note != null and diary != null, "Regional diary resources load")
		check(not diary_note.unlocked and diary_note.layout == MonsterNote.Layout.BOSS, "Diary locked")
		check(notes_tab.notes.has(diary_note), "Diary is listed in the notes tab")
		var regional = PICKUP_SCENE.instantiate()
		regional.note = diary_note
		world.add_child(regional)
		check(regional.item == diary and regional.sprite.texture == DIARY.icon, "Regional pickup")
		check(diary.opens_note and diary.max_stack == 1, "Diary is a note item")
		check(store.set_unlocked(diary_note.note_id, true), "Diary unlocks its own entry")
		for other in ["ember", "tide", "flora", "gale"]:
			if other != region and not store._states.has("diary_" + other):
				var other_note := load("res://data/notes/diary_%s.tres" % other) as MonsterNote
				check(not store.is_unlocked(other_note), "Other entries stay locked")
	notes_tab.queue_free()
	world.queue_free()
	store.save_path = old_path
	store._states = old_states
	if FileAccess.file_exists(test_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	await process_frame
	print("Boss diary: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
