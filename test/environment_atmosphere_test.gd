extends SceneTree
const PLAYER: PackedScene = preload("res://gameplay/player/foxy.tscn")
var failures := 0

func _initialize() -> void:
	call_deferred("run_test")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func run_test() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var player := PLAYER.instantiate() as Player
	world.add_child(player)
	var effect = player.get_node("Effects/EnvironmentAtmosphere")
	var vignette = player.get_node("Effects/LowHealthVignette")
	effect.set_process(false)
	check(effect.player == player, "atmosphere is connected to player")
	check(effect._overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "overlay never blocks controls")
	check(is_zero_approx(effect._water_amount), "water effect starts dry")
	player.environment_is_water = true
	effect._process(effect.water_fade_in * 0.5)
	check(is_equal_approx(effect._water_amount, 0.5), "water fades in smoothly")
	effect._process(effect.water_fade_in * 0.5)
	check(is_equal_approx(effect._water_amount, 1.0), "water reaches full effect")
	player.hp.take_damage(player.hp.get_max_hp() * 0.8)
	check(vignette._active, "low health vignette remains active in water")
	check(is_equal_approx(float(effect._material.get_shader_parameter("water_amount")), 1.0), "water overlay remains active at low health")
	player.environment_is_water = false
	effect._process(effect.water_fade_out * 0.5)
	check(is_equal_approx(effect._water_amount, 0.5), "water fades out smoothly")
	effect._process(effect.water_fade_out * 0.5)
	check(is_zero_approx(effect._water_amount), "water overlay clears after leaving")
	player.environment_is_water = true
	player.dead = true
	effect._process(effect.water_fade_in)
	check(is_zero_approx(effect._water_amount), "water effect stays off after death")
	world.queue_free()
	await process_frame
	print("Environment atmosphere tests: ", "passed" if failures == 0 else "failed")
	quit(0 if failures == 0 else 1)
