extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(100, 1, 100)
	collider.shape = shape
	floor_body.add_child(collider)
	floor_body.position.y = -0.5
	world.add_child(floor_body)
	var player := load("res://gameplay/player/foxy.tscn").instantiate() as Player
	# Pin the fixture independently of the forge selected for manual testing.
	player.get_node("WeaponController").default_forge = null
	player.get_node("WeaponController").default_weapon = load(
		"res://data/weapon/weapon_dagger.tres"
	)
	player.position.y = 0.7
	world.add_child(player)
	for frame in 12:
		await physics_frame
	_check(player.is_on_floor(), "Fixture is grounded")
	player.set_physics_process(false)
	var camera := Camera3D.new()
	world.add_child(camera)
	player.camera = camera
	camera.position = player.position + Vector3(0, 10, 10)
	camera.look_at(player.position)
	camera.make_current()
	var target: Vector3 = player._get_mouse_target()
	var expected := (target - player.global_position).normalized()
	player.move_direction = -expected
	player.last_facing_direction = -expected
	_check(
		player.build_attack_context().direction.is_equal_approx(expected),
		"Cursor aim overrides opposite movement and facing"
	)
	var state := player.get_node("States/Attack")
	player.request_attack()
	state._enter()
	_check(state.accepted, "Mouse-aimed attack starts")
	_check(
		player.weapon_controller._context.direction.is_equal_approx(expected),
		"Attack hitbox uses cursor direction"
	)
	_check(
		player.last_facing_direction.is_equal_approx(expected),
		"Character faces the accepted attack"
	)
	_check(state._step_direction.is_equal_approx(expected), "Forward step follows cursor aim")
	var displacement := Vector3.ZERO
	for frame in 12:
		state._update(0.02)
		var movement := Vector3(player.velocity.x, 0, player.velocity.z)
		_check(
			movement.dot(expected) >= -0.0001,
			"Holding opposite movement never pulls the swing backward"
		)
		displacement += movement * 0.02
	_check(
		displacement.is_equal_approx(expected * state._combo_step.step_distance),
		"Opposite movement preserves the authored lunge distance without drift"
	)
	_check(
		Vector3(player.velocity.x, 0, player.velocity.z).is_zero_approx(),
		"Recovery stays still after the forward step ends"
	)
	var visual_facing: Vector3 = player.visual._facing
	# Moving the camera changes the projected cursor target without changing the mouse.
	camera.position = player.position + Vector3(10, 10, 0)
	camera.look_at(player.position)
	var next_target: Vector3 = player._get_mouse_target()
	var next_direction := (next_target - player.global_position).normalized()
	_check(not next_direction.is_equal_approx(expected), "Fixture changes aim direction")
	player.move_direction = -next_direction
	state._update(0.01)
	_check(
		player.weapon_controller._context.direction.is_equal_approx(expected),
		"Current swing stays locked when aim and movement change"
	)
	_check(
		player.visual._facing.is_equal_approx(visual_facing), "Current animation keeps its facing"
	)
	var duration := player.weapon_controller.get_attack_duration()
	player.weapon_controller._physics_process(duration - 0.04)
	player.request_attack()
	state._update(0.01)
	_check(
		player.weapon_controller._queued_attack.direction.is_equal_approx(next_direction),
		"Combo buffer uses new cursor aim instead of movement"
	)
	player.weapon_controller._physics_process(0.05)
	_check(player.weapon_controller._context.combo_index == 1, "Buffered combo continues")
	_check(
		player.weapon_controller._context.direction.is_equal_approx(next_direction),
		"Next swing uses its own cursor direction"
	)
	_check(
		player.last_facing_direction.is_equal_approx(next_direction),
		"Character turns when next swing starts"
	)
	state._exit()
	player.update_facing()
	_check(
		player.last_facing_direction.is_equal_approx(player.move_direction),
		"Locomotion resumes movement facing"
	)
	player.update_movement(0.02, true)
	_check(
		player.velocity.dot(player.move_direction) > 0.0,
		"Held movement resumes after leaving Attack"
	)
	# A cursor directly over the actor must not produce a zero attack direction.
	var fallback := AimFallbackPlayer.new()
	var visual := PlayerVisual.new()
	visual.name = "Visual"
	fallback.add_child(visual)
	var fsm := Fsm.new()
	fsm.name = "FSM"
	fallback.add_child(fsm)
	world.add_child(fallback)
	fallback.last_facing_direction = Vector3.LEFT
	_check(
		fallback.build_attack_context().direction.is_equal_approx(Vector3.LEFT),
		"Coincident cursor target falls back to facing"
	)
	fallback.has_mouse_target = false
	_check(
		fallback.build_attack_context().direction.is_equal_approx(Vector3.LEFT),
		"Missing mouse target falls back to facing"
	)
	world.free()
	# Let the global audio manager finish the swing sound before shutting down.
	await create_timer(0.5).timeout
	if _failures == 0:
		print("Mouse attack aim, combo, direction lock and fallbacks passed")
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


class AimFallbackPlayer:
	extends Player
	var has_mouse_target: bool = true

	func _ready() -> void:
		set_physics_process(false)

	func _get_mouse_target() -> Variant:
		return global_position if has_mouse_target else null
