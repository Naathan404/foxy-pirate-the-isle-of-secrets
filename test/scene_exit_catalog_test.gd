extends SceneTree

const CATALOG := preload("res://world/components/scene_exit_catalog.gd")
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var forest := "res://world/biomes/forest/forest_01.tscn"
	var ruins := "res://world/biomes/ruins/ruins_01.tscn"
	_check(CATALOG.get_exit_ids(forest) == PackedStringArray(["down", "right"]),
		"Inherited Forest room lists only its enabled exits")
	_check(CATALOG.get_exit_ids(ruins) == PackedStringArray(["left", "up"]),
		"Inherited Ruins room resolves its overrides")
	_check(CATALOG.get_exit_ids("res://test/fixtures/scene_transition_arrival.tscn").has("from_hub"),
		"Standalone instanced triggers are discovered")
	_check(CATALOG.get_exit_ids("res://missing.tscn").is_empty(), "Missing scene is safe")
	_check(CATALOG.destination_warning(forest, &"right").is_empty(), "Valid destination accepted")
	_check(not CATALOG.destination_warning(forest, &"left").is_empty(), "Disabled destination flagged")
	var property := {}
	CATALOG.configure_dropdown(property, forest, &"old_gate")
	_check(property.hint == PROPERTY_HINT_ENUM and property.hint_string == ",down,right,old_gate",
		"Dropdown offers actual exits and preserves a stale selection")
	for message: String in failures:
		push_error(message)
	if failures.is_empty():
		print("Scene exit catalog checks: PASS")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
