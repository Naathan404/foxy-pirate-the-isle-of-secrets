class_name IslandRaidConductor
extends Node
## Shuttle levers of a two-island raid: clearing an island raises its shore lever. Exits,
## gates and the reward chest are handled by the room's `RaidLockdown`. Progress is read
## back from the stages, so re-entering the room restores the earned levers.

@export var entry_stage: RaidStage
@export var far_stage: RaidStage
@export var entry_lever: ShuttleCallLever
@export var far_lever: ShuttleCallLever


func _ready() -> void:
	if entry_stage == null or far_stage == null or entry_lever == null or far_lever == null:
		push_error("IslandRaidConductor: assign both stages and both levers.")
		return
	entry_stage.cleared.connect(entry_lever.reveal)
	far_stage.cleared.connect(far_lever.reveal)
	# The levers bury themselves in their own _ready, so restore after the room is built.
	_restore_progress.call_deferred()


func _restore_progress() -> void:
	if entry_stage.is_cleared():
		entry_lever.reveal_immediately()
	if far_stage.is_cleared():
		far_lever.reveal_immediately()
