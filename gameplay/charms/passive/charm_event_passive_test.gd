extends SceneTree
## Headless deterministic test cho bốn event/condition Passive Charm Phase 6.

const LIFE_STEAL: CharmData = preload("res://gameplay/charms/charm_data/life_steal.tres")
const DOUBLE_STRIKE: CharmData = preload("res://gameplay/charms/charm_data/double_strike.tres")
const ADRENALINE_SURGE: CharmData = preload(
	"res://gameplay/charms/charm_data/adrenaline_surge.tres"
)
const BACKSTABBER: CharmData = preload("res://gameplay/charms/charm_data/backstabber.tres")
const ARROW_RAIN: CharmData = preload("res://gameplay/charms/charm_data/arrow_rain.tres")
const DAGGER_ATTACK_SCENE_PATH := "res://gameplay/weapons/attack scenes/dagger_attack.tscn"

var _failures: int = 0
var _damage_event_count: int = 0
var _last_damage: DamageContext


func _initialize() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	_test_data()
	_test_seed_injection()
	var world := Node3D.new()
	root.add_child(world)
	var actor := MockActor.new()
	world.add_child(actor)
	actor.setup()
	var manager := CharmSocketManager.new()
	var registry := CharmRegistry.new()
	registry.definitions = [LIFE_STEAL, DOUBLE_STRIKE, ADRENALINE_SURGE, BACKSTABBER, ARROW_RAIN]
	manager.actor = actor
	manager.registry = registry
	manager.loadout = CharmLoadout.new()
	manager.add_child(registry)
	actor.charm_socket_manager = manager
	actor.add_child(manager)
	await process_frame
	for definition: CharmData in registry.definitions:
		_assert_true(
			registry.set_owned(definition.charm_id, true), "own " + definition.display_name
		)

	_test_life_steal(actor, registry)
	await _test_double_strike_pipeline(actor, world, manager, registry)
	_test_backstabber(actor, world, registry)
	_test_adrenaline_surge(actor, world, manager, registry)

	world.free()
	if _failures == 0:
		print("Charm Passive Phase 6: all tests passed")
	quit(0 if _failures == 0 else 1)


func _test_data() -> void:
	var definitions: Array[CharmData] = [LIFE_STEAL, DOUBLE_STRIKE, ADRENALINE_SURGE, BACKSTABBER]
	_assert_equal(CharmValidator.validate_catalog(definitions).size(), 0, "valid catalog")
	_assert_near(LIFE_STEAL.proc_chance, 0.05, "Life Steal chance")
	_assert_equal(LIFE_STEAL.get_param_int(&"heal_hp"), 1, "Life Steal heal")
	_assert_near(DOUBLE_STRIKE.proc_chance, 0.2, "Double Strike chance")
	_assert_near(DOUBLE_STRIKE.get_param_float(&"damage_multiplier"), 2.0, "Double Strike")
	_assert_near(ADRENALINE_SURGE.proc_chance, 0.2, "Adrenaline chance")
	_assert_near(ADRENALINE_SURGE.get_param_float(&"restore_sp"), 100.0, "Adrenaline SP")
	_assert_near(BACKSTABBER.get_param_float(&"damage_multiplier"), 1.5, "Backstabber")


func _test_seed_injection() -> void:
	var first := CharmProcRoller.new()
	var second := CharmProcRoller.new()
	first.set_seed(2606)
	second.set_seed(2606)
	for index: int in range(8):
		_assert_equal(first.roll(0.2), second.roll(0.2), "seeded roll %d" % index)


func _test_life_steal(actor: MockActor, registry: CharmRegistry) -> void:
	_assert_true(
		registry.equip_charm(LIFE_STEAL.charm_id, CharmConstants.SocketId.Q, actor),
		"equip Life Steal"
	)
	var effect := registry.get_equipped(CharmConstants.SocketId.Q).effect as LifeStealEffect
	effect.set_proc_seed(_find_seed(LIFE_STEAL.proc_chance, true))
	actor.hp.take_damage(2)
	var damage := _make_damage(actor, &"normal", WeaponData.WeaponCategory.MELEE)
	registry.dispatch_event(&"damage_dealt", [damage, actor, 1])
	_assert_equal(actor.hp.get_current_hp(), 9, "Life Steal heals one HP")
	_assert_proc(damage, LIFE_STEAL.charm_id, true, &"normal_attack_damage_dealt")
	registry.dispatch_event(&"damage_dealt", [damage, actor, 1])
	_assert_equal(actor.hp.get_current_hp(), 9, "Life Steal does not repeat one hit")

	var failed_damage := _make_damage(actor, &"normal", WeaponData.WeaponCategory.MELEE)
	effect.set_proc_seed(_find_seed(LIFE_STEAL.proc_chance, false))
	registry.dispatch_event(&"damage_dealt", [failed_damage, actor, 1])
	_assert_equal(actor.hp.get_current_hp(), 9, "Life Steal failed roll does not heal")
	_assert_proc(failed_damage, LIFE_STEAL.charm_id, false, &"normal_attack_damage_dealt")

	var skill_damage := _make_damage(actor, &"crescent_cleave", WeaponData.WeaponCategory.MELEE)
	effect.set_proc_seed(_find_seed(LIFE_STEAL.proc_chance, true))
	registry.dispatch_event(&"damage_dealt", [skill_damage, actor, 1])
	_assert_false(skill_damage.has_proc_result(LIFE_STEAL.charm_id), "Life Steal ignores skills")

	var stale_damage := _make_damage(actor, &"normal", WeaponData.WeaponCategory.MELEE)
	_assert_true(registry.unequip_socket(CharmConstants.SocketId.Q), "unequip Life Steal")
	registry.dispatch_event(&"damage_dealt", [stale_damage, actor, 1])
	_assert_false(stale_damage.has_proc_result(LIFE_STEAL.charm_id), "unequipped callback inactive")


func _test_double_strike_pipeline(
	actor: MockActor, world: Node3D, manager: CharmSocketManager, registry: CharmRegistry
) -> void:
	_assert_true(
		registry.equip_charm(DOUBLE_STRIKE.charm_id, CharmConstants.SocketId.Q, actor),
		"equip Double Strike"
	)
	var effect := registry.get_equipped(CharmConstants.SocketId.Q).effect as DoubleStrikeEffect
	effect.set_proc_seed(_find_seed(DOUBLE_STRIKE.proc_chance, true))
	var controller := WeaponController.new()
	controller.actor = actor
	controller.equipped = WeaponInstance.new()
	controller.equipped.definition = WeaponData.new()
	var target := MockTarget.new()
	world.add_child(target)
	target.setup(30)
	var hurtbox := HurtBox.new()
	hurtbox.actor = target
	hurtbox.team = CombatTeams.ENEMY
	target.add_child(hurtbox)
	var context := AttackContext.new()
	context.actor = actor
	context.team = CombatTeams.PLAYER
	context.action = &"normal"
	context.weapon_category = WeaponData.WeaponCategory.MELEE
	context.damage_hp = 10
	context.origin = actor.global_position
	context.direction = Vector3.BACK
	context.damage_prepared.connect(controller._on_damage_prepared)
	context.damage_applied.connect(controller._on_damage_applied.bind(controller.equipped))
	context.damage_applied.connect(_on_damage_applied)
	# Load after autoloads exist; the scene's CombatFeedback uses their singleton names.
	var attack := load(DAGGER_ATTACK_SCENE_PATH).instantiate() as DaggerAttack
	attack.context = context
	world.add_child(attack)
	attack.activate()
	attack.hitbox.call("_on_area_entered", hurtbox)
	_assert_equal(target.hp.get_current_hp(), 10, "Double Strike modifies damage before HP loss")
	_assert_equal(_damage_event_count, 1, "dagger relays one damage event")
	_assert_true(_last_damage != null, "dagger exposes DamageContext")
	if _last_damage != null:
		_assert_equal(_last_damage.base_amount_hp, 10, "damage payload keeps base amount")
		_assert_equal(_last_damage.amount_hp, 20, "damage payload exposes final amount")
		_assert_proc(_last_damage, DOUBLE_STRIKE.charm_id, true, &"normal_attack_outgoing_damage")
		_assert_equal(
			manager.modify_outgoing_damage(_last_damage.amount_hp, _last_damage),
			20,
			"Double Strike cannot apply twice to one hit"
		)
	attack.cancel()
	target.queue_free()
	controller.free()
	await process_frame

	var failed_damage := _make_damage(actor, &"normal", WeaponData.WeaponCategory.MELEE)
	effect.set_proc_seed(_find_seed(DOUBLE_STRIKE.proc_chance, false))
	_assert_equal(registry.modify_outgoing_damage(10, failed_damage), 10, "Double Strike fail")
	_assert_proc(failed_damage, DOUBLE_STRIKE.charm_id, false, &"normal_attack_outgoing_damage")
	_assert_true(registry.unequip_socket(CharmConstants.SocketId.Q), "unequip Double Strike")


func _test_backstabber(actor: MockActor, world: Node3D, registry: CharmRegistry) -> void:
	_assert_true(
		registry.equip_charm(BACKSTABBER.charm_id, CharmConstants.SocketId.Q, actor),
		"equip Backstabber"
	)
	var target := MockTarget.new()
	world.add_child(target)
	target.global_position = Vector3.ZERO
	target.facing_direction = Vector3.BACK
	actor.global_position = Vector3.FORWARD
	var behind := _make_damage(actor, &"normal", WeaponData.WeaponCategory.MELEE)
	behind.target = target
	behind.origin = actor.global_position
	_assert_equal(registry.modify_outgoing_damage(10, behind), 15, "Backstab from behind")
	_assert_proc(behind, BACKSTABBER.charm_id, true, &"behind_melee_normal_attack")

	actor.global_position = Vector3.BACK
	var front := _make_damage(actor, &"normal", WeaponData.WeaponCategory.MELEE)
	front.target = target
	front.origin = actor.global_position
	_assert_equal(registry.modify_outgoing_damage(10, front), 10, "front attack is not Backstab")
	_assert_proc(front, BACKSTABBER.charm_id, false, &"outside_backstab_arc")

	actor.global_position = Vector3.FORWARD
	var ranged := _make_damage(actor, &"normal", WeaponData.WeaponCategory.RANGED)
	ranged.target = target
	ranged.origin = actor.global_position
	_assert_equal(registry.modify_outgoing_damage(10, ranged), 10, "Backstab ignores ranged")
	_assert_false(ranged.has_proc_result(BACKSTABBER.charm_id), "ranged has no Backstab proc")
	var skill := _make_damage(actor, &"crescent_cleave", WeaponData.WeaponCategory.MELEE)
	skill.target = target
	skill.origin = actor.global_position
	_assert_equal(registry.modify_outgoing_damage(10, skill), 10, "Backstab ignores skills")

	_assert_true(
		registry.equip_charm(DOUBLE_STRIKE.charm_id, CharmConstants.SocketId.SPACE, actor),
		"equip Double Strike after Backstabber"
	)
	var double_effect := (
		registry.get_equipped(CharmConstants.SocketId.SPACE).effect as DoubleStrikeEffect
	)
	double_effect.set_proc_seed(_find_seed(DOUBLE_STRIKE.proc_chance, true))
	var stacked := _make_damage(actor, &"normal", WeaponData.WeaponCategory.MELEE)
	stacked.target = target
	stacked.origin = actor.global_position
	_assert_equal(
		registry.modify_outgoing_damage(5, stacked),
		16,
		"Charm damage modifiers stack in Q then Space order"
	)
	_assert_true(registry.unequip_socket(CharmConstants.SocketId.SPACE), "unequip stacked Double")
	_assert_true(registry.unequip_socket(CharmConstants.SocketId.Q), "unequip Backstabber")
	target.queue_free()


func _test_adrenaline_surge(
	actor: MockActor, world: Node3D, _manager: CharmSocketManager, registry: CharmRegistry
) -> void:
	_assert_true(
		registry.equip_charm(ARROW_RAIN.charm_id, CharmConstants.SocketId.Q, actor),
		"equip Active for Adrenaline"
	)
	_assert_true(
		registry.equip_charm(ADRENALINE_SURGE.charm_id, CharmConstants.SocketId.SPACE, actor),
		"equip Adrenaline Surge"
	)
	var active_runtime := registry.get_equipped(CharmConstants.SocketId.Q)
	active_runtime.start_cooldown()
	var effect := (
		registry.get_equipped(CharmConstants.SocketId.SPACE).effect as AdrenalineSurgeEffect
	)
	effect.set_proc_seed(_find_seed(ADRENALINE_SURGE.proc_chance, true))
	actor.stamina.try_consume(150.0)
	var target := MockTarget.new()
	world.add_child(target)
	target.setup(1)
	target.dead = true
	var kill_damage := _make_damage(actor, &"normal", WeaponData.WeaponCategory.MELEE)
	kill_damage.target = target
	kill_damage.target_defeated = true
	registry.dispatch_event(&"target_defeated", [target, kill_damage])
	_assert_near(active_runtime.cooldown_remaining, 0.0, "Adrenaline resets Active cooldown")
	_assert_near(actor.stamina.get_current_sp(), 250.0, "Adrenaline restores 100 SP")
	_assert_proc(kill_damage, ADRENALINE_SURGE.charm_id, true, &"player_caused_target_defeat")
	registry.dispatch_event(&"target_defeated", [target, kill_damage])
	_assert_near(actor.stamina.get_current_sp(), 250.0, "death event cannot proc twice")

	active_runtime.start_cooldown()
	actor.stamina.try_consume(100.0)
	effect.set_proc_seed(_find_seed(ADRENALINE_SURGE.proc_chance, false))
	var failed_damage := _make_damage(actor, &"normal", WeaponData.WeaponCategory.MELEE)
	failed_damage.target = target
	failed_damage.target_defeated = true
	registry.dispatch_event(&"target_defeated", [target, failed_damage])
	_assert_true(active_runtime.cooldown_remaining > 5.9, "failed Adrenaline keeps cooldown")
	_assert_near(actor.stamina.get_current_sp(), 150.0, "failed Adrenaline keeps SP")

	var foreign_actor := Node3D.new()
	world.add_child(foreign_actor)
	var foreign_damage := _make_damage(actor, &"normal", WeaponData.WeaponCategory.MELEE)
	foreign_damage.source = foreign_actor
	foreign_damage.target = target
	foreign_damage.target_defeated = true
	effect.set_proc_seed(_find_seed(ADRENALINE_SURGE.proc_chance, true))
	registry.dispatch_event(&"target_defeated", [target, foreign_damage])
	_assert_false(
		foreign_damage.has_proc_result(ADRENALINE_SURGE.charm_id),
		"Adrenaline ignores non-player death"
	)
	_assert_true(registry.unequip_socket(CharmConstants.SocketId.SPACE), "unequip Adrenaline")
	_assert_true(registry.unequip_socket(CharmConstants.SocketId.Q), "unequip Active")
	target.queue_free()
	foreign_actor.queue_free()


func _make_damage(actor: MockActor, action: StringName, category: int) -> DamageContext:
	var damage := DamageContext.new()
	damage.source = actor
	damage.source_team = CombatTeams.PLAYER
	damage.base_amount_hp = 10
	damage.amount_hp = 10
	damage.tag = action
	damage.weapon_category = category
	damage.origin = actor.global_position
	return damage


func _find_seed(chance: float, expected: bool) -> int:
	for candidate: int in range(1, 10000):
		var random := RandomNumberGenerator.new()
		random.seed = candidate
		if (random.randf() < chance) == expected:
			return candidate
	_fail("could not find deterministic proc seed")
	return 1


func _on_damage_applied(damage: DamageContext, _target: Node, _applied_hp: int) -> void:
	_damage_event_count += 1
	_last_damage = damage


func _assert_proc(
	damage: DamageContext, charm_id: StringName, success: bool, reason: StringName
) -> void:
	_assert_true(damage.has_proc_result(charm_id), "%s proc result exists" % charm_id)
	if not damage.has_proc_result(charm_id):
		return
	var result: Dictionary = damage.proc_results[charm_id]
	_assert_equal(result.get(&"success"), success, "%s proc success" % charm_id)
	_assert_equal(result.get(&"reason"), reason, "%s proc reason" % charm_id)


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
	push_error("Charm Passive Phase 6: " + message)


class MockActor:
	extends Node3D
	var hp: HealthComponent
	var stamina: StaminaComponent
	var charm_socket_manager: CharmSocketManager

	func setup() -> void:
		hp = HealthComponent.new()
		stamina = StaminaComponent.new()
		add_child(hp)
		add_child(stamina)
		hp.init(10)
		stamina.init(300.0, 0.0, 0.0)


class MockTarget:
	extends Node3D
	var hp: HealthComponent
	var dead: bool = false
	var facing_direction: Vector3 = Vector3.BACK

	func setup(max_hp: int) -> void:
		hp = HealthComponent.new()
		add_child(hp)
		hp.init(max_hp)

	func receive_damage(damage: DamageContext) -> int:
		if hp == null:
			return 0
		var applied := hp.take_damage(damage.amount_hp)
		dead = not hp.is_alive()
		return applied

	func get_facing_direction() -> Vector3:
		return facing_direction

	func is_defeated() -> bool:
		return dead
