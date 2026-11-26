class_name ExitSeal
extends Node3D
## Keeps one exit of its room shut until something opens it, then remembers that for the run
## through a story flag (saved with the run, reset by New Game).
##
## While sealed the exit's transition is off and the island boundary closes across its path.
## Boulders (`gate`) can stand on the path, or the path can stay hidden so the exit looks like
## plain shore. Breaking `breakable` opens it: a cracked wall in front of a secret passage.
## Subclasses open it on their own terms (see `TidePearlGate`).

signal opened

enum Exit { UP = 1, RIGHT = 2, DOWN = 4, LEFT = 8 }

@export var room: BaseRoom
@export var exit: Exit = Exit.RIGHT
## Story flag kept once the exit is open, e.g. `coral_valley_pearl_gate_open`.
@export var open_flag: StringName = &""
## Draw no path while sealed, so the exit is a secret until it opens.
@export var hide_path_while_sealed: bool = false
## Boulders standing on the path while the exit is sealed.
@export var gate: RaidBoulderGate
## Optional: destroying this prop opens the exit.
@export var breakable: DestructibleProp


func _ready() -> void:
	if room == null or open_flag.is_empty():
		push_error("ExitSeal: assign the room and an open flag.")
		return
	if is_open():
		if is_instance_valid(breakable):
			# The wall would come back after a rest, but the passage stays open for the run.
			breakable.queue_free()
		return
	room.set_exit_sealed(exit, true, hide_path_while_sealed)
	if gate != null:
		gate.set_closed_immediately()
	if is_instance_valid(breakable):
		breakable.destroyed.connect(open, CONNECT_ONE_SHOT)


func is_open() -> bool:
	return get_node("/root/GameManager").has_story_flag(open_flag)


## Opens the exit for the rest of the run. Does nothing when it is already open.
func open() -> void:
	if is_open():
		return
	get_node("/root/GameManager").set_story_flag(open_flag)
	room.set_exit_sealed(exit, false)
	if gate != null:
		gate.lower()
	opened.emit()
