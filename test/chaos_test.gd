extends SceneTree

var failures: int = 0
var world: Node3D
var player: Player
var enemy: EnemyBase


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame


func attack(action: StringName) -> bool:
	var context := AttackContext.new()
	context.action = action
	context.direction = Vector3.FORWARD
	return player.weapon_controller.try_attack(context)


func thrown_dagger() -> WeaponAttack:
	for child in world.get_children():
		if child is WeaponAttack:
			return child
	return null


func _run() -> void:
	var meter := ChaosComponent.new()
	meter.init(100.0)
	meter.gain(120.0)
	check(meter.current == 100.0 and meter.is_full(), "Chaos must clamp at maximum")
	check(meter.try_consume_full() and meter.current == 0.0, "Ability must consume all chaos")
	meter.gain(99.0)
	check(not meter.try_consume_full() and meter.current == 99.0, "Partial chaos cannot be spent")
	meter.init(0.0)
	check(not meter.is_full(), "Zero capacity must disable ability")
	meter.free()

	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(50, 1, 50)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.5
	world.add_child(floor_body)
	player = load("res://gameplay/player/foxy.tscn").instantiate() as Player
	# Keep combat assertions independent from the live balance resource.
	player.data = player.data.duplicate() as PlayerData
	player.data.chaos_per_hit = 20.0
	# Use a private weapon fixture so balancing the live dagger cannot break hit assertions.
	player.weapon_controller.default_weapon = (
		player.weapon_controller.default_weapon.duplicate(true) as WeaponData
	)
	player.weapon_controller.default_weapon.normal_attack.damage_hp = 1
	player.weapon_controller.default_weapon.secondary_attack.damage_hp = 3
	player.position.y = 1.0
	world.add_child(player)
	await frames(90)
	check(player.is_on_floor(), "Player fixture must be grounded")
	check(player.chaos.current == 0.0, "Player must start with empty chaos")
	var mouse_events := InputMap.action_get_events("secondary_attack")
	check(
		mouse_events.size() == 1 and mouse_events[0].button_index == MOUSE_BUTTON_RIGHT,
		"Right mouse must trigger secondary attack"
	)
	check(not attack(&"secondary"), "Ability must reject empty chaos")
	check(attack(&"normal"), "Normal attack must work without chaos")
	await frames(40)
	check(player.chaos.current == 0.0, "Missing must not generate chaos")

	enemy = load("res://gameplay/enemies/barrel/barrel.tscn").instantiate() as EnemyBase
	enemy.data = enemy.data.duplicate()
	enemy.data.max_hp = 100
	enemy.position = Vector3(0, player.position.y, -1.4)
	world.add_child(enemy)
	enemy.set_physics_process(false)
	await frames(3)
	for i in 5:
		check(attack(&"normal"), "Melee attack must be accepted")
		await frames(40)
	check(enemy.hp.current_hp == 95, "Melee must deal damage once per attack")
	check(player.chaos.current == 100.0, "Five confirmed hits must fill chaos")
	check(
		player.get_node("PlayerHUD/ChaosControl/WeaponIcon").modulate == Color.WHITE,
		"Full chaos must light up the weapon skill icon"
	)

	enemy.position.z = -4.0
	await frames(3)
	check(attack(&"secondary"), "Full chaos must allow dagger throw")
	var dagger := thrown_dagger()
	check(
		dagger != null and not dagger.launched and not dagger.is_physics_processing(),
		"Dagger must wait for windup before flying"
	)
	check(player.chaos.current == 0.0, "Accepted throw must consume all chaos immediately")
	check(not attack(&"secondary"), "Busy controller must reject a second throw")
	await frames(50)
	check(
		not player.weapon_controller.busy and is_instance_valid(dagger),
		"Dagger must survive after the attack animation releases it"
	)
	if is_instance_valid(dagger):
		dagger.cancel()
		check(
			not dagger.is_queued_for_deletion(), "Launched dagger must survive attack cancellation"
		)
	check(enemy.hp.current_hp == 92, "Thrown dagger must hit the enemy for three damage")
	check(player.chaos.current == 20.0, "Thrown dagger damage must report a confirmed hit")
	check(not attack(&"secondary"), "Partial chaos must reject another throw")
	await frames(60)
	check(enemy.hp.current_hp == 89, "Returning dagger must hit the same enemy once more")
	check(player.chaos.current == 40.0, "Return hit must also generate chaos")
	for child in world.get_children():
		check(not child is WeaponAttack, "Caught dagger must be removed")

	# A world collider must stop the projectile before it reaches the enemy.
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(3, 3, 0.2)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	wall.position = Vector3(0, 1, -2)
	world.add_child(wall)
	await frames(3)
	player.chaos.gain(100.0)
	check(attack(&"secondary"), "Throw toward wall must be accepted")
	await frames(50)
	check(
		enemy.hp.current_hp == 89, "Dagger must return at walls without hitting enemies behind them"
	)
	check(player.chaos.current == 0.0, "Wall hit must not generate chaos")
	wall.queue_free()
	await frames(2)

	# A rejected ability definition must preserve the full meter.
	player.chaos.gain(100.0)
	var original := player.weapon_controller.equipped.definition
	var no_ability := original.duplicate() as WeaponData
	no_ability.secondary_attack = null
	player.weapon_controller.equipped.definition = no_ability
	check(
		not attack(&"secondary") and player.chaos.is_full(),
		"Missing weapon ability must not consume chaos"
	)
	player.weapon_controller.equipped.definition = original
	# A missed dagger must return after reaching maximum range.
	enemy.position.x = 10.0
	check(attack(&"secondary"), "Throw into empty space must be accepted")
	await frames(65)
	player.position.x = -3.0
	await frames(65)
	for child in world.get_children():
		check(
			not child is WeaponAttack,
			"Returning dagger must follow and be caught by a moving thrower"
		)

	player.chaos.gain(100.0)
	check(attack(&"secondary"), "Lifetime test throw must be accepted")
	dagger = thrown_dagger()
	if dagger != null:
		dagger.set("lifetime", 0.1)
	await frames(40)
	check(not is_instance_valid(dagger), "Dagger must expire when its lifetime ends")

	# Cancelling during windup removes the unlaunched dagger without any damage.
	player.chaos.gain(100.0)
	check(attack(&"secondary"), "Windup cancellation test throw must be accepted")
	dagger = thrown_dagger()
	player.weapon_controller.cancel()
	await frames(3)
	check(not is_instance_valid(dagger), "Unlaunched dagger must be removed on cancellation")
	world.queue_free()
	await frames(2)
	print("Chaos integration checks: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
