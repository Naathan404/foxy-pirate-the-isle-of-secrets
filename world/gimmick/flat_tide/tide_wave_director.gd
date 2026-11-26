class_name TideWaveDirector
extends Node
## Scripted enemy waves carried in by the tide. Each time a tide has fully receded, the next
## planned `RaidWave` climbs out of the wet sand, so the water visibly brings the enemies.
## A wave only comes once the previous one is defeated, and a wave tied to a zone waits for
## that zone's tide (its spawn points lie in the sand that zone uncovers).
##
## After the last wave the tide keeps running without enemies until the next rest: the room
## records that its waves are done for the current world cycle.

signal wave_started(number: int)
signal waves_finished

## Key of this director's record in the room state.
const STATE_KEY_SUFFIX := ":waves_done"

@export var controller: FlatTideController
@export var spawner: RaidGroundSpawner
@export var waves: Array[RaidWave] = []
## Optional, one per wave: the zone whose receding tide brings that wave. Empty means any.
@export var wave_zones: Array[FlatTideZone] = []

var _wave_index: int = -1
var _previous_state: FlatTideController.State = FlatTideController.State.LOW
var _spawning: bool = false
var _living: Dictionary[int, EnemyBase] = {}


func _ready() -> void:
	if controller == null or spawner == null or waves.is_empty() or waves.has(null):
		push_error("TideWaveDirector: assign the controller, spawner and at least one wave.")
		return
	if not wave_zones.is_empty() and wave_zones.size() != waves.size():
		push_error("TideWaveDirector: give one zone per wave, or none.")
		return
	if _is_done():
		return
	_previous_state = controller.state
	controller.state_changed.connect(_on_tide_state_changed)
	spawner.enemy_spawned.connect(_on_enemy_spawned)
	spawner.wave_spawn_finished.connect(_on_wave_spawn_finished)


func _on_tide_state_changed(state: FlatTideController.State) -> void:
	var receded := (
		state == FlatTideController.State.LOW
		and _previous_state == FlatTideController.State.FALLING
	)
	_previous_state = state
	if receded and _can_start_next(controller.get_active_zone()):
		_start_next_wave()


func _can_start_next(receded_zone: FlatTideZone) -> bool:
	var next_index := _wave_index + 1
	if _spawning or not _living.is_empty() or next_index >= waves.size():
		return false
	return wave_zones.is_empty() or wave_zones[next_index] == receded_zone


func _start_next_wave() -> void:
	_wave_index += 1
	_spawning = spawner.spawn_wave(waves[_wave_index])
	if _spawning:
		wave_started.emit(_wave_index + 1)


func _on_enemy_spawned(enemy: EnemyBase, _is_elite: bool) -> void:
	var id := enemy.get_instance_id()
	_living[id] = enemy
	# A fall into the void frees the enemy without dying; both count as gone.
	enemy.died.connect(_on_enemy_removed.bind(id), CONNECT_ONE_SHOT)
	enemy.tree_exiting.connect(_on_enemy_removed.bind(id), CONNECT_ONE_SHOT)


func _on_wave_spawn_finished() -> void:
	_spawning = false
	_check_finished.call_deferred()


func _on_enemy_removed(id: int) -> void:
	_living.erase(id)
	_check_finished.call_deferred()


func _check_finished() -> void:
	# Leaving the room frees every enemy; that is not a defeated wave.
	if not is_inside_tree() or _spawning or not _living.is_empty():
		return
	if _wave_index + 1 < waves.size():
		return
	_record_done()
	waves_finished.emit()


func _is_done() -> bool:
	var room := BaseRoom.find_room(self)
	if room == null or room.scene_file_path.is_empty():
		return false
	var registry: RoomStateRegistry = get_node("/root/GameManager").room_states
	return registry.is_cleared(room.scene_file_path, _state_key(room))


func _record_done() -> void:
	var room := BaseRoom.find_room(self)
	if room == null or room.scene_file_path.is_empty():
		return
	var registry: RoomStateRegistry = get_node("/root/GameManager").room_states
	registry.mark_cleared(room.scene_file_path, _state_key(room), registry.cycle)


func _state_key(room: BaseRoom) -> String:
	return String(room.get_path_to(self)) + STATE_KEY_SUFFIX
