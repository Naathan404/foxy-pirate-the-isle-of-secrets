extends SceneTree

const SKELETON := preload("res://gameplay/enemies/coral_skeleton/coral_skeleton.tscn")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arena := Node3D.new()
	root.add_child(arena)
	current_scene = arena
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = CombatLayers.WORLD
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(40, 0.5, 40)
	floor_collision.shape = floor_shape
	floor_body.add_child(floor_collision)
	floor_body.position.y = -0.25
	arena.add_child(floor_body)
	var skeleton := SKELETON.instantiate() as CoralSkeleton
	skeleton.initial_facing = EnemyBase.InitialFacing.LEFT
	skeleton.sleep_delay = 0.7
	arena.add_child(skeleton)
	var player := CharacterBody3D.new()
	player.add_to_group("player")
	player.collision_layer = CombatLayers.PLAYER_BODY
	player.collision_mask = 0
	var player_collision := CollisionShape3D.new()
	var player_shape := CapsuleShape3D.new()
	player_shape.height = 1.8
	player_collision.shape = player_shape
	player.add_child(player_collision)
	player.position = Vector3(7.0, 0.9, 0)
	arena.add_child(player)
	await create_timer(0.5).timeout
	_check(not skeleton.has_target(), "Sleeping detector acquired player outside the small radius")
	_check(skeleton.fsm.current_state.name == &"Sleep", "Skeleton did not start asleep")
	var detector_shape := skeleton.get_node("TargetDetector/CollisionShape3D").shape as CylinderShape3D
	skeleton.sleep_detection_radius = 2.5
	await create_timer(0.1).timeout
	_check(is_equal_approx(detector_shape.radius, 2.5), "Sleep radius did not update at runtime")
	skeleton.sleep_detection_radius = 3.5
	player.position.x = 3.0
	await create_timer(0.8).timeout
	_check(skeleton.is_awake, "Player entering sleep radius did not wake skeleton")
	_check(is_equal_approx(detector_shape.radius, skeleton.detection_radius), "Awake detection radius was not applied")
	skeleton.request_state(&"hit", 50)
	await create_timer(0.8).timeout
	_check(skeleton.is_awake and skeleton.has_target(), "Hit recovery put an alert skeleton back to sleep")
	player.position.x = 7.0
	await create_timer(1.6).timeout
	_check(skeleton.has_target(), "Awake detector lost player inside the expanded radius")
	_check(skeleton.position.x > 0.5, "Skeleton did not approach player")
	player.position = Vector3(30, 0.9, 0)
	await create_timer(0.2).timeout
	_check(not skeleton.has_target(), "Detector did not lose player")
	var start_distance := skeleton.distance_from_home()
	var sideways := false
	var paused := false
	for frame in 360:
		await physics_frame
		if absf(skeleton.position.z) > 0.08:
			sideways = true
		if frame > 20 and skeleton.fsm.current_state.name == &"Return" and Vector2(skeleton.velocity.x, skeleton.velocity.z).length() < 0.01:
			paused = true
		if skeleton.fsm.current_state.name == &"Guard":
			break
	_check(start_distance > 0.5, "Return test did not start away from home")
	_check(sideways, "Return path did not bend")
	_check(paused, "Return path did not pause")
	_check(skeleton.distance_from_home() <= skeleton.home_tolerance + 0.1, "Skeleton did not return home")
	_check(skeleton.last_facing_direction.is_equal_approx(Vector3.LEFT), "Skeleton did not restore initial facing")
	_check(skeleton.fsm.current_state.name == &"Guard", "Skeleton did not wait awake after returning")
	await create_timer(0.2).timeout
	_check(skeleton.is_awake, "Skeleton slept before its configured delay")
	player.position = skeleton.position + Vector3(2, 0.9, 0)
	await create_timer(0.4).timeout
	_check(skeleton.has_target() and skeleton.is_awake, "Skeleton did not resume pursuit during the guard delay")
	player.position = Vector3(30, 0.9, 0)
	for _frame in 240:
		await physics_frame
		if not skeleton.has_target() and skeleton.fsm.current_state.name == &"Guard":
			break
	await create_timer(0.9).timeout
	_check(skeleton.fsm.current_state.name == &"Sleep", "Skeleton did not fall asleep after the configured delay")
	_check(not skeleton.is_awake and is_equal_approx(detector_shape.radius, skeleton.sleep_detection_radius), "Detector did not shrink after sleeping")
	arena.queue_free()
	await process_frame
	if failures.is_empty():
		print("Coral Skeleton movement tests passed")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
