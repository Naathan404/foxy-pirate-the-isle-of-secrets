extends SceneTree

var failures: Array[String] = []
var spawned: Array[EnemyBase] = []
var elite_flags: Array[bool] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var room := (load("res://world/tests/beach_test.tscn") as PackedScene).instantiate()
	room.get_node("Starfish").free()
	room.get_node("EliteStarfish").free()
	root.add_child(room)
	current_scene = room
	await process_frame
	await physics_frame
	var tide := room.get_node("FlatTide") as FlatTideController
	var zone := tide.zones[0]
	var spawner = tide.get_node("EnemySpawner")
	tide.set_physics_process(false)
	spawner._random.seed = 42
	spawner.enemies_per_tide = 5
	spawner.minimum_player_distance = 0.0
	spawner.elite_chance = 100.0
	spawner.enemy_spawned.connect(
		func(enemy: EnemyBase, elite: bool):
			spawned.append(enemy)
			elite_flags.append(elite)
	)
	tide._enter_state(FlatTideController.State.HIGH)
	tide._apply_coverage()
	tide._enter_state(FlatTideController.State.FALLING)
	_check(spawner._pending.size() == 5, "Select five positions in flooded ground")
	for i in spawner._pending.size():
		var a: Vector3 = spawner._pending[i].position
		_check(tide.is_point_flooded(a), "Selected position starts flooded")
		for j in range(i):
			var b: Vector3 = spawner._pending[j].position
			_check(
				Vector2(a.x - b.x, a.z - b.z).length() >= spawner.minimum_spacing,
				"Positions respect spacing"
			)
	_check(spawned.is_empty(), "No spawn while all selected points are submerged")
	for step in range(1, 101):
		tide._elapsed = tide.fall_duration * float(step) / 100.0
		tide._apply_coverage()
		for enemy in spawned:
			_check(
				not tide.is_point_flooded(enemy.global_position),
				"Enemy appears only after water recedes"
			)
	_check(spawner._pending.is_empty(), "All points processed by low tide")
	_check(not spawned.is_empty(), "At least one enemy spawned on available ground")
	_check(elite_flags.all(func(flag: bool): return flag), "100 percent elite chance spawns elites")
	spawner.wave_chance = 0.0
	tide._enter_state(FlatTideController.State.HIGH)
	tide._apply_coverage()
	tide._enter_state(FlatTideController.State.FALLING)
	_check(spawner._pending.is_empty(), "Zero wave chance selects no enemies")
	spawner.wave_chance = 100.0
	spawner.enemies_per_tide = 20
	spawner.minimum_spacing = 0.0
	var crab := FlatTideEnemyEntry.new()
	crab.normal_scene = load("res://gameplay/enemies/crab/crab.tscn")
	spawner.enemies.append(crab)
	tide._enter_state(FlatTideController.State.HIGH)
	tide._apply_coverage()
	tide._enter_state(FlatTideController.State.FALLING)
	var has_crab := false
	var has_elite_starfish := false
	for entry in spawner._pending:
		if entry.scene == crab.normal_scene:
			has_crab = true
			_check(not entry.elite, "An enemy without an elite variant uses its normal scene")
		if entry.scene == spawner.enemies[0].elite_scene:
			has_elite_starfish = true
	_check(has_crab and has_elite_starfish, "Enemy types are selected from the configured array")
	spawner.enemies.clear()
	tide._enter_state(FlatTideController.State.HIGH)
	tide._apply_coverage()
	tide._enter_state(FlatTideController.State.FALLING)
	_check(spawner._pending.is_empty(), "An empty enemy array spawns nothing")
	room.queue_free()
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("Flat tide enemy spawner checks: PASS")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
