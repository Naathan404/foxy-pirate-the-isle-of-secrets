extends SceneTree
## Kiểm tra giao tiếp giữa component thật và các phần HUD sau khi tách script.

const HUD_SCENE: PackedScene = preload("res://gameplay/player/hud/player_hud.tscn")

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _run() -> void:
	var world := Node.new()
	root.add_child(world)
	current_scene = world
	var health := HealthComponent.new()
	var stamina := StaminaComponent.new()
	var chaos := ChaosComponent.new()
	world.add_child(health)
	world.add_child(stamina)
	world.add_child(chaos)
	health.init(8)
	stamina.init(350.0, 0.0, 0.0)
	chaos.init(100.0)
	var hud := HUD_SCENE.instantiate() as CanvasLayer
	hud.set("health", health)
	hud.set("stamina", stamina)
	hud.set("chaos", chaos)
	world.add_child(hud)
	await process_frame
	await process_frame
	var hp := hud.get_node("Stats/HealthArc") as HudStatArc
	var sp := hud.get_node("Stats/StaminaArc") as HudStatArc
	var cp := hud.get_node("Stats/ChaosArc") as HudStatArc
	var portrait := hud.get_node("StatControl/Portrait") as HudPortrait
	var tooltip := hud.get_node("StatTooltip") as HudTooltip
	_check(
		hp.fill.value == 8.0 and sp.fill.value == 350.0 and cp.fill.value == 0.0,
		"HUD must synchronize all component values after ready"
	)
	_check(cp.readiness_icon.modulate == cp.unavailable_tint, "Empty CP must dim skill icon")
	_check(tooltip.bars.size() == 3, "Tooltip must receive all three arc references")

	chaos.gain(100.0)
	stamina.try_consume(50.0)
	health.take_damage(6)
	_check(portrait.modulate == Color(1.0, 0.35, 0.35), "Damage must trigger portrait hit feedback")
	_check(cp.value_label.text == "CP: 100 / 100", "Chaos label must update from component signal")
	_check(cp.readiness_icon.modulate == Color.WHITE, "Full CP must light skill icon")
	await create_timer(0.9).timeout
	_check(
		hp.fill.value == 2.0 and sp.fill.value == 300.0 and cp.fill.value == 100.0,
		"Animated bars must settle at the requested values"
	)
	_check(not cp.fill_effect.white_fill.visible, "White fill must disappear after animation")
	_check(
		portrait.modulate == Color(1.0, 0.65, 0.65), "Hit portrait must return to low-health state"
	)

	for arc: HudStatArc in [hp, sp, cp]:
		await _test_tooltip(tooltip, arc.capacity)

	health.set_max_hp_modifier(&"hud_test", 2)
	stamina.set_max_sp_modifier(&"hud_test", 200.0)
	_check(
		hp.capacity.max_value == 10.0 and sp.capacity.max_value == 550.0,
		"Changing maximum stats must update arc capacities"
	)
	_check(
		is_equal_approx(hp.capacity.radial_fill_degrees, 112.5),
		"Health arc length must reflect new maximum"
	)
	_check(
		cp.capacity.radial_initial_angle == 225.0 and cp.capacity.radial_fill_degrees == 135.0,
		"Chaos must keep its own arc layout"
	)
	health.heal(8)
	_check(portrait.modulate == Color.WHITE, "Healing must restore healthy portrait")
	_check(chaos.try_consume_full(), "Full chaos must be consumable")
	_check(cp.readiness_icon.modulate == cp.unavailable_tint, "Spending CP must dim skill icon")
	await create_timer(0.9).timeout
	_check(
		cp.fill.value == 0.0 and not cp.fill_effect.white_fill.visible,
		"Chaos drain must settle at zero and clear white fill"
	)
	chaos.init(0.0)
	_check(
		cp.capacity.radial_fill_degrees == 0.0 and cp.readiness_icon.modulate != Color.WHITE,
		"Zero capacity must hide the arc and never show readiness"
	)

	health.take_damage(100)
	_check(portrait.modulate == Color(0.45, 0.45, 0.45), "Death must override hit portrait")
	_check(not portrait.is_processing(), "Death must stop portrait shaking")
	world.queue_free()
	await process_frame
	# The HUD scene must still work by itself without assigned gameplay components.
	var preview := HUD_SCENE.instantiate() as CanvasLayer
	root.add_child(preview)
	await process_frame
	await process_frame
	_check(
		(preview.get_node("Stats/HealthArc") as HudStatArc).fill.max_value > 0.0,
		"Standalone HUD preview must initialize"
	)
	preview.queue_free()
	await process_frame
	print("HUD integration checks: ", "PASS" if _failures == 0 else "FAIL (%d)" % _failures)
	quit(0 if _failures == 0 else 1)


func _test_tooltip(tooltip: HudTooltip, bar: ArcTooltipBar) -> void:
	var point := Vector2.ZERO
	var found := false
	for y in range(0, int(bar.size.y), 2):
		for x in range(0, int(bar.size.x), 2):
			var candidate := Vector2(x, y)
			if bar._has_point(candidate):
				point = bar.get_global_transform_with_canvas() * candidate
				found = true
				break
		if found:
			break
	_check(found, "Arc must contain a hoverable pixel")
	if not found:
		return
	var motion := InputEventMouseMotion.new()
	motion.position = point
	# Points are already in viewport coordinates; bypass headless window stretching.
	root.push_input(motion, true)
	await create_timer(0.05).timeout
	_check(not tooltip.visible, "Tooltip must wait for hover delay")
	await create_timer(0.25).timeout
	_check(
		tooltip.visible and tooltip.value_label.text == bar.get_stat_tooltip(),
		"Hover must display the matching stat tooltip with scaled HUD coordinates"
	)
	motion = InputEventMouseMotion.new()
	motion.position = Vector2(640, 360)
	root.push_input(motion, true)
	await create_timer(0.05).timeout
	_check(not tooltip.visible, "Tooltip must hide when pointer leaves the arc")
