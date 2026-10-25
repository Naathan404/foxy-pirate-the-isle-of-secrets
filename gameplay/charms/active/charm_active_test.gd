extends SceneTree
## Headless smoke test cho ba Active Charm Phase 4.

const ARROW_RAIN: CharmData = preload("res://gameplay/charms/charm_data/arrow_rain.tres")
const CRESCENT_CLEAVE: CharmData = preload("res://gameplay/charms/charm_data/crescent_cleave.tres")
const TIDE_GRAPPLE: CharmData = preload("res://gameplay/charms/charm_data/tide_grapple.tres")
const CRESCENT_ATTACK_SCENE = preload("res://gameplay/charms/active/crescent_cleave_attack.tscn")
const TIDE_ATTACK_SCENE = preload("res://gameplay/charms/active/tide_grapple_attack.tscn")

var _failures: int = 0
var _arrow_launch_count: int = 0
var _arrow_first_direction: Vector3 = Vector3.ZERO
var _arrow_last_damage_hp: int = 0


func _initialize() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	_test_data()
	var world := Node3D.new()
	root.add_child(world)
	var actor := MockActor.new()
	world.add_child(actor)
	actor.setup_stats_and_weapon(450.0, 100)
	var manager := CharmSocketManager.new()
	var registry := CharmRegistry.new()
	registry.definitions = [ARROW_RAIN, CRESCENT_CLEAVE, TIDE_GRAPPLE]
	manager.registry = registry
	manager.actor = actor
	manager.loadout = CharmLoadout.new()
	manager.add_child(registry)
	actor.add_child(manager)
	await process_frame
	manager.set_safe_location(true)
	for definition: CharmData in registry.definitions:
		_assert_true(
			registry.set_owned(definition.charm_id, true), "own " + definition.display_name
		)

	await _test_arrow_rain(actor, manager, registry)
	await _test_crescent_cleave(actor, world, manager, registry)
	await _test_tide_grapple(actor, world, manager, registry)
	world.free()
	if _failures == 0:
		print("Charm Active Phase 4: all tests passed")
	quit(0 if _failures == 0 else 1)


func _test_data() -> void:
	var definitions: Array[CharmData] = [ARROW_RAIN, CRESCENT_CLEAVE, TIDE_GRAPPLE]
	_assert_equal(CharmValidator.validate_catalog(definitions).size(), 0, "valid catalog")
	_assert_equal(ARROW_RAIN.get_param_int(&"projectile_count"), 8, "Arrow Rain count")
	_assert_near(ARROW_RAIN.get_param_float(&"damage_percent"), 0.35, "Arrow damage")
	var volley_duration := ARROW_RAIN.get_param_float(&"volley_duration_seconds")
	_assert_true(volley_duration >= 1.0 and volley_duration <= 1.5, "Arrow volley data")
	_assert_near(ARROW_RAIN.resource_cost, 100.0, "Arrow cost")
	_assert_near(ARROW_RAIN.cooldown_seconds, 6.0, "Arrow cooldown")
	_assert_near(CRESCENT_CLEAVE.get_param_float(&"damage_multiplier"), 2.0, "Cleave damage")
	_assert_near(CRESCENT_CLEAVE.resource_cost, 100.0, "Cleave cost")
	_assert_near(CRESCENT_CLEAVE.cooldown_seconds, 4.0, "Cleave cooldown")
	_assert_near(TIDE_GRAPPLE.get_param_float(&"damage_multiplier"), 2.5, "Tide damage")
	_assert_near(TIDE_GRAPPLE.get_param_float(&"stun_seconds"), 1.0, "Tide stun")
	_assert_near(TIDE_GRAPPLE.resource_cost, 150.0, "Tide cost")
	_assert_near(TIDE_GRAPPLE.cooldown_seconds, 5.0, "Tide cooldown")
	_assert_equal(TIDE_GRAPPLE.acquisition_source, &"fixed_boss_reward", "Tide source")
	_assert_true(InputMap.has_action(&"charm_slot_q"), "Q input exists")


func _test_arrow_rain(
	actor: MockActor, manager: CharmSocketManager, registry: CharmRegistry
) -> void:
	_assert_true(
		manager.equip_charm(ARROW_RAIN.charm_id, CharmConstants.SocketId.Q), "equip Arrow Rain"
	)
	var runtime := registry.get_equipped(CharmConstants.SocketId.Q)
	var effect := runtime.effect as ArrowRainEffect
	effect.projectile_launched.connect(_on_arrow_projectile_launched)
	actor.aim_target = Vector3.RIGHT * 8.0
	actor.has_aim_target = true
	_assert_true(manager.activate_socket(CharmConstants.SocketId.Q), "activate Arrow Rain")
	_assert_near(actor.stamina.get_current_sp(), 350.0, "Arrow cost consumed")
	_assert_true(runtime.cooldown_remaining > 5.9, "Arrow cooldown started")
	_assert_false(manager.activate_socket(CharmConstants.SocketId.Q), "Arrow cooldown rejects")
	_assert_near(actor.stamina.get_current_sp(), 350.0, "cooldown rejection is free")
	await create_timer(1.8).timeout
	_assert_equal(_arrow_launch_count, 8, "Arrow launches eight projectiles")
	_assert_true(_arrow_first_direction.is_equal_approx(Vector3.RIGHT), "Arrow cursor aim")
	_assert_equal(_arrow_last_damage_hp, 35, "Arrow projectile damage")
	runtime.reset_cooldown()
	_assert_true(manager.activate_socket(CharmConstants.SocketId.Q), "reactivate Arrow Rain")
	actor.dead = true
	await physics_frame
	await process_frame
	_assert_equal(effect.get("_remaining_projectiles"), 0, "death cancels Arrow volley")
	_assert_equal((effect.get("_executions") as Array).size(), 0, "death clears projectiles")
	actor.dead = false
	_assert_true(manager.unequip_charm(CharmConstants.SocketId.Q), "unequip Arrow Rain")
	await create_timer(0.9).timeout


func _test_crescent_cleave(
	actor: MockActor, world: Node3D, manager: CharmSocketManager, registry: CharmRegistry
) -> void:
	_assert_true(
		manager.equip_charm(CRESCENT_CLEAVE.charm_id, CharmConstants.SocketId.Q),
		"equip Crescent Cleave"
	)
	_assert_true(manager.activate_socket(CharmConstants.SocketId.Q), "activate Crescent Cleave")
	_assert_near(actor.stamina.get_current_sp(), 150.0, "Cleave cost consumed")
	var runtime := registry.get_equipped(CharmConstants.SocketId.Q)
	_assert_true(runtime.cooldown_remaining > 3.9, "Cleave cooldown started")
	var attack := CRESCENT_ATTACK_SCENE.instantiate() as CrescentCleaveAttack
	world.add_child(attack)
	attack.context = _make_attack_context(actor, Vector3.BACK, 200, &"crescent_cleave")
	attack.global_position = Vector3.ZERO
	attack.radius_units = 2.8
	attack.half_angle_degrees = 90.0
	_assert_true(attack.activate(), "Cleave execution validates")
	var front_target := MockTarget.new()
	world.add_child(front_target)
	front_target.global_position = Vector3.BACK * 2.0
	var front_hurtbox := _add_hurtbox(front_target)
	var back_target := MockTarget.new()
	world.add_child(back_target)
	back_target.global_position = Vector3.FORWARD * 2.0
	var back_hurtbox := _add_hurtbox(back_target)
	attack.call("_try_hit", front_hurtbox)
	attack.call("_try_hit", front_hurtbox)
	attack.call("_try_hit", back_hurtbox)
	_assert_equal(front_target.hit_count, 1, "Cleave hits front target once")
	_assert_equal(front_target.last_damage_hp, 200, "Cleave deals 200 percent")
	_assert_equal(back_target.hit_count, 0, "Cleave excludes rear target")
	attack.cancel()
	await process_frame
	_assert_true(manager.unequip_charm(CharmConstants.SocketId.Q), "unequip Cleave")


func _test_tide_grapple(
	actor: MockActor, world: Node3D, manager: CharmSocketManager, registry: CharmRegistry
) -> void:
	_assert_true(
		manager.equip_charm(TIDE_GRAPPLE.charm_id, CharmConstants.SocketId.Q), "equip Tide Grapple"
	)
	actor.has_aim_target = false
	_assert_true(manager.activate_socket(CharmConstants.SocketId.Q), "activate Tide Grapple")
	_assert_near(actor.stamina.get_current_sp(), 0.0, "Tide cost consumed")
	var runtime := registry.get_equipped(CharmConstants.SocketId.Q)
	_assert_true(runtime.cooldown_remaining > 4.9, "Tide cooldown started")
	runtime.reset_cooldown()
	_assert_false(manager.activate_socket(CharmConstants.SocketId.Q), "Tide rejects low SP")
	_assert_near(actor.stamina.get_current_sp(), 0.0, "low SP rejection is free")
	var attack := TIDE_ATTACK_SCENE.instantiate() as TideGrappleAttack
	world.add_child(attack)
	attack.context = _make_attack_context(actor, Vector3.BACK, 250, &"tide_grapple")
	attack.pull_stop_distance = 1.0
	attack.pull_speed_units_per_second = 16.0
	attack.stun_seconds = 1.0
	var small_target := MockTarget.new()
	world.add_child(small_target)
	small_target.global_position = Vector3.BACK * 3.0
	_assert_equal(
		attack.resolve_hit(small_target, small_target.global_position),
		TideGrappleAttack.RESULT_TARGET_PULLED,
		"Tide pulls small target"
	)
	_assert_equal(small_target.last_damage_hp, 250, "Tide deals 250 percent")
	_assert_near(small_target.last_stun_seconds, 1.0, "Tide stuns for one second")
	var large_target := MockTarget.new()
	large_target.large = true
	world.add_child(large_target)
	large_target.global_position = Vector3.BACK * 3.0
	_assert_equal(
		attack.resolve_hit(large_target, large_target.global_position),
		TideGrappleAttack.RESULT_ACTOR_PULLED_LARGE,
		"Tide pulls actor to large target"
	)
	var boss_target := MockTarget.new()
	boss_target.large = true
	boss_target.add_to_group("boss")
	world.add_child(boss_target)
	boss_target.global_position = Vector3.RIGHT * 3.0
	_assert_equal(
		attack.resolve_hit(boss_target, boss_target.global_position),
		TideGrappleAttack.RESULT_ACTOR_PULLED_BOSS,
		"Tide identifies boss"
	)
	var terrain := StaticBody3D.new()
	world.add_child(terrain)
	_assert_equal(
		attack.resolve_hit(terrain, Vector3.LEFT * 3.0),
		TideGrappleAttack.RESULT_ACTOR_PULLED_TERRAIN,
		"Tide pulls actor to terrain"
	)
	_assert_equal(
		attack.resolve_hit(null, Vector3.ZERO), TideGrappleAttack.RESULT_MISS, "Tide null miss"
	)
	attack.queue_free()
	await process_frame


func _make_attack_context(
	actor: MockActor, direction: Vector3, damage_hp: int, action: StringName
) -> AttackContext:
	var context := AttackContext.new()
	context.actor = actor
	context.team = actor.team
	context.direction = direction
	context.damage_hp = damage_hp
	context.action = action
	return context


func _add_hurtbox(target: MockTarget) -> HurtBox:
	var hurtbox := HurtBox.new()
	hurtbox.actor = target
	hurtbox.team = CombatTeams.ENEMY
	target.add_child(hurtbox)
	return hurtbox


func _on_arrow_projectile_launched(
	_projectile_index: int, _projectile_count: int, direction: Vector3, damage_hp: int
) -> void:
	_arrow_launch_count += 1
	if _arrow_launch_count == 1:
		_arrow_first_direction = direction
	_arrow_last_damage_hp = damage_hp


func _assert_true(value: bool, label: String) -> void:
	if not value:
		_fail(label)


func _assert_false(value: bool, label: String) -> void:
	_assert_true(not value, label)


func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_fail("%s: expected %s, got %s" % [label, expected, actual])


func _assert_near(actual: float, expected: float, label: String) -> void:
	if not is_equal_approx(actual, expected):
		_fail("%s: expected %s, got %s" % [label, expected, actual])


func _fail(message: String) -> void:
	_failures += 1
	push_error("Charm Active Phase 4: " + message)


class MockActor:
	extends Node3D
	var stamina: StaminaComponent
	var weapon_controller: WeaponController
	var team: int = CombatTeams.PLAYER
	var dead: bool = false
	var aim_target: Vector3 = Vector3.ZERO
	var has_aim_target: bool = false
	var pull_count: int = 0

	func setup_stats_and_weapon(max_sp: float, base_damage_hp: int) -> void:
		stamina = StaminaComponent.new()
		add_child(stamina)
		stamina.init(max_sp, 0.0, 0.0)
		var attack := AttackData.new()
		attack.damage_hp = base_damage_hp
		var weapon_data := WeaponData.new()
		weapon_data.normal_attack = attack
		var weapon := WeaponInstance.new()
		weapon.definition = weapon_data
		weapon_controller = WeaponController.new()
		weapon_controller.equipped = weapon
		add_child(weapon_controller)

	func build_attack_context() -> AttackContext:
		var context := AttackContext.new()
		context.actor = self
		context.team = team
		context.direction = Vector3.BACK
		context.target_position = aim_target
		context.has_target = has_aim_target
		return context

	func apply_charm_grapple_pull(
		_target_position: Vector3, _stop_distance: float, _pull_speed: float
	) -> bool:
		pull_count += 1
		return true


class MockTarget:
	extends Node3D
	var large: bool = false
	var hit_count: int = 0
	var last_damage_hp: int = 0
	var last_stun_seconds: float = 0.0

	func receive_damage(damage: DamageContext) -> int:
		hit_count += 1
		last_damage_hp = damage.amount_hp
		return damage.amount_hp

	func apply_charm_grapple(
		source: Node3D, stop_distance: float, pull_speed: float, stun_seconds: float
	) -> StringName:
		if large:
			source.call("apply_charm_grapple_pull", global_position, stop_distance, pull_speed)
			return &"actor_pulled_boss" if is_in_group("boss") else &"actor_pulled_large"
		last_stun_seconds = stun_seconds
		return &"target_pulled"
