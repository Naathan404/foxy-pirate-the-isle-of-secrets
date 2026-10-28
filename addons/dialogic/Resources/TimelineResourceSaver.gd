@tool
class_name DialogicTimelineFormatSaver
extends ResourceFormatSaver


func _get_recognized_extensions(_resource: Resource) -> PackedStringArray:
	return PackedStringArray(["dtl"])


## Return true if this resource should be loaded as a DialogicTimeline
func _recognize(resource: Resource) -> bool:
	# Cast instead of using "is" keyword in case is a subclass
	resource = resource as DialogicTimeline

	if resource:
		return true

	return false


## Save the resource
func _save(resource: Resource, path: String = '', _flags: int = 0) -> Error:
	# A new resource (including one created in the Inspector) has no dirty flag.
	# Only skip writing a clean timeline that already exists at its own path.
	if resource.get_meta("timeline_not_saved", false) or not FileAccess.file_exists(path) or path != resource.resource_path:
		var timeline_as_text: String = resource.as_text()

		var file := FileAccess.open(path, FileAccess.WRITE)
		if not file:
			var error := FileAccess.get_open_error()
			push_error('[Dialogic] Cannot save timeline "%s": %s' % [path, error_string(error)])
			return error
		file.store_string(timeline_as_text)
		file.flush()
		var error := file.get_error()
		file.close()
		if error != OK:
			push_error('[Dialogic] Cannot write timeline "%s": %s' % [path, error_string(error)])
			return error

	return OK
