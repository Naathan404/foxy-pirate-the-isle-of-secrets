class_name RaidLockdown
extends Node
## Room rules of a raid. While any stage with `locks_room` is fighting, the room exits are
## locked and every gate is raised; when it is cleared they open again. Once every stage is
## cleared, the optional reward chest appears. Progress lives in the stages, so re-entering
## a room restores exactly what was earned.

## Emitted once every stage of the room is cleared (not on re-entering a cleared room).
signal raid_cleared

@export var room: BaseRoom
@export var stages: Array[RaidStage] = []
## Gates raised while a locking stage fights; usually one per open exit.
@export var gates: Array[RaidBoulderGate] = []
## Optional. Spawned once every stage is cleared; must have a `TreasureChest` root.
@export var reward_chest_scene: PackedScene
## Spawn position of the reward chest in room-local coordinates.
@export var reward_position: Vector3 = Vector3.ZERO

var _locking_stages: Dictionary[RaidStage, bool] = {}
var _reward_chest: TreasureChest


func _ready() -> void:
	if room == null or stages.is_empty() or stages.has(null) or gates.has(null):
		push_error("RaidLockdown: assign the room and at least one stage; no empty gate slots.")
		return
	for stage in stages:
		stage.started.connect(_on_stage_started.bind(stage))
		stage.cleared.connect(_on_stage_cleared.bind(stage))
	if is_cleared():
		_spawn_reward.call_deferred()


func _on_stage_started(stage: RaidStage) -> void:
	if not stage.locks_room:
		return
	if _locking_stages.is_empty():
		room.set_exits_locked(true)
		for gate in gates:
			gate.raise()
	_locking_stages[stage] = true


func _on_stage_cleared(stage: RaidStage) -> void:
	if _locking_stages.erase(stage) and _locking_stages.is_empty():
		room.set_exits_locked(false)
		for gate in gates:
			gate.lower()
	if is_cleared():
		_spawn_reward()
		raid_cleared.emit()


## True once every stage of the room has been cleared in this run.
func is_cleared() -> bool:
	for stage in stages:
		if not stage.is_cleared():
			return false
	return true


func _spawn_reward() -> void:
	if reward_chest_scene == null or is_instance_valid(_reward_chest):
		return
	var instance := reward_chest_scene.instantiate()
	_reward_chest = instance as TreasureChest
	if _reward_chest == null:
		instance.free()
		push_error("RaidLockdown: reward scene must have a TreasureChest root.")
		return
	_reward_chest.position = reward_position
	room.add_child(_reward_chest)
	# Added after the room was built, so it registers itself; once opened it stays open.
	room.track_object(_reward_chest)
