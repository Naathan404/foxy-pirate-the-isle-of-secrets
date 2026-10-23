extends SceneTree

const BARREL_SCENE := preload("res://gameplay/enemies/barrel/barrel.tscn")
const BARREL_PLAYER_TEST_SCENE := preload("res://test/barrel_player_test.tscn")

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_player_sandbox_scene()
	_test_idle_to_shoot_burst()
	print("Barrel tests: ", _failures, " failures")
	quit(0 if _failures == 0 else 1)


func _test_player_sandbox_scene() -> void:
	var sandbox := BARREL_PLAYER_TEST_SCENE.instantiate()
	_expect(sandbox.get_node_or_null("Foxy") is Player, "Sandbox includes Foxy")
	_expect(sandbox.get_node_or_null("Barrel") is Barrel, "Sandbox includes Barrel")
	sandbox.free()


func _test_idle_to_shoot_burst() -> void:
	var barrel := BARREL_SCENE.instantiate() as Barrel
	barrel.min_bullets_per_volley = 3
	barrel.max_bullets_per_volley = 3
	barrel.max_bullet_angle_offset_degrees = 20.0
	root.add_child(barrel)
	barrel.set_physics_process(false)
	barrel.fsm._update(0.0)
	_expect(barrel.fsm.current_state.name == &"Idle", "Barrel starts in Idle")
	_expect(is_instance_valid(barrel.target_detector), "Barrel has a TargetDetector")
	_expect(
		not barrel.direction_pivot.is_ancestor_of(barrel.target_detector),
		"Barrel range stays fixed when Barrel turns"
	)
	var detector_shape: Shape3D = barrel.target_detector.get_node("CollisionShape3D").shape
	_expect(
		detector_shape is CylinderShape3D and is_equal_approx(detector_shape.radius, 4.0),
		"Barrel detects the player in a fixed radius-4 circle"
	)
	_expect(barrel.contact_hitbox == null, "Barrel does not use contact damage")
	_expect(barrel.visual.has_animation(&"shoot_side"), "Barrel has shoot animation")

	var player := Node3D.new()
	player.add_to_group(&"player")
	player.global_position = barrel.global_position + Vector3.FORWARD * 3.0
	root.add_child(player)
	barrel.set_target(player)
	barrel.fsm._update(0.0)
	barrel.fsm._update(0.0)
	_expect(barrel.fsm.current_state.name == &"Shoot", "Barrel enters Shoot when it has a target")
	_expect(
		String(barrel.visual.animation_player.assigned_animation).begins_with("shoot_"),
		"Barrel plays shoot animation"
	)

	var shoot := barrel.get_node("States/Shoot") as BarrelShoot
	_expect(_count_bullets() == 0, "Barrel waits for the shoot animation before firing")
	barrel.fsm._update(shoot.fire_delay)
	_expect(_count_bullets() == 1, "Barrel fires its first bullet after the configured delay")
	for _shot in range(shoot.shots_in_burst - 1):
		barrel.fsm._update(shoot.shot_interval)
	_expect(
		_count_bullets() == shoot.shots_in_burst,
		"A burst fires its selected number of bullets one at a time"
	)
	_expect(
		shoot.shots_in_burst == 3,
		"Barrel uses its configured random bullet-count range"
	)
	var bullet_angles: Array[float] = []
	for child in root.get_children():
		if child is BarrelBullet:
			bullet_angles.append(rad_to_deg(Vector3.BACK.signed_angle_to(child._direction, Vector3.UP)))
	_expect(
		bullet_angles.size() == 3
		and bullet_angles.all(func(angle): return absf(angle) <= 20.0),
		"Each bullet receives a random offset within the configured 20 degrees"
	)
	barrel.fsm._update(0.0)
	_expect(barrel.fsm.current_state.name == &"Idle", "Barrel returns to Idle after firing")

	for child in root.get_children():
		if child is BarrelBullet:
			child.free()
	barrel.free()
	player.free()


func _count_bullets() -> int:
	var count := 0
	for child in root.get_children():
		if child is BarrelBullet:
			count += 1
	return count


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
