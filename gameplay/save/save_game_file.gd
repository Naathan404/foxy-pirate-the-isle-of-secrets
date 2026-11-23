class_name SaveGameFile
extends RefCounted
## One JSON save slot under user://. A write goes to a temporary file, is read back and
## checked, and only then replaces the slot, so a failed or interrupted write never
## destroys the previous good save.

const TEMP_SUFFIX := ".tmp"
const JSON_INDENT := "\t"

## Absolute user:// path of the slot. Tests point this at their own directory.
var path: String


func _init(slot_path: String) -> void:
	path = slot_path


## Reads and validates the slot. A valid temporary file left by an interrupted replace is
## promoted first, because the slot itself was already removed at that point.
func read() -> ReadResult:
	_recover_interrupted_write()
	if not FileAccess.file_exists(path):
		return ReadResult.failed(ERR_FILE_NOT_FOUND, "No saved game.")
	return _read_file(path)


func exists() -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(_temp_path())


## The payload must already be validated by the caller. Returns OK only after the slot on
## disk holds exactly this payload.
func write(payload: Dictionary) -> Error:
	if payload.is_empty():
		return ERR_INVALID_DATA
	var text := JSON.stringify(payload, JSON_INDENT)
	var directory := path.get_base_dir()
	var dir_error := DirAccess.make_dir_recursive_absolute(directory)
	if dir_error != OK:
		return dir_error

	var temp_path := _temp_path()
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var stored := file.store_string(text)
	var write_error := file.get_error()
	file.close()
	if not stored or write_error != OK:
		DirAccess.remove_absolute(temp_path)
		return write_error if write_error != OK else ERR_FILE_CANT_WRITE

	var check := _read_file(temp_path)
	if check.error != OK or check.text != text:
		DirAccess.remove_absolute(temp_path)
		return ERR_FILE_CORRUPT
	# Godot replaces an existing target on rename. If the process dies between removing
	# the old slot and renaming, read() promotes the verified temporary file.
	return DirAccess.rename_absolute(temp_path, path)


func delete() -> Error:
	for file_path: String in [path, _temp_path()]:
		if FileAccess.file_exists(file_path):
			var error := DirAccess.remove_absolute(file_path)
			if error != OK:
				return error
	return OK


func _temp_path() -> String:
	return path + TEMP_SUFFIX


func _recover_interrupted_write() -> void:
	var temp_path := _temp_path()
	if FileAccess.file_exists(path) or not FileAccess.file_exists(temp_path):
		return
	if _read_file(temp_path).error == OK:
		DirAccess.rename_absolute(temp_path, path)


func _read_file(file_path: String) -> ReadResult:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return ReadResult.failed(FileAccess.get_open_error(), "The save file cannot be opened.")
	var text := file.get_as_text()
	var read_error := file.get_error()
	file.close()
	if read_error != OK and read_error != ERR_FILE_EOF:
		return ReadResult.failed(read_error, "The save file cannot be read.")
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return ReadResult.failed(ERR_PARSE_ERROR, "The save file is damaged.")
	var payload := json.data as Dictionary
	var problem := GameSaveSnapshot.validate(payload)
	if not problem.is_empty():
		var error := (
			ERR_FILE_UNRECOGNIZED
			if GameSaveSnapshot.is_unsupported_version(payload)
			else ERR_INVALID_DATA
		)
		return ReadResult.failed(error, problem)
	var result := ReadResult.new()
	result.payload = payload
	result.text = text
	return result


## Outcome of reading a slot; `message` is shown to the player when `error` is not OK.
class ReadResult:
	extends RefCounted

	var error: Error = OK
	var message: String = ""
	var payload: Dictionary = {}
	var text: String = ""

	static func failed(read_error: Error, read_message: String) -> ReadResult:
		var result := ReadResult.new()
		result.error = read_error
		result.message = read_message
		return result

	## One line for the Continue button area, e.g. "Slot 1 · room_00 · 2026-11-23 14:05".
	func describe() -> String:
		if error == ERR_FILE_NOT_FOUND:
			return "No saved game. Rest at a campfire in a safe room to save."
		if error != OK:
			return "Slot 1 cannot be loaded: %s" % message
		return "Slot 1 · %s · %s" % [_room_name(), _local_time()]

	## Tells the player which save a campfire Save will replace.
	func describe_for_overwrite() -> String:
		if error == ERR_FILE_NOT_FOUND:
			return "Saving will use the empty Slot 1."
		if error != OK:
			return "Saving will replace the unreadable save in Slot 1."
		return "Saving will overwrite Slot 1 (%s, %s)." % [_room_name(), _local_time()]

	func _room_name() -> String:
		return String(payload.location.scene).get_file().get_basename()

	func _local_time() -> String:
		var bias_seconds := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
		var local := Time.get_datetime_dict_from_unix_time(
			int(payload.saved_at_unix) + bias_seconds
		)
		return (
			"%04d-%02d-%02d %02d:%02d"
			% [local.year, local.month, local.day, local.hour, local.minute]
		)
