extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _ray(room: Node3D, from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(
		room.to_global(from), room.to_global(to), 1 << 8
	)
	return not room.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _check(value: bool, label: String) -> void:
	if not value:
		failures.append(label)


func _run() -> void:
	var room = load("res://world/biomes/base/base_room.tscn").instantiate()
	root.add_child(room)
	await physics_frame
	_check(_ray(room, Vector3(10, 1, 8), Vector3(16, 1, 8)), "ground edge blocked")
	_check(not _ray(room, Vector3(10, 1, 0), Vector3(15, 1, 0)), "right path entrance open")
	_check(not _ray(room, Vector3(0, 1, -9), Vector3(0, 1, -17)), "up path entrance open")
	_check(not _ray(room, Vector3(0, 1, 9), Vector3(0, 1, 18)), "down path entrance open")
	_check(not _ray(room, Vector3(-10, 1, 0), Vector3(-17, 1, 0)), "left path entrance open")
	room.open_exits = 1
	await process_frame
	await physics_frame
	_check(_ray(room, Vector3(10, 1, 0), Vector3(16, 1, 0)), "closed exit blocked")
	var ground = room.get_node("Environment/BaseGround/StaticBody3D/CollisionShape3D")
	ground.shape = ground.shape.duplicate()
	ground.shape.size.x = 8.0
	room._rebuild_ground_boundaries()
	await physics_frame
	_check(_ray(room, Vector3(6, 1, 5), Vector3(10, 1, 5)), "resized ground boundary")
	room.queue_free()
	await process_frame
	for entry in [
		["res://world/biomes/beach/beach_01.tscn", Vector3(10, 1, 0), Vector3(13, 1, 0)],
		["res://world/biomes/forest/forest_silas_01.tscn", Vector3(11, 1, 2), Vector3(15, 1, 2)]
	]:
		room = load(entry[0]).instantiate()
		root.add_child(room)
		await physics_frame
		_check(not _ray(room, entry[1], entry[2]), "platform dock open: " + entry[0])
		if entry[0].contains("forest_silas_01"):
			var player: CharacterBody3D = room.get_node("Foxy")
			var collision := KinematicCollision3D.new()
			var start := player.global_transform
			start.origin = room.to_global(Vector3(10, 1, 8))
			_check(
				(
					player.test_move(start, Vector3(5, 0, 0), collision)
					and collision.get_collider() == room.get_node("GroundBoundaries")
				),
				"Foxy collides with Silas room ground boundary"
			)
		room.queue_free()
		await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("Ground boundary checks: PASS")
	quit(0 if failures.is_empty() else 1)
