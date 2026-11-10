extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var room := (load("res://world/tests/beach_test.tscn") as PackedScene).instantiate()
	room.get_node("Starfish").free()
	room.get_node("EliteStarfish").free()
	root.add_child(room)
	current_scene = room
	await process_frame
	var tide := room.get_node("FlatTide") as FlatTideController
	var zone := tide.zones[0]
	var footsteps := tide.get_node("WaterFootsteps")
	tide.set_physics_process(false)
	tide.state = FlatTideController.State.LOW
	tide._warned = true
	tide._elapsed = tide.low_duration - tide.warning_fade_duration * 0.5
	tide._apply_coverage()
	_check(
		is_equal_approx(
			(zone.material_override as ShaderMaterial).get_shader_parameter("warning"), 0.5
		),
		"Controller fades the warning before the tide rises"
	)
	zone.set_coverage(1.0, false, 0.0)
	var ground_point := zone.to_global(Vector3.ZERO)
	footsteps._emit_mark(ground_point, Vector3.RIGHT, zone)
	var mark: MeshInstance3D = footsteps._marks[0]
	_check(mark.visible, "A step in water shows a mark")
	_check(
		is_equal_approx(
			mark.global_position.y,
			zone.get_surface_height_at(ground_point) + footsteps.surface_clearance
		),
		"Step rests on the water surface"
	)
	zone.set_coverage(1.0, false, 0.5)
	footsteps._update_marks(0.1)
	_check(
		is_equal_approx(
			mark.global_position.y,
			zone.get_surface_height_at(ground_point) + footsteps.surface_clearance
		),
		"Step follows animated water height"
	)
	zone.set_coverage(0.0, false, 0.5)
	footsteps._update_marks(0.1)
	_check(not mark.visible, "Step disappears when the water recedes")
	room.queue_free()
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("Flat tide footsteps checks: PASS")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
