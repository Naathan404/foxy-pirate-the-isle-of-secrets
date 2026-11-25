class_name RaidStage
extends Node3D
## One island of an island raid. Starts when Foxy steps into the activation area, plays its
## scripted waves out of the ground one after another, and reports when the last enemy is
## gone. Completion is kept in `GameManager.story_flags` for the run, so a cleared island
## never fights again; dying mid-fight restarts the island from its first wave.

signal started
signal wave_started(number: int)
signal cleared

## Story flag set when this stage is cleared. Unique per stage, e.g.
## `coral_valley_room_18_west_cleared`.
@export var stage_id: StringName = &""
## While this stage fights, `RaidLockdown` locks the room exits and raises its gates. Turn
## off for a stage that is only reachable from inside an already cleared area.
@export var locks_room: bool = true
@export var activation_area: Area3D
@export var spawner: RaidGroundSpawner
## Played in order; each starts once the previous one is fully defeated.
@export var waves: Array[RaidWave] = []
@export_range(0.0, 5.0, 0.1, "suffix:s") var wave_pause_seconds: float = 1.0
## How long Foxy must stay inside the activation area before the fight starts. Arriving
## in a room spawns Foxy at the origin for a moment before moving them to the door, so
## a plain enter signal would start the raid while Foxy is still on the pier.
@export_range(0.0, 2.0, 0.05, "suffix:s") var activation_dwell_seconds: float = 0.25

var _active: bool = false
var _dwell_elapsed_seconds: float = 0.0
var _wave_index: int = -1
var _spawn_complete: bool = false
var _advancing: bool = false
var _living: Dictionary[int, EnemyBase] = {}


func _ready() -> void:
	set_physics_process(false)
	if not _is_configured():
		return
	if is_cleared():
		activation_area.set_deferred("monitoring", false)
		return
	spawner.enemy_spawned.connect(_on_enemy_spawned)
	spawner.wave_spawn_finished.connect(_on_spawn_finished)
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	var player := get_node("/root/GameManager").player as Player
	if not is_instance_valid(player) or player.dead or not activation_area.overlaps_body(player):
		_dwell_elapsed_seconds = 0.0
		return
	_dwell_elapsed_seconds += delta
	if _dwell_elapsed_seconds >= activation_dwell_seconds:
		_start()


func is_cleared() -> bool:
	return get_node("/root/GameManager").story_flags.get(stage_id, false)


func _is_configured() -> bool:
	if (
		stage_id.is_empty()
		or activation_area == null
		or spawner == null
		or waves.is_empty()
		or waves.has(null)
	):
		push_error("RaidStage: assign an id, area, spawner and at least one wave.")
		return false
	return true


func _start() -> void:
	set_physics_process(false)
	_active = true
	started.emit()
	_begin_next_wave()


func _begin_next_wave() -> void:
	_wave_index += 1
	_spawn_complete = false
	_advancing = false
	if not spawner.spawn_wave(waves[_wave_index]):
		return
	wave_started.emit(_wave_index + 1)


func _on_enemy_spawned(enemy: EnemyBase, _is_elite: bool) -> void:
	var id := enemy.get_instance_id()
	_living[id] = enemy
	# A fall into the void frees the enemy without dying; both count as gone.
	enemy.died.connect(_on_enemy_removed.bind(id), CONNECT_ONE_SHOT)
	enemy.tree_exiting.connect(_on_enemy_removed.bind(id), CONNECT_ONE_SHOT)


func _on_enemy_removed(id: int) -> void:
	_living.erase(id)
	_try_advance.call_deferred()


func _on_spawn_finished() -> void:
	_spawn_complete = true
	_try_advance.call_deferred()


func _try_advance() -> void:
	# Leaving the room (death, exit) frees every enemy; that is not a cleared wave.
	if not is_inside_tree():
		return
	if not _active or _advancing or not _spawn_complete or not _living.is_empty():
		return
	_advancing = true
	if _wave_index + 1 < waves.size():
		# A tween bound to this node pauses with the game and is dropped with the room.
		await create_tween().tween_interval(wave_pause_seconds).finished
		_begin_next_wave()
		return
	_active = false
	get_node("/root/GameManager").story_flags[stage_id] = true
	activation_area.set_deferred("monitoring", false)
	cleared.emit()
