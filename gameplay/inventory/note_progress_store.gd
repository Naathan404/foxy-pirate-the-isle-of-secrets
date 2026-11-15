extends Node
## Standalone persistence until a game-wide save system is available.
signal changed(note_id: StringName)

const SAVE_VERSION := 1
@export var save_path: String = "user://monster_notes.save"
var _states: Dictionary = {}


func _ready() -> void:
	load_progress()


func is_unlocked(note: MonsterNote) -> bool:
	return note != null and bool(_states.get(String(note.note_id), note.unlocked))


func set_unlocked(note_id: StringName, unlocked: bool) -> bool:
	if note_id.is_empty():
		return false
	var key := String(note_id)
	if _states.has(key) and bool(_states[key]) == unlocked:
		return true
	_states[key] = unlocked
	changed.emit(note_id)
	return save_progress()


func load_progress() -> bool:
	_states.clear()
	if not FileAccess.file_exists(save_path):
		return true
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_warning("NoteProgress: could not read save")
		return false
	var payload: Variant = file.get_var(false)
	if not payload is Dictionary or not payload.get("states", null) is Dictionary:
		push_warning("NoteProgress: invalid save")
		return false
	for key in payload.states:
		if key is String and not key.is_empty() and payload.states[key] is bool:
			_states[key] = payload.states[key]
	return true


func save_progress() -> bool:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("NoteProgress: could not save progress; unlock remains active this session")
		return false
	file.store_var({"version": SAVE_VERSION, "states": _states}, false)
	return true
