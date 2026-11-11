extends SceneTree

const ROOM := "res://world/biomes/forest/forest_01.tscn"
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()
	create_timer(20.0, true, false, true).timeout.connect(func() -> void:
		push_error("Void reload test timed out")
		quit(1)
	)


func _run() -> void:
	var manager := root.get_node("GameManager")
	manager.fade_out_seconds = 0.03
	manager.fade_in_seconds = 0.03
	change_scene_to_file(ROOM)
	await scene_changed
	var original: WeakRef = weakref(current_scene)
	var player := manager.player as Player
	# Verify the Inspector toggle, then let real gravity carry Foxy into the void.
	current_scene.void_reload_enabled = false
	player.position = Vector3(50, -7, 0)
	for frame in 4:
		await physics_frame
		await process_frame
	_check(not manager.get("_transition_pending"), "Disabled void reload ignores falling player")
	player.position = Vector3(50, 0, 0)
	player.velocity = Vector3.ZERO
	current_scene.void_reload_enabled = true
	await physics_frame
	await process_frame
	_check(not manager.get("_transition_pending"), "Above void threshold does not reload")
	await manager.scene_transition_finished
	_check(original.get_ref() == null, "Falling replaces the room instance")
	_check(current_scene.scene_file_path == ROOM, "Void reloads the same room")
	player = manager.player as Player
	_check(absf(player.position.x) < 0.1 and player.position.y > current_scene.void_height,
		"Foxy returns to the authored spawn above the void")
	_check(not paused and manager.state == manager.State.PLAYING, "Gameplay resumes after fade")
	for failure: String in failures:
		push_error(failure)
	if failures.is_empty():
		print("Void reload checks: PASS")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
