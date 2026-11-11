extends SceneTree

const SCENES := [
	"res://world/tests/test_coral_valley.tscn",
	"res://world/coral_valley/scenes/coral_valley.tscn",
	"res://world/coral_valley/scenes/coral_valley2.tscn",
	"res://world/coral_valley/scenes/islands/coral_island2.tscn",
	"res://world/coral_valley/scenes/islands/coral_island7.tscn",
	"res://world/coral_valley/scenes/islands/coral_island9.tscn",
	"res://world/coral_valley/scenes/islands/coral_island11.tscn",
]


func _initialize() -> void:
	for path in SCENES:
		var scene := load(path) as PackedScene
		if scene == null or not scene.can_instantiate():
			push_error("Cannot load scene: " + path)
			quit(1)
			return
		var instance := scene.instantiate()
		if instance == null:
			push_error("Cannot instantiate scene: " + path)
			quit(1)
			return
		instance.free()
	print("Former tide scenes load: PASS")
	quit(0)
