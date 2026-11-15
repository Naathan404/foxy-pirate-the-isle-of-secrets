extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func run() -> void:
	var room := (load("res://world/biomes/hub/map/room_02.tscn") as PackedScene).instantiate()
	root.add_child(room)
	await process_frame
	var player := room.get_node("Foxy") as Player
	var camera := player.get_node("Camera3D") as BoundedFollowCamera3D
	camera.set_process(false)
	camera.movement_bob_enabled = false
	var start := camera.global_position
	player.dash_started.emit()
	player.global_position += Vector3.RIGHT * 2.0
	camera._process(camera.dash_hold_duration * 0.5)
	check(camera.global_position.distance_to(start) < 0.01, "Camera holds briefly when dash starts")
	camera._process(camera.dash_hold_duration)
	check(camera.global_position.x > start.x, "Camera begins catching up after the hold")
	check(camera.global_position.x < start.x + 2.0, "Camera catches up smoothly")
	for frame in range(120):
		camera._process(1.0 / 60.0)
	check(not camera._dash_follow_active, "Camera settles back to normal follow")
	player.dash_started.emit()
	player.global_position += Vector3.RIGHT * (camera.dash_max_lag_distance * 2.0)
	camera._process(0.0)
	check(
		is_equal_approx(
			camera.global_position.x,
			(
				player.global_position.x
				+ camera._follow_offset.x * player.global_basis.x.length()
				- camera.dash_max_lag_distance
			)
		),
		"Dash lag is limited"
	)
	player.dash_started.emit()
	check(camera._dash_follow_active, "Consecutive dash restarts the effect")
	camera.begin_dialogue_override()
	check(not camera._dash_follow_active, "Dialogue cancels dash follow")
	camera.end_dialogue_override()
	camera.combat_focus_offset = Vector3(0.5, 0.0, 0.0)
	camera._process(0.0)
	var focused_start := camera.global_position
	player.dash_started.emit()
	player.global_position += Vector3.RIGHT
	camera._process(0.0)
	check(
		camera.global_position.distance_to(focused_start) < 0.01,
		"Combat focus does not jump on dash"
	)
	camera.combat_focus_offset = Vector3.ZERO
	camera.snap_to_follow()
	player.dash_started.emit()
	camera.snap_to_follow()
	check(not camera._dash_follow_active, "Scene transition snap clears dash follow")
	room.queue_free()
	await process_frame
	print("Dash camera follow: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
