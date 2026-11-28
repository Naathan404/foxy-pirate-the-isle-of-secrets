extends Node
## Unlocked monster notes. Its own file keeps the latest state between launches; the game
## save slot is the authority on New Game (reset) and Continue (restore).
signal changed(note_id: StringName)
## An entry was learned during play. Restoring a save never emits this.
signal discovered(note: MonsterNote)

const SAVE_VERSION := 1
## Note IDs that were renamed, so older saves keep their unlocked notes.
const RENAMED_NOTE_IDS: Dictionary[String, String] = {
	"starfish": "hermit_crab",
	"elite_starfish": "elite_hermit_crab",
}
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


## Unlocks an entry the player has just earned. Returns true only the first time.
func discover(note: MonsterNote) -> bool:
	if note == null or note.note_id.is_empty() or is_unlocked(note):
		return false
	set_unlocked(note.note_id, true)
	discovered.emit(note)
	return true


func get_save_data() -> Dictionary:
	return {"unlocked": _states.duplicate()}


## Expects data already checked by GameSaveSnapshot.
func apply_save_data(saved: Dictionary) -> bool:
	var previous := _states.duplicate()
	_states.clear()
	var unlocked: Dictionary = saved.get("unlocked", {})
	for key: Variant in unlocked:
		if key is String and not String(key).is_empty() and unlocked[key] is bool:
			_store_loaded_state(key, unlocked[key])
	for key: String in _merged_keys(previous, _states):
		if previous.get(key) != _states.get(key):
			changed.emit(StringName(key))
	return save_progress()


func reset_progress() -> bool:
	return apply_save_data({})


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
			_store_loaded_state(key, payload.states[key])
	return true


func save_progress() -> bool:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("NoteProgress: could not save progress; unlock remains active this session")
		return false
	file.store_var({"version": SAVE_VERSION, "states": _states}, false)
	return true


## An entry already stored under the new ID wins over one under its old ID.
func _store_loaded_state(key: String, unlocked: bool) -> void:
	if not RENAMED_NOTE_IDS.has(key):
		_states[key] = unlocked
		return
	var renamed := RENAMED_NOTE_IDS[key]
	if not _states.has(renamed):
		_states[renamed] = unlocked


func _merged_keys(first: Dictionary, second: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for key: Variant in first.keys() + second.keys():
		if not keys.has(String(key)):
			keys.append(String(key))
	return keys
