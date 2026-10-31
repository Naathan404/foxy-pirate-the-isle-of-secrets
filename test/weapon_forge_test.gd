extends SceneTree

const POOL: WeaponForgePool = preload("res://data/weapon/forges/shared_pool.tres")
# SP-paying attack: damage, speed, range, startup, recovery, SP, melee hitbox, projectile range.
const EXPECTED: Dictionary = {
	&"pristine": [1, 1, 1, 1, 1, 1, 1, 1],
	&"heavy_edge": [1.3, 0.8, 1, 1, 1, 1, 1, 1],
	&"swift_flow": [0.8, 1.3, 1, 1, 1, 1, 1, 1],
	&"brittle_force": [1.5, 0.65, 1, 1, 1, 1, 1, 1],
	&"long_reach": [0.88, 1, 1.25, 1, 1, 1, 1, 1],
	&"close_quarters": [1.25, 1, 0.75, 1, 1, 1, 1, 1],
	&"quickdraw": [1, 1, 1, 0.7, 1.2, 1, 1, 1],
	&"measured_strike": [1, 1, 1, 1.2, 0.7, 1, 1, 1],
	&"keen_edge": [0.9, 1, 1, 1, 1, 1, 1, 1],
	&"blunt_impact": [1.15, 1, 1, 1, 1, 1, 1, 1],
	&"sharpened_soul": [1.5, 0.8, 1, 1, 1, 1, 1, 1],
	&"brutal_core": [2.0, 0.6, 1, 1, 1, 1, 1, 1],
	&"leviathans_fang": [3.0, 0.4, 1, 1, 1.2, 1, 1, 1],
	&"rusted_blade": [0.8, 0.85, 1, 1, 1, 1, 1, 1],
	&"broken_edge": [0.5, 0.9, 1, 1, 1, 1, 1, 1],
	&"crippling_weight": [1.6, 0.65, 1, 1, 1.2, 1, 1, 1],
	&"cursed_scrap": [0.85, 0.85, 1, 1, 1, 1, 1, 1],
	&"doomsday_edge": [2.0, 0.45, 1, 1, 1, 1, 1, 1],
	&"frenzied_steel": [0.6, 1.7, 1, 1, 1, 1, 1, 1],
	&"hollow_edge": [0.5, 1.9, 1, 1, 1, 1, 1, 1],
	&"overcharge": [1.2, 1, 1, 1, 1, 1.4, 1, 1],
	&"titan_sweep": [1, 0.9, 1, 1, 1, 1, 1.3, 1],
	&"true_flight": [0.88, 1.1, 1, 1, 1, 1, 1, 1.25],
	&"arcane_efficiency": [0.85, 1, 1, 1, 1, 0.7, 1, 1],
	&"sniper_sight": [1, 0.85, 1, 1, 1, 1, 1, 1.3],
	&"misaligned_shot": [0.9, 1, 1, 1, 1, 1, 1, 1],
}
const WEIGHTS: Dictionary[StringName, int] = {
	&"pristine": 3,
	&"heavy_edge": 8,
	&"swift_flow": 8,
	&"brittle_force": 4,
	&"long_reach": 6,
	&"close_quarters": 6,
	&"quickdraw": 5,
	&"measured_strike": 5,
	&"keen_edge": 5,
	&"blunt_impact": 5,
	&"sharpened_soul": 5,
	&"brutal_core": 5,
	&"leviathans_fang": 1,
	&"rusted_blade": 4,
	&"broken_edge": 3,
	&"crippling_weight": 3,
	&"cursed_scrap": 3,
	&"doomsday_edge": 2,
	&"frenzied_steel": 3,
	&"hollow_edge": 3,
	&"overcharge": 3,
	&"titan_sweep": 3,
	&"true_flight": 3,
	&"arcane_efficiency": 2,
	&"sniper_sight": 2,
	&"misaligned_shot": 2,
}

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_pool()
	var world := Node3D.new()
	root.add_child(world)
	_test_attacks(world)
	root.get_node("AudioManager").stop_all_sfx()
	world.free()
	await create_timer(0.1).timeout
	if _failures == 0:
		print("Shared forge pool, all 26 modifiers, all weapon categories and attack timing passed")
	quit(0 if _failures == 0 else 1)


func _test_pool() -> void:
	_check(POOL.is_valid() and POOL.forges.size() == 26, "Shared pool contains 26 valid forges")
	var random := RandomNumberGenerator.new()
	random.seed = 7421
	var replay := RandomNumberGenerator.new()
	replay.seed = 7421
	var seen: Dictionary[StringName, bool] = {}
	for index in 1000:
		var forge := POOL.roll(random)
		_check(forge == POOL.roll(replay), "Seeded rolls reproduce the same sequence")
		seen[forge.forge_id] = true
	_check(seen.size() == 26, "Every forge is reachable in the same pool")
	_check(POOL.get_forge(&"missing") == null, "Unknown forge ID is absent")
	var universal_count := 0
	var total_weight := 0.0
	for forge: WeaponForge in POOL.forges:
		_near(forge.drop_weight, WEIGHTS[forge.forge_id], "Balanced weight for " + forge.forge_id)
		total_weight += forge.drop_weight
		if forge.forge_group == WeaponForge.ForgeGroup.UNIVERSAL:
			universal_count += 1
	_near(total_weight, 102.0, "Authored weights sum to 102 and roll relatively")
	_check(universal_count == 20, "Pool has 20 Universal and 6 Wildcard entries")
	var weighted := WeaponForgePool.new()
	var disabled := POOL.forges[0].duplicate() as WeaponForge
	var enabled := POOL.forges[1].duplicate() as WeaponForge
	disabled.drop_weight = 0.0
	enabled.drop_weight = 3.0
	weighted.forges = [disabled, enabled]
	for index in 30:
		_check(weighted.roll(random) == enabled, "Zero weight never rolls")
	enabled.drop_weight = 0.0
	_check(weighted.roll(random) == null, "Disabled pool cannot roll")
	weighted.forges = [enabled, enabled]
	_check(not weighted.is_valid(), "Duplicate IDs invalidate the pool")
	weighted.forges.clear()
	_check(weighted.roll(random) == null, "Empty pool cannot roll")
	_check(POOL.roll(null) == null, "Missing RNG is rejected")
	for category: int in WeaponData.WeaponCategory.values():
		var weapon := WeaponInstance.new()
		weapon.definition = WeaponData.new()
		weapon.definition.category = category
		for index in 30:
			_check(weapon.reforge(POOL, random), "All weapon categories use the shared pool")
			_check(POOL.forges.has(weapon.forge), "Weapon has one forge from the catalog")
		var previous := weapon.forge
		_check(not weapon.reforge(weighted, random), "Failed reforge is rejected")
		_check(weapon.forge == previous, "Failed reforge preserves the previous forge")


func _test_attacks(world: Node3D) -> void:
	var actor := ForgeActor.new()
	world.add_child(actor)
	var stamina := StaminaComponent.new()
	actor.add_child(stamina)
	stamina.init(100000.0, 0.0, 0.0)
	var chaos := ChaosComponent.new()
	actor.add_child(chaos)
	chaos.init(100.0)
	var controller := WeaponController.new()
	actor.add_child(controller)
	controller.chaos = chaos
	_check(controller.setup(actor, stamina), "Controller fixture initializes")
	var data := load("res://data/weapon/weapon_dagger.tres").duplicate(true) as WeaponData
	var starter := WeaponController.new()
	actor.add_child(starter)
	starter.default_weapon = data
	starter.default_forge = POOL.get_forge(&"quickdraw")
	_check(starter.setup(actor, stamina), "Controller accepts an initial forge from Inspector")
	_check(starter.equipped.forge == starter.default_forge, "Initial forge reaches weapon instance")
	starter.free()
	data.normal_attack.damage_hp = 1.0
	data.normal_attack.range_units = 10.0
	data.normal_attack.stamina_cost = 10.0
	data.normal_attack.cooldown_seconds = 0.5
	data.normal_attack.combo_steps[0].windup_seconds = 0.2
	data.normal_attack.combo_steps[0].active_seconds = 0.1
	data.normal_attack.combo_steps[0].recovery_seconds = 0.3
	data.normal_attack.combo_steps[0].damage_multiplier = 1.0
	data.secondary_attack.damage_hp = 1.0
	data.secondary_attack.stamina_cost = 10.0
	for category: int in WeaponData.WeaponCategory.values():
		data.category = category
		for forge: WeaponForge in POOL.forges:
			var expected: Array = EXPECTED[forge.forge_id]
			var weapon := WeaponInstance.new()
			weapon.definition = data
			weapon.forge = forge
			_check(controller.equip(weapon), "Forge is accepted independently of weapon category")
			var before := stamina.get_current_sp()
			var request := AttackContext.new()
			_check(controller.try_attack(request), "Forged melee attack starts")
			var context := controller._context
			_near(context.damage_hp, expected[0], "Authored fractional damage applies")
			_near(context.range_units, 10.0 * expected[2], "Melee range excludes projectile bonus")
			_near(context.hitbox_multiplier, expected[6], "Melee-only hitbox modifier applies")
			_near(before - stamina.get_current_sp(), 10.0 * expected[5], "SP multiplier applies")
			_near(controller._windup, 0.2 * expected[3] / expected[1], "Combo startup timing")
			_near(controller._active, 0.1 / expected[1], "Attack speed scales active timing")
			_near(controller._recovery, 0.3 * expected[4] / expected[1], "Combo recovery timing")
			_near(weapon.cooldowns[&"normal"], 0.5 / expected[1], "Speed scales cooldown")
			controller.cancel()
			chaos.gain(chaos.maximum)
			request = AttackContext.new()
			request.action = &"secondary"
			_check(controller.try_attack(request), "Same forge supports projectile attack")
			context = controller._context
			_near(context.range_units, 10.0 * expected[2] * expected[7], "Projectile range applies")
			_near(context.hitbox_multiplier, 1.0, "Melee bonus never enlarges projectile hitbox")
			_near(controller._windup, 0.15 * expected[3] / expected[1], "Non-combo startup timing")
			_near(
				controller._recovery, 0.2 * expected[4] / expected[1], "Non-combo recovery timing"
			)
			controller.cancel()
	_near(data.normal_attack.damage_hp, 1.0, "Forging never mutates base damage")
	_near(data.normal_attack.range_units, 10.0, "Forging never mutates base range")
	_near(data.normal_attack.combo_steps[0].windup_seconds, 0.2, "Combo data stays immutable")
	_test_execution(controller, chaos)
	# A forge is snapshotted when accepted; replacing it must not change a running attack.
	controller.equipped.forge = POOL.get_forge(&"heavy_edge")
	controller.equipped.cooldowns.clear()
	_check(controller.try_attack(AttackContext.new()), "Snapshot fixture starts")
	var snapshot := controller._context
	var duration := controller.get_attack_duration()
	controller.equipped.forge = POOL.get_forge(&"broken_edge")
	_near(snapshot.damage_hp, 1.3, "In-flight damage survives forge replacement")
	_near(controller.get_attack_duration(), duration, "In-flight timing survives forge replacement")
	controller.cancel()
	controller.equipped.forge = WeaponForge.new()
	controller.equipped.forge.damage_multiplier = -1.0
	_check(not controller.try_attack(AttackContext.new()), "Invalid forge rejects attack")
	_test_overcharge(controller, chaos)
	_test_critical_stats(controller)


func _test_critical_stats(controller: WeaponController) -> void:
	var weapon := controller.equipped
	weapon.definition.critical_rate = 0.05
	var attack := weapon.definition.normal_attack
	for fixture: Array in [
		[&"keen_edge", 0.20],
		[&"blunt_impact", 0.0],
		[&"cursed_scrap", 0.0],
		[&"sniper_sight", 0.10]
	]:
		weapon.forge = POOL.get_forge(fixture[0])
		var context := controller._make_context(AttackContext.new(), attack)
		_near(context.critical_rate, fixture[1], "Forge adds percentage points and clamps chance")
		weapon.forge = POOL.get_forge(&"pristine")
		_near(
			context.create_damage_context().critical_rate,
			fixture[1],
			"Critical chance stays snapshotted"
		)
	weapon.definition.critical_rate = 0.95
	weapon.forge = POOL.get_forge(&"keen_edge")
	_near(
		controller._make_context(AttackContext.new(), attack).critical_rate,
		1.0,
		"Chance caps at 100 percent"
	)
	weapon.definition.critical_rate = 0.05
	weapon.forge = POOL.get_forge(&"misaligned_shot")
	var context := controller._make_context(AttackContext.new(), weapon.definition.secondary_attack)
	_near(context.projectile_speed_multiplier, 0.6, "Projectile speed penalty is snapshotted")


func _test_execution(controller: WeaponController, chaos: ChaosComponent) -> void:
	controller.equipped.forge = POOL.get_forge(&"titan_sweep")
	controller.equipped.cooldowns.clear()
	_check(controller.try_attack(AttackContext.new()), "Titan Sweep execution starts")
	controller._physics_process(controller._windup)
	var melee := controller._execution as DaggerAttack
	_near(melee.hitbox.scale.x, 1.3, "Titan Sweep enlarges the actual melee hitbox")
	controller.cancel()
	controller.equipped.forge = POOL.get_forge(&"true_flight")
	controller.equipped.cooldowns.clear()
	chaos.gain(chaos.maximum)
	var request := AttackContext.new()
	request.action = &"secondary"
	_check(controller.try_attack(request), "True Flight projectile starts")
	var projectile := controller._execution
	projectile.set("launch_hitstop", 0.0)
	projectile.set("launch_shake", 0.0)
	controller._physics_process(controller._windup)
	_near(projectile.get("max_distance"), 12.5, "True Flight extends actual projectile flight")
	_near(projectile.get_node("HitBox").scale.x, 1.0, "Projectile retains its original hitbox")
	controller.cancel()
	# Attack delivery, rather than weapon category, controls the two specialized bonuses.
	var area := controller.equipped.definition.normal_attack.duplicate(true) as AttackData
	area.delivery_type = AttackData.DeliveryType.AREA
	controller.equipped.forge = POOL.get_forge(&"true_flight")
	var area_context := controller._make_context(AttackContext.new(), area)
	_near(area_context.range_units, 10.0, "Area attack excludes projectile range bonus")
	controller.equipped.forge = POOL.get_forge(&"titan_sweep")
	area_context = controller._make_context(AttackContext.new(), area)
	_near(area_context.hitbox_multiplier, 1.0, "Area attack excludes melee hitbox bonus")


func _test_overcharge(controller: WeaponController, chaos: ChaosComponent) -> void:
	var weapon := WeaponInstance.new()
	weapon.definition = controller.equipped.definition.duplicate(true)
	weapon.forge = POOL.get_forge(&"overcharge")
	_check(controller.equip(weapon), "Overcharge boundary fixture equips")
	var normal := weapon.definition.normal_attack
	normal.stamina_cost = 0.0
	weapon.definition.secondary_attack.stamina_cost = 0.0
	_check_overcharge_attack(controller, &"normal", 1.2, 0.0, "Free attack receives damage bonus")
	chaos.gain(chaos.maximum)
	_check_overcharge_attack(
		controller, &"secondary", 1.2, 0.0, "CP-only attack receives damage bonus"
	)
	_near(chaos.current, 0.0, "CP cost remains unchanged")
	var ammo := AmmoComponent.new()
	controller.actor.add_child(ammo)
	ammo.add_ammo(&"forge_test_arrow", 2)
	controller.ammo = ammo
	normal.ammo_id = &"forge_test_arrow"
	normal.ammo_cost = 1
	_check_overcharge_attack(controller, &"normal", 1.2, 0.0, "Ammo attack receives damage bonus")
	_check(ammo.get_amount(&"forge_test_arrow") == 1, "Ammo cost remains unchanged")
	normal.ammo_cost = 0
	normal.ammo_id = &""
	normal.stamina_cost = 10.0
	_check_overcharge_attack(controller, &"normal", 1.2, 14.0, "SP attack gets bonus and surcharge")
	controller.stamina.try_consume(controller.stamina.get_current_sp() - 13.0)
	weapon.cooldowns.clear()
	_check(not controller.try_attack(AttackContext.new()), "Surcharge cannot exceed available SP")
	_near(controller.stamina.get_current_sp(), 13.0, "Rejected attack never spends partial SP")
	weapon.forge = weapon.forge.duplicate()
	weapon.forge.stamina_cost_multiplier = 0.0
	_check_overcharge_attack(
		controller, &"normal", 1.2, 0.0, "Attack with zero effective SP cost receives damage bonus"
	)
	_near(
		POOL.get_forge(&"overcharge").stamina_cost_multiplier,
		1.4,
		"Boundary fixture does not mutate the shared forge"
	)


func _check_overcharge_attack(
	controller: WeaponController, action: StringName, damage: float, sp_cost: float, message: String
) -> void:
	controller.equipped.cooldowns.clear()
	var request := AttackContext.new()
	request.action = action
	var before := controller.stamina.get_current_sp()
	var accepted := controller.try_attack(request)
	_check(accepted, message + ": attack accepted")
	if accepted:
		_near(controller._context.damage_hp, damage, message + ": damage")
		_near(before - controller.stamina.get_current_sp(), sp_cost, message + ": SP")
	controller.cancel()


func _near(actual: float, expected: float, message: String) -> void:
	_check(
		is_equal_approx(actual, expected), "%s: expected %s, got %s" % [message, expected, actual]
	)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


class ForgeActor:
	extends Node3D
	var charm_socket_manager: CharmSocketManager
