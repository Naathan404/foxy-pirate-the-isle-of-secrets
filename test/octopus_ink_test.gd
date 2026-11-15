extends SceneTree

const OCTOPUS_SCENE: PackedScene = preload("res://world/biomes/coral_valley/objects/octopus.tscn")

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var player := (load("res://gameplay/player/foxy.tscn") as PackedScene).instantiate() as Player
	world.add_child(player)
	var octopus := OCTOPUS_SCENE.instantiate() as DestructibleProp
	world.add_child(octopus)
	var recovery_time: float = octopus.get("defeat_hold_time") + octopus.get("defeat_fade_time")
	var damage := DamageContext.new()
	damage.source = player
	damage.source_team = CombatTeams.PLAYER
	damage.amount_hp = 1.0
	check(octopus.receive_damage(damage) > 0.0, "Octopus accepts player damage")
	var ink = player.get_node_or_null("OctopusInkOverlay")
	check(ink != null and ink._overlay.visible, "A surviving hit creates a visible ink overlay")
	check(ink._overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Ink does not block input")
	check(not ink._fatal_active, "First hit is a normal splash")
	var first_seed: float = ink._material.get_shader_parameter("splash_seed")
	ink._tween.pause()
	ink._tween.custom_step(octopus.hit_spread_time + 0.01)
	check(is_equal_approx(ink.coverage, ink.HIT_COVERAGE), "Hit remains a partial splatter")
	check(
		is_equal_approx(float(ink._material.get_shader_parameter("splash_seed")), first_seed),
		"Splatter stays still between hits"
	)
	check(octopus.receive_damage(damage) > 0.0, "Second hit is accepted")
	check(
		not is_equal_approx(float(ink._material.get_shader_parameter("splash_seed")), first_seed),
		"New hit chooses a new splatter"
	)
	check(octopus.receive_damage(damage) > 0.0, "Killing hit is accepted")
	check(ink._fatal_active, "Killing hit switches to full-screen ink")
	ink._tween.pause()
	ink._tween.custom_step(octopus.defeat_spread_time + 0.01)
	await create_timer(octopus.hit_flash_hold_duration + octopus.hit_flash_duration + 0.05).timeout
	check(is_equal_approx(ink.coverage, ink.FULL_COVERAGE), "Defeat ink reaches full coverage")
	check(ink._overlay.visible, "Defeat ink survives destruction of the octopus")
	var second := OCTOPUS_SCENE.instantiate() as DestructibleProp
	world.add_child(second)
	var defeat_seed: float = ink._material.get_shader_parameter("splash_seed")
	second.receive_damage(damage)
	check(ink._fatal_active, "Normal hit cannot shorten an active defeat effect")
	check(
		is_equal_approx(float(ink._material.get_shader_parameter("splash_seed")), defeat_seed),
		"Ignored hits do not change the defeat splatter"
	)
	ink._tween.custom_step(recovery_time + 0.2)
	check(not ink._overlay.visible, "Ink clears after recovery")
	world.queue_free()
	await process_frame
	print("Octopus ink: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
