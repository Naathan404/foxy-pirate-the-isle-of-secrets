class_name BossEncounter
extends Node
## Persist a defeated boss and its uncollected chest items across room transitions.

const ITEM_PICKUP := preload("res://gameplay/inventory/item_pickup.tscn")

@export var encounter_id: StringName
@export var boss: BossBase
## Optional boundary lock for rooms using the shared BaseRoom implementation.
@export var room: BaseRoom
@export var activation_area: Area3D

var _state: Dictionary
var _tracked: Dictionary[int, ItemPickup] = {}
var _room: Node3D
var _reward_scene: PackedScene


func _ready() -> void:
	_room = get_parent() as Node3D
	if encounter_id.is_empty() or not is_instance_valid(boss) or _room == null:
		push_error("BossEncounter requires an ID, boss and Node3D room")
		return
	if room != null:
		if activation_area == null:
			push_error("BossEncounter: a boundary-locked room requires an activation area.")
			return
		room.set_exits_locked(false)
	var manager := get_node("/root/GameManager")
	if not manager.boss_encounters.has(encounter_id):
		manager.boss_encounters[encounter_id] = {"defeated": false, "opened": false, "items": {}}
	_state = manager.boss_encounters[encounter_id]
	if bool(_state.defeated):
		_reward_scene = boss.reward_chest
		_restore_reward.call_deferred()
		boss.queue_free()
		return
	boss.fight_finished.connect(_on_boss_defeated)
	boss.reward_spawned.connect(_on_reward_spawned)
	if room != null:
		activation_area.body_entered.connect(_on_player_entered)


func _exit_tree() -> void:
	for index: int in _tracked.keys():
		_save_pickup(index)


func _on_player_entered(body: Node3D) -> void:
	if not body is Player or (body as Player).dead:
		return
	if not is_instance_valid(boss) or boss.dead or boss.is_queued_for_deletion():
		return
	room.set_exits_locked(true)
	boss.start_fight(body)


func _on_boss_defeated() -> void:
	_state.defeated = true
	_state.position = _room.to_local(boss.global_position)
	if room != null:
		room.set_exits_locked(false)
		activation_area.set_deferred("monitoring", false)


func _on_reward_spawned(node: Node3D) -> void:
	var chest := node as BossRewardChest
	if chest == null:
		return
	chest.reward_pickup_spawned.connect(_track_pickup)
	chest.destroyed.connect(func(): _state.opened = true)


func _track_pickup(index: int, pickup: ItemPickup) -> void:
	_tracked[index] = pickup
	_save_pickup(index)
	pickup.tree_exiting.connect(_save_pickup.bind(index))


func _save_pickup(index: int) -> void:
s	var pickup := _tracked.get(index) as ItemPickup
	if not is_instance_valid(pickup) or _state.is_empty():
		return
	var items: Dictionary = _state.items
	if pickup.quantity <= 0:
		items.erase(index)
	else:
		items[index] = {
			"item": pickup.item,
			"note": pickup.note,
			"quantity": pickup.quantity,
			"position": pickup.position,
		}


func _restore_reward() -> void:
	if _reward_scene == null or not is_inside_tree():
		return
	var chest := _reward_scene.instantiate() as BossRewardChest
	if chest == null:
		return
	_room.add_child(chest)
	chest.position = _state.position
	_on_reward_spawned(chest)
	if not bool(_state.opened):
		return
	chest.restore_opened()
	var items: Dictionary = _state.items.duplicate()
	for index: int in items:
		var entry: Dictionary = items[index]
		var pickup := ITEM_PICKUP.instantiate() as ItemPickup
		pickup.item = entry.item
		pickup.note = entry.get("note") as MonsterNote
		pickup.quantity = entry.quantity
		_room.add_child(pickup)
		pickup.position = entry.position
		if pickup.is_special_reward():
			pickup.show_highlight()
		_track_pickup(index, pickup)
