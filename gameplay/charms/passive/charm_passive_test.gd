extends SceneTree
## Headless smoke test cho ba Passive stat Charm Phase 5.

const GALE_PACE: CharmData = preload("res://gameplay/charms/charm_data/gale_pace.tres")
const TURTLE_SHELL: CharmData = preload("res://gameplay/charms/charm_data/turtle_shell.tres")
const ENDURANCE_VESSEL: CharmData = preload(
	"res://gameplay/charms/charm_data/endurance_vessel.tres"
)

var _failures: int = 0


func _initialize() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	_test_data()
	var actor := Player.new()
	actor.data = PlayerData.new()
	actor.data.move_speed = 100.0
	actor.hp = HealthComponent.new()
	actor.stamina = StaminaComponent.new()
	actor.add_child(actor.hp)
	actor.add_child(actor.stamina)
	_assert_true(actor.hp.init(10), "initialize HP")
	actor.stamina.init(300.0, 0.0, 0.0)
	var manager := CharmSocketManager.new()
	var registry := CharmRegistry.new()
	manager.actor = actor
	manager.registry = registry
	manager.add_child(registry)
	actor.charm_socket_manager = manager
	root.add_child(manager)
	var definitions: Array[CharmData] = [GALE_PACE, TURTLE_SHELL, ENDURANCE_VESSEL]
	for definition: CharmData in definitions:
		_assert_true(
			registry.register_definition(definition), "register " + definition.display_name
		)
		_assert_true(
			registry.set_owned(definition.charm_id, true), "own " + definition.display_name
		)

	_assert_true(
		registry.equip_charm(GALE_PACE.charm_id, CharmConstants.SocketId.Q, actor),
		"equip Gale Pace"
	)
	_assert_near(_get_move_speed(actor), 120.0, "Gale speed")
	_assert_near(actor.stamina.get_max_sp(), 200.0, "Gale max SP")
	_assert_near(actor.stamina.get_current_sp(), 200.0, "Gale clamps current SP")

	_assert_true(
		registry.equip_charm(TURTLE_SHELL.charm_id, CharmConstants.SocketId.SPACE, actor),
		"equip Turtle Shell"
	)
	_assert_equal(actor.hp.get_max_hp(), 12, "Turtle max HP")
	_assert_near(_get_move_speed(actor), 96.0, "stacked speed multipliers")
	_assert_equal(actor.hp.heal(2), 2, "heal to modified max HP")

	_assert_true(
		registry.equip_charm(ENDURANCE_VESSEL.charm_id, CharmConstants.SocketId.E, actor),
		"equip Endurance Vessel"
	)
	_assert_equal(actor.hp.get_max_hp(), 10, "Endurance offsets Turtle HP")
	_assert_equal(actor.hp.get_current_hp(), 10, "Endurance clamps current HP")
	_assert_near(actor.stamina.get_max_sp(), 400.0, "Endurance offsets Gale SP")
	var turtle_runtime := registry.get_equipped(CharmConstants.SocketId.SPACE)
	turtle_runtime.effect.on_equipped()
	_assert_equal(actor.hp.get_max_hp(), 10, "re-equip hook does not stack HP")
	_assert_near(_get_move_speed(actor), 96.0, "re-equip hook does not stack speed")

	_assert_true(registry.unequip_socket(CharmConstants.SocketId.Q), "unequip Gale Pace")
	_assert_near(actor.stamina.get_max_sp(), 500.0, "Gale removal preserves Endurance")
	_assert_near(_get_move_speed(actor), 80.0, "Gale removal preserves Turtle")
	_assert_true(registry.unequip_socket(CharmConstants.SocketId.SPACE), "unequip Turtle Shell")
	_assert_equal(actor.hp.get_max_hp(), 8, "Turtle removal preserves Endurance")
	_assert_equal(actor.hp.get_current_hp(), 8, "Turtle removal clamps current HP")
	_assert_near(_get_move_speed(actor), 100.0, "Turtle speed penalty removed")
	_assert_true(registry.unequip_socket(CharmConstants.SocketId.E), "unequip Endurance Vessel")
	_assert_equal(actor.hp.get_max_hp(), 10, "base HP restored")
	_assert_near(actor.stamina.get_max_sp(), 300.0, "base SP restored")
	await process_frame
	manager.free()
	actor.free()
	if _failures == 0:
		print("Charm Passive Phase 5: all tests passed")
	quit(0 if _failures == 0 else 1)


func _test_data() -> void:
	var definitions: Array[CharmData] = [GALE_PACE, TURTLE_SHELL, ENDURANCE_VESSEL]
	_assert_equal(CharmValidator.validate_catalog(definitions).size(), 0, "valid catalog")
	_assert_near(GALE_PACE.get_param_float(&"move_speed_multiplier"), 1.2, "Gale speed")
	_assert_near(GALE_PACE.get_param_float(&"max_sp_flat"), -100.0, "Gale SP")
	_assert_equal(TURTLE_SHELL.get_param_int(&"max_hp_flat"), 2, "Turtle HP")
	_assert_near(TURTLE_SHELL.get_param_float(&"move_speed_multiplier"), 0.8, "Turtle speed")
	_assert_near(ENDURANCE_VESSEL.get_param_float(&"max_sp_flat"), 200.0, "Endurance SP")
	_assert_equal(ENDURANCE_VESSEL.get_param_int(&"max_hp_flat"), -2, "Endurance HP")


func _get_move_speed(actor: Player) -> float:
	return float(actor.call("_get_move_speed"))


func _assert_true(value: bool, label: String) -> void:
	if not value:
		_fail(label)


func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_fail("%s: expected %s, got %s" % [label, expected, actual])


func _assert_near(actual: float, expected: float, label: String) -> void:
	if not is_equal_approx(actual, expected):
		_fail("%s: expected %s, got %s" % [label, expected, actual])


func _fail(message: String) -> void:
	_failures += 1
	push_error("Charm Passive Phase 5: " + message)
