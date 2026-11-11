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
	var player := tide.player
	var zone := tide.zones[0]
	tide.set_physics_process(false)
	zone.set_coverage(1.0, false)
	var ground := zone.to_global(Vector3.ZERO)
	player.global_position = Vector3(ground.x, 0.86, ground.z)
	for index in range(10):
		await physics_frame
	tide.flooded_dash_multiplier = 0.5
	tide._update_player()
	_check(player.environment_is_water, "Player should be in water")
	_check(
		is_equal_approx(player.environment_dash_distance_multiplier, 0.5),
		"Water applies dash multiplier"
	)
	var dash = player.fsm.states.get("dash")
	player.pending_free_dash = true
	player.pending_free_dash_direction = Vector3.RIGHT
	dash._enter()
	_check(dash.active, "Dash starts on the ground")
	_check(
		is_equal_approx(dash._dash_distance, player.data.dash_distance * 0.5),
		"Water halves dash distance"
	)
	player.environment_dash_distance_multiplier = 1.0
	_check(
		is_equal_approx(dash._dash_distance, player.data.dash_distance * 0.5),
		"Dash retains its starting multiplier"
	)
	dash._exit()
	zone.set_coverage(0.0, false)
	tide._update_player()
	_check(not player.environment_is_water, "Player leaves water after tide recedes")
	_check(
		is_equal_approx(player.environment_dash_distance_multiplier, 1.0),
		"Dash multiplier resets on dry ground"
	)
	tide.flooded_dash_multiplier = 0.25
	zone.set_coverage(1.0, false)
	tide._update_player()
	_check(
		is_equal_approx(player.environment_dash_distance_multiplier, 0.25),
		"Water dash multiplier is configurable"
	)
	var material := zone.material_override as ShaderMaterial
	_check(
		material.render_priority == zone.water_render_priority,
		"Water uses its configured render priority"
	)
	var footsteps = tide.get_node("WaterFootsteps")
	footsteps._emit_mark(ground, Vector3.RIGHT, zone)
	var mark_material := footsteps._marks[0].mesh.material as ShaderMaterial
	_check(mark_material.render_priority > material.render_priority, "Footsteps render after water")
	room.queue_free()
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("Flat tide dash checks: PASS")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
