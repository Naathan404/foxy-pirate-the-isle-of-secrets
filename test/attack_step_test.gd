extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var floor_body := _box(Vector3(0, -0.5, 0), Vector3(30, 1, 30))
	world.add_child(floor_body)
	var player := load("res://gameplay/player/foxy.tscn").instantiate() as Player
	# Pin the fixture independently of the forge selected for manual testing.
	player.get_node("WeaponController").collection.clear()
	player.get_node("WeaponController").default_forge = null
	player.get_node("WeaponController").default_weapon = load(
		"res://data/weapon/weapon_dagger.tres"
	)
	player.position.y = 0.7
	world.add_child(player)
	await _frames(12)
	_check(player.is_on_floor(), "Attack fixture is grounded")
	var state = player.get_node("States/Attack")
	var start := player.global_position
	await _start_attack(player)
	_check(state.accepted, "Normal attack is accepted")
	_check(player.position.x > start.x, "Attack advances body in facing direction")
	player.inventory_ui.open_inventory()
	var paused_position := player.global_position
	var paused_progress: float = state._step_elapsed
	await _frames(3)
	_check(player.global_position == paused_position, "Inventory freezes attack movement")
	_check(state._step_elapsed == paused_progress, "Inventory freezes step timing")
	player.inventory_ui.close_inventory(true)
	await _frames(40)
	_check(
		is_equal_approx(player.position.x - start.x, state.step_distance),
		"Step distance is bounded"
	)
	_check(absf(player.position.z - start.z) < 0.01, "Step does not drift sideways")
	_check(player.weapon_controller.busy == false, "Attack finishes normally")
	# A blocked attack consumes its step window instead of banking movement for later.
	player.position.x = 0.0
	var collider := player.get_node("CollisionShape3D") as CollisionShape3D
	var radius := (collider.shape as CapsuleShape3D).radius * collider.global_basis.x.length()
	var wall_x := collider.global_position.x + radius + 0.125
	var wall := _box(Vector3(wall_x, 1.5, 0), Vector3(0.05, 3, 4))
	world.add_child(wall)
	await _frames(2)
	start = player.global_position
	await _start_attack(player)
	await _frames(40)
	var blocked_distance := player.position.x - start.x
	_check(blocked_distance >= 0.0 and blocked_distance < 0.2, "Thin wall blocks forward step")
	wall.free()
	await _frames(5)
	_check(is_equal_approx(player.position.x - start.x, blocked_distance), "No delayed wall lunge")
	# Cooldown rejection must never grant a free step.
	player.position.x = 0.0
	player.weapon_controller.equipped.cooldowns[&"normal"] = 100.0
	start = player.global_position
	await _start_attack(player)
	await _frames(5)
	_check(is_equal_approx(player.position.x, start.x), "Rejected attack does not move body")
	player.weapon_controller.equipped.cooldowns.erase(&"normal")
	# Melee execution follows the actor when it activates and while active.
	var melee = load("res://gameplay/weapons/attack scenes/dagger_attack.tscn").instantiate()
	world.add_child(melee)
	var context := AttackContext.new()
	context.actor = player
	context.direction = Vector3.RIGHT
	context.team = 1
	melee.context = context
	melee.activate()
	_check(melee.global_position == player.global_position, "Melee activates at advanced body")
	player.position.x += 0.1
	melee.tick_active(0.016)
	_check(melee.global_position == player.global_position, "Melee hitbox follows body")
	melee.free()
	# Projectile secondary keeps its release recoil, without a forward body step.
	player.chaos.gain(player.chaos.maximum)
	start = player.global_position
	await _start_attack(player, &"secondary")
	_check(state.accepted, "Secondary attack is accepted")
	if is_instance_valid(player.weapon_controller._execution):
		player.weapon_controller._execution.launch_hitstop = 0.0
	await _frames(40)
	_check(is_equal_approx(player.position.x, start.x), "Dagger throw does not lunge body")
	# Hit interruption must clear step motion before knockback takes over.
	await _start_attack(player)
	player.take_damage(1)
	root.get_node("HitstopController").cancel()
	await _frames(3)
	_check(state._step_direction == Vector3.ZERO, "Hit interruption clears forward step")
	_check(player.velocity.x <= 0.0, "Step does not override hit knockback")
	root.get_node("HitstopController").cancel()
	root.get_node("ScreenShakeController").cancel()
	world.free()
	if _failures == 0:
		print("Attack step distance, pause, wall collision, rejection and interruption passed")
	quit(0 if _failures == 0 else 1)


func _start_attack(player: Player, action: StringName = &"normal") -> void:
	# Keep this movement/collision fixture aimed right under mouse-directed attacks.
	var target: Vector3 = player._get_mouse_target()
	var aim_offset := player.global_position + Vector3.RIGHT * 5.0 - target
	player._get_active_camera().global_position += aim_offset
	player.last_facing_direction = Vector3.RIGHT
	player.request_attack(action)
	await _frames(3)


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame


func _box(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	body.position = at
	return body


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
