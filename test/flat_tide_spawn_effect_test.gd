extends SceneTree
const ENEMY: PackedScene = preload("res://gameplay/enemies/starfish/starfish.tscn")
var spawned := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run_test")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func run_test() -> void:
	var arena := Node3D.new()
	root.add_child(arena)
	var controller := FlatTideController.new()
	arena.add_child(controller)
	controller.set_physics_process(false)
	var spawner := FlatTideEnemySpawner.new()
	spawner.controller = controller
	arena.add_child(spawner)
	spawner.enemy_spawned.connect(func(_enemy: EnemyBase, _elite: bool): spawned += 1)
	spawner._spawn(Vector3(0, 0, 0), ENEMY, false)
	spawner._spawn(Vector3(5, 0, 0), ENEMY, true)
	spawner._spawn(Vector3(10, 0, 0), null, false)
	check(spawned == 2, "only valid spawns emit enemy_spawned")
	var effects: Array[Node3D] = []
	for child in spawner.get_children():
		if child.get_script() == load("res://world/gimmick/flat_tide/flat_tide_spawn_effect.gd"):
			effects.append(child)
	check(effects.size() == 2, "every successful spawn has one effect")
	if effects.size() == 2:
		check(effects[0].global_position.is_equal_approx(Vector3.ZERO), "effect is at ground position")
		check(effects[1].scale.x > effects[0].scale.x, "elite effect is larger")
		var first = effects[0].get_node("Ripple").material_override
		var second = effects[1].get_node("Ripple").material_override
		check(first != second, "simultaneous ripples have independent materials")
	await create_timer(1.4).timeout
	if effects.size() == 2:
		check(not is_instance_valid(effects[0]) and not is_instance_valid(effects[1]), "effects clean up")
	spawner.spawn_effect_scene = null
	spawner._spawn(Vector3(10, 0, 0), ENEMY, false)
	check(spawned == 3, "disabling effect does not disable spawning")
	arena.queue_free()
	await process_frame
	print("Flat tide spawn effect tests: ", "passed" if failures == 0 else "failed")
	quit(0 if failures == 0 else 1)
