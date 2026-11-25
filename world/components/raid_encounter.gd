class_name RaidEncounter
extends Node3D
## Four finite tide waves. Unlock only after all requested spawns and enemies are cleared.

signal wave_started(number: int)
signal raid_cleared

@export var encounter_id: StringName = &"coral_valley_raid_07_cleared"
@export var controller: FlatTideController
@export var spawner: RaidEnemySpawner
@export var activation_area: Area3D
@export var room: BaseRoom
@export var reward_chest_scene: PackedScene
## Spawn position in room-local coordinates.
@export var reward_position := Vector3.ZERO
@export var first_wave_enemies: Array[FlatTideEnemyEntry] = []
@export var later_wave_enemies: Array[FlatTideEnemyEntry] = []
@export var wave_counts: Array[int] = [3, 4, 4, 5]
@export var wave_elites: Array[int] = [0, 0, 1, 2]

var _wave_index := -1
var _active := false
var _spawn_complete := false
var _advancing := false
var _living: Dictionary[int, EnemyBase] = {}
var _reward_chest: TreasureChest


func _ready() -> void:
	if (
		controller == null
		or room == null
		or spawner == null
		or activation_area == null
		or not controller.externally_advanced
		or not controller.sequential_zones
		or wave_counts.is_empty()
		or wave_counts.size() != wave_elites.size()
		or controller.zones.size() != wave_counts.size()
	):
		push_error("RaidEncounter: assign controller, spawner, area and matching wave arrays.")
		return
	for index in wave_counts.size():
		if (
			wave_counts[index] <= 0
			or wave_elites[index] < 0
			or wave_elites[index] > wave_counts[index]
		):
			push_error("RaidEncounter: invalid wave or elite count.")
			return
	room.set_exits_locked(false)
	if get_node("/root/GameManager").story_flags.get(encounter_id, false):
		_spawn_reward.call_deferred()
		return
	activation_area.body_entered.connect(_on_body_entered)
	spawner.enemy_spawned.connect(_on_enemy_spawned)
	spawner.wave_spawn_finished.connect(_on_spawn_finished)
	controller.state_changed.connect(_on_tide_state_changed)


func _on_body_entered(body: Node3D) -> void:
	if _active or not body is Player or (body as Player).dead:
		return
	_active = true
	_start_raid.call_deferred()


func _start_raid() -> void:
	room.set_exits_locked(true)
	_begin_next_wave()


func _begin_next_wave() -> void:
	_wave_index += 1
	_spawn_complete = false
	_advancing = false
	spawner.enemies_per_tide = wave_counts[_wave_index]
	spawner.elite_count = wave_elites[_wave_index]
	spawner.enemies = first_wave_enemies if _wave_index == 0 else later_wave_enemies
	if not controller.request_cycle():
		push_error("RaidEncounter: tide rejected the next wave.")
		return
	wave_started.emit(_wave_index + 1)


func _on_enemy_spawned(enemy: EnemyBase, _is_elite: bool) -> void:
	var id := enemy.get_instance_id()
	_living[id] = enemy
	enemy.died.connect(_on_enemy_removed.bind(id), CONNECT_ONE_SHOT)
	enemy.tree_exiting.connect(_on_enemy_removed.bind(id), CONNECT_ONE_SHOT)


func _on_enemy_removed(id: int) -> void:
	_living.erase(id)
	_try_advance.call_deferred()


func _on_spawn_finished() -> void:
	_spawn_complete = true
	_try_advance.call_deferred()


func _on_tide_state_changed(_state: FlatTideController.State) -> void:
	_try_advance.call_deferred()


func _try_advance() -> void:
	if not _active or _advancing or not _spawn_complete or not _living.is_empty():
		return
	_advancing = true
	controller.finish_cycle()
	if _wave_index + 1 >= wave_counts.size():
		_active = false
		get_node("/root/GameManager").story_flags[encounter_id] = true
		room.set_exits_locked(false)
		activation_area.set_deferred("monitoring", false)
		_spawn_reward()
		raid_cleared.emit()
		return
	_begin_next_wave()


func _spawn_reward() -> void:
	if is_instance_valid(_reward_chest) or reward_chest_scene == null:
		return
	var instance := reward_chest_scene.instantiate()
	_reward_chest = instance as TreasureChest
	if _reward_chest == null:
		instance.free()
		push_error("RaidEncounter: reward scene must have a TreasureChest root.")
		return
	_reward_chest.position = reward_position
	room.add_child(_reward_chest)
	# Spawned after the room was built, so it registers itself; once opened it stays open.
	room.track_object(_reward_chest)
