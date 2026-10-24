extends SceneTree

const STARFISH_SCENE := preload("res://gameplay/enemies/starfish/starfish.tscn")

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var starfish := STARFISH_SCENE.instantiate() as EnemyBase
	root.add_child(starfish)
	starfish.set_physics_process(false)
	starfish.fsm._update(0.0)
	_expect(starfish.fsm.current_state.name == &"Run", "Starfish starts in Run")
	_expect(starfish.contact_hitbox.is_active(), "Run enables contact damage")
	_expect(is_instance_valid(starfish.target_detector), "Starfish has a TargetDetector")
	_expect(
		not starfish.direction_pivot.is_ancestor_of(starfish.target_detector),
		"Starfish detection range stays fixed while it turns"
	)
	var detector_shape: Shape3D = starfish.target_detector.get_node("CollisionShape3D").shape
	_expect(
		detector_shape is CylinderShape3D and is_equal_approx(detector_shape.radius, 4.0),
		"Starfish detects the player in a fixed radius-4 circle"
	)
	_expect(starfish.visual.has_animation(&"attack_down"), "Starfish has attack animation")
	_expect(starfish.visual.has_animation(&"hit_left"), "Starfish maps hurt frames to Hit")
	_expect(starfish.visual.has_animation(&"death_up"), "Starfish maps dead frames to Death")

	var player := Node3D.new()
	player.add_to_group(&"player")
	player.global_position = starfish.global_position + Vector3(0, 0, 2)
	root.add_child(player)
	starfish.set_target(player)
	starfish.fsm._update(0.0)
	starfish.fsm._update(0.0)
	_expect(starfish.fsm.current_state.name == &"Attack", "Starfish attacks when a player is detected")
	_expect(not starfish.contact_hitbox.is_active(), "Wind-up does not deal contact damage")
	var attack := starfish.fsm.current_state as StarfishAttack
	starfish.fsm._update(attack.wind_up + 0.01)
	_expect(starfish.contact_hitbox.is_active(), "Charge enables contact damage")

	starfish.free()
	player.free()
	print("Starfish tests: ", _failures, " failures")
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("Starfish test failed: " + message)
