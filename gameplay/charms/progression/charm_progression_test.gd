extends SceneTree
## Headless test cho safe location, socket economy, acquisition và snapshot Phase 7.

const ARROW_RAIN: CharmData = preload("res://gameplay/charms/charm_data/arrow_rain.tres")
const CRESCENT_CLEAVE: CharmData = preload("res://gameplay/charms/charm_data/crescent_cleave.tres")
const TIDE_GRAPPLE: CharmData = preload("res://gameplay/charms/charm_data/tide_grapple.tres")
const GALE_PACE: CharmData = preload("res://gameplay/charms/charm_data/gale_pace.tres")
const TURTLE_SHELL: CharmData = preload("res://gameplay/charms/charm_data/turtle_shell.tres")
const ENDURANCE_VESSEL: CharmData = preload(
	"res://gameplay/charms/charm_data/endurance_vessel.tres"
)
const LIFE_STEAL: CharmData = preload("res://gameplay/charms/charm_data/life_steal.tres")
const DOUBLE_STRIKE: CharmData = preload("res://gameplay/charms/charm_data/double_strike.tres")
const ADRENALINE_SURGE: CharmData = preload(
	"res://gameplay/charms/charm_data/adrenaline_surge.tres"
)
const BACKSTABBER: CharmData = preload("res://gameplay/charms/charm_data/backstabber.tres")

var _failures: int = 0


func _initialize() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var actor := MockActor.new()
	world.add_child(actor)
	actor.setup()
	var manager := CharmSocketManager.new()
	var registry := CharmRegistry.new()
	registry.definitions = _get_all_definitions()
	manager.actor = actor
	manager.registry = registry
	manager.loadout = CharmLoadout.new()
	manager.add_child(registry)
	actor.charm_socket_manager = manager
	actor.add_child(manager)
	await process_frame

	_test_safe_location_sources(manager)
	_test_checkpoint_safe_location(manager)
	_test_socket_economy(manager)
	await _test_runtime_debug_inspector(manager, registry)
	_test_acquisition(registry)
	await _test_snapshot(world, manager, registry)

	world.free()
	if _failures == 0:
		print("Charm Progression Phase 7: all tests passed")
	quit(0 if _failures == 0 else 1)


func _test_safe_location_sources(manager: CharmSocketManager) -> void:
	var first := Node.new()
	var second := Node.new()
	root.add_child(first)
	root.add_child(second)
	_assert_false(manager.can_change_loadout(), "loadout starts unsafe")
	manager.enter_safe_location(first)
	manager.enter_safe_location(second)
	_assert_true(manager.can_change_loadout(), "safe source enables loadout")
	manager.exit_safe_location(first)
	_assert_true(manager.can_change_loadout(), "second safe source remains active")
	manager.exit_safe_location(second)
	_assert_false(manager.can_change_loadout(), "last source exit disables loadout")
	first.free()
	second.free()
	var transient := Node.new()
	root.add_child(transient)
	manager.enter_safe_location(transient)
	transient.free()
	_assert_false(manager.can_change_loadout(), "freed safe source removes permission")


func _test_checkpoint_safe_location(manager: CharmSocketManager) -> void:
	var player := Player.new()
	player.charm_socket_manager = manager
	var checkpoint := Checkpoint.new()
	checkpoint.call("_on_body_entered", player)
	_assert_true(manager.can_change_loadout(), "checkpoint entry enables loadout")
	checkpoint.call("_on_body_exited", player)
	_assert_false(manager.can_change_loadout(), "checkpoint exit disables loadout")
	checkpoint.free()
	player.free()


func _test_socket_economy(manager: CharmSocketManager) -> void:
	var service := CharmSocketUnlockService.new()
	var economy := MockEconomy.new(150)
	_assert_false(service.purchase_next_socket(manager, economy, 50), "unsafe unlock rejected")
	_assert_equal(economy.balance, 150, "unsafe unlock keeps currency")
	manager.set_safe_location(true)
	_assert_false(
		service.purchase_next_socket(manager, economy, 200), "insufficient unlock rejected"
	)
	_assert_equal(economy.balance, 150, "insufficient unlock keeps currency")
	_assert_true(service.purchase_next_socket(manager, economy, 50), "purchase socket two")
	_assert_equal(manager.get_unlocked_socket_count(), 2, "socket two unlocked")
	_assert_equal(economy.balance, 100, "socket two cost paid")
	_assert_true(service.purchase_next_socket(manager, economy, 100), "purchase socket three")
	_assert_equal(manager.get_unlocked_socket_count(), 3, "socket three unlocked")
	_assert_equal(economy.balance, 0, "socket three cost paid")
	_assert_false(service.purchase_next_socket(manager, economy, 0), "fourth socket rejected")
	_assert_equal(economy.balance, 0, "max socket rejection keeps currency")
	var failing_manager := FailingUnlockManager.new()
	var rollback_economy := MockEconomy.new(25)
	_assert_false(
		service.purchase_next_socket(failing_manager, rollback_economy, 25),
		"unexpected unlock failure rejected"
	)
	_assert_equal(rollback_economy.balance, 25, "unexpected unlock failure refunded")
	failing_manager.free()


func _test_acquisition(registry: CharmRegistry) -> void:
	var service := CharmAcquisitionService.new()
	var placeholder := CharmData.new()
	placeholder.charm_id = &"placeholder_passive"
	placeholder.display_name = "Placeholder Passive"
	placeholder.charm_type = CharmConstants.CharmType.PASSIVE
	placeholder.acquisition_source = &"shop"
	_assert_true(registry.register_definition(placeholder), "register blocked placeholder")
	var pool := service.get_shop_pool(registry)
	_assert_equal(pool.size(), 7, "shop contains seven accepted Passive Charms")
	for definition: CharmData in pool:
		_assert_true(definition.is_passive(), "shop excludes Active Charms")
		_assert_true(definition.effect_scene != null, "shop excludes placeholders")
	_assert_true(registry.set_owned(GALE_PACE.charm_id, true), "own Gale Pace")
	_assert_equal(service.get_shop_pool(registry).size(), 6, "shop excludes owned Charm")
	var random := RandomNumberGenerator.new()
	random.seed = 7007
	var offer := service.roll_shop_offer(registry, random)
	_assert_true(offer != null and offer.is_passive(), "seeded shop offer is playable Passive")
	_assert_true(
		service.grant_fixed_boss_reward(registry, TIDE_GRAPPLE.charm_id),
		"grant fixed Tide Grapple reward"
	)
	_assert_true(registry.is_owned(TIDE_GRAPPLE.charm_id), "fixed boss reward owned")
	_assert_false(
		service.grant_fixed_boss_reward(registry, ARROW_RAIN.charm_id),
		"non-boss metadata cannot use fixed reward"
	)


func _test_runtime_debug_inspector(manager: CharmSocketManager, registry: CharmRegistry) -> void:
	manager.set(&"debug_socket", CharmConstants.SocketId.Q)
	manager.set(&"debug_charm", GALE_PACE.display_name)
	await process_frame
	_assert_equal(
		manager.get_equipped_charm(CharmConstants.SocketId.Q),
		GALE_PACE.charm_id,
		"runtime inspector equips selected Charm",
	)
	_assert_false(registry.is_owned(GALE_PACE.charm_id), "debug equip does not grant ownership")
	manager.set(&"debug_charm", "<Unequip>")
	await process_frame
	_assert_equal(
		manager.get_equipped_charm(CharmConstants.SocketId.Q),
		&"",
		"runtime inspector clears selected socket",
	)


func _test_snapshot(world: Node3D, manager: CharmSocketManager, registry: CharmRegistry) -> void:
	_assert_true(registry.set_owned(LIFE_STEAL.charm_id, true), "own Life Steal")
	_assert_true(manager.equip_charm(LIFE_STEAL.charm_id, CharmConstants.SocketId.Q), "equip Q")
	_assert_true(
		manager.equip_charm(GALE_PACE.charm_id, CharmConstants.SocketId.SPACE), "equip Space"
	)
	_assert_true(manager.equip_charm(TIDE_GRAPPLE.charm_id, CharmConstants.SocketId.E), "equip E")
	var payload := CharmProgressionSnapshot.capture(manager, registry)
	_assert_equal(payload.get("version"), 1, "snapshot version")
	_assert_equal(payload.get("unlocked_socket_count"), 3, "snapshot socket count")

	var restored_actor := MockActor.new()
	world.add_child(restored_actor)
	restored_actor.setup()
	var restored_manager := CharmSocketManager.new()
	var restored_registry := CharmRegistry.new()
	restored_registry.definitions = _get_all_definitions()
	restored_manager.actor = restored_actor
	restored_manager.registry = restored_registry
	restored_manager.loadout = CharmLoadout.new()
	restored_manager.add_child(restored_registry)
	restored_actor.charm_socket_manager = restored_manager
	restored_actor.add_child(restored_manager)
	await process_frame
	_assert_true(
		CharmProgressionSnapshot.restore(payload, restored_manager, restored_registry),
		"restore valid snapshot"
	)
	_assert_equal(restored_manager.get_unlocked_socket_count(), 3, "restored socket count")
	_assert_true(restored_registry.is_owned(LIFE_STEAL.charm_id), "restored owned ID")
	_assert_equal(
		restored_manager.get_equipped_charm(CharmConstants.SocketId.Q),
		LIFE_STEAL.charm_id,
		"restored Q"
	)
	_assert_equal(
		restored_manager.get_equipped_charm(CharmConstants.SocketId.SPACE),
		GALE_PACE.charm_id,
		"restored Space"
	)
	_assert_equal(
		restored_manager.get_equipped_charm(CharmConstants.SocketId.E),
		TIDE_GRAPPLE.charm_id,
		"restored E"
	)

	var corrupt_payload := {
		"version": 999,
		"unlocked_socket_count": 99,
		"owned_charm_ids": [String(LIFE_STEAL.charm_id), "missing_charm"],
		"equipped_charm_ids":
		["missing_charm", String(LIFE_STEAL.charm_id), String(LIFE_STEAL.charm_id)],
	}
	_assert_true(
		CharmProgressionSnapshot.restore(corrupt_payload, restored_manager, restored_registry),
		"restore corrupt snapshot with fallback"
	)
	_assert_equal(restored_manager.get_unlocked_socket_count(), 3, "corrupt count clamped")
	_assert_false(restored_registry.is_owned(&"missing_charm"), "unknown owned ID ignored")
	_assert_equal(
		restored_manager.get_equipped_charm(CharmConstants.SocketId.Q), &"", "unknown equip ignored"
	)
	_assert_equal(
		restored_manager.get_equipped_charm(CharmConstants.SocketId.SPACE),
		LIFE_STEAL.charm_id,
		"valid corrupt entry restored"
	)
	_assert_equal(
		restored_manager.get_equipped_charm(CharmConstants.SocketId.E),
		&"",
		"duplicate corrupt equip ignored"
	)
	restored_actor.queue_free()


func _get_all_definitions() -> Array[CharmData]:
	return [
		ARROW_RAIN,
		CRESCENT_CLEAVE,
		TIDE_GRAPPLE,
		GALE_PACE,
		TURTLE_SHELL,
		ENDURANCE_VESSEL,
		LIFE_STEAL,
		DOUBLE_STRIKE,
		ADRENALINE_SURGE,
		BACKSTABBER,
	]


func _assert_true(value: bool, label: String) -> void:
	if not value:
		_fail(label)


func _assert_false(value: bool, label: String) -> void:
	_assert_true(not value, label)


func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_fail("%s: expected %s, got %s" % [label, expected, actual])


func _fail(message: String) -> void:
	_failures += 1
	push_error("Charm Progression Phase 7: " + message)


class MockActor:
	extends Node3D
	var dead: bool = false
	var team: int = CombatTeams.PLAYER
	var hp: HealthComponent
	var stamina: StaminaComponent
	var charm_socket_manager: CharmSocketManager
	var weapon_controller: WeaponController

	func setup() -> void:
		hp = HealthComponent.new()
		stamina = StaminaComponent.new()
		add_child(hp)
		add_child(stamina)
		hp.init(10)
		stamina.init(500.0, 0.0, 0.0)

	func build_attack_context() -> AttackContext:
		var context := AttackContext.new()
		context.actor = self
		context.team = team
		context.direction = Vector3.BACK
		return context


class MockEconomy:
	extends CharmEconomyAdapter
	var balance: int

	func _init(starting_balance: int) -> void:
		balance = starting_balance

	func can_afford(amount: int) -> bool:
		return amount >= 0 and balance >= amount

	func try_spend(amount: int) -> bool:
		if not can_afford(amount):
			return false
		balance -= amount
		return true

	func refund(amount: int) -> void:
		balance += maxi(0, amount)


class FailingUnlockManager:
	extends CharmSocketManager

	func can_change_loadout() -> bool:
		return true

	func can_unlock_next_socket() -> bool:
		return true

	func unlock_next_socket() -> bool:
		return false
