extends SceneTree

const ATMOSPHERE := preload("res://gameplay/player/effects/environment_atmosphere.gd")
var failures := 0


class TestPlayer:
	extends Player
	var wave_hits := 0

	func _ready() -> void:
		pass

	func _exit_tree() -> void:
		pass

	func _physics_process(_delta: float) -> void:
		pass

	func notify_hit(_duration: float = -1.0) -> void:
		wave_hits += 1


func _initialize() -> void:
	call_deferred("run_tests")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func run_tests() -> void:
	var player := TestPlayer.new()
	var visual := PlayerVisual.new()
	visual.name = "Visual"
	visual.process_mode = Node.PROCESS_MODE_DISABLED
	player.add_child(visual)
	var fsm := Fsm.new()
	fsm.name = "FSM"
	player.add_child(fsm)
	root.add_child(player)
	player.apply_environment_knockback(Vector3.RIGHT, 14.0, 0.65)
	player.velocity = Vector3(-20.0, 3.0, 4.0)
	player._apply_environment_push(0.1)
	check(player.velocity.x >= 14.0, "Opposing movement cannot cancel wave")
	check(is_equal_approx(player.velocity.z, 4.0), "Wave preserves sideways movement")
	check(is_equal_approx(player.velocity.y, 3.0), "Wave preserves vertical velocity")
	player.velocity.x = -20.0
	player._apply_environment_push(0.1)
	check(player.velocity.x > 0.0, "Wave persists after movement resets velocity")
	player._apply_environment_push(1.0)
	player.velocity.x = -5.0
	player._apply_environment_push(0.1)
	check(is_equal_approx(player.velocity.x, -5.0), "Wave expires")
	player.apply_environment_knockback(Vector3.UP, 14.0, 0.65)
	check(player._environment_push_remaining == 0.0, "Vertical-only direction is rejected")
	var tide := FlatTideController.new()
	var zone := FlatTideZone.new()
	zone.size = Vector2(12.0, 12.0)
	zone.shore_wave_amplitude = 0.0
	zone.shore_detail_amplitude = 0.0
	tide.add_child(zone)
	tide.zones = [zone]
	tide.player = player
	tide.player_ground_offset = 0.0
	root.add_child(tide)
	tide.set_physics_process(false)
	tide.state = FlatTideController.State.RISING
	tide._elapsed = tide.rise_duration * 0.5
	player.position = Vector3(-5.0, 0.0, 0.0)
	tide._apply_coverage()
	var previous_hits := player.wave_hits
	player.position = Vector3(4.0, 0.0, 0.0)
	tide._apply_coverage()
	check(player.wave_hits == previous_hits + 1, "Moving into an advancing wave applies its push")
	tide._apply_coverage()
	check(player.wave_hits == previous_hits + 1, "Wave hits only once per rise")
	tide.queue_free()
	var atmosphere := ATMOSPHERE.new()
	atmosphere.player = player
	root.add_child(atmosphere)
	atmosphere.set_process(false)
	player.environment_is_water = true
	atmosphere._process(6.0)
	check(
		is_equal_approx(atmosphere._water_pressure, 0.5),
		"Water pressure progresses over 12 seconds"
	)
	atmosphere._process(6.0)
	check(
		is_equal_approx(atmosphere._water_pressure, 1.0),
		"Water reaches full pressure at 12 seconds"
	)
	atmosphere._process(10.0)
	check(is_equal_approx(atmosphere._water_pressure, 1.0), "Water pressure remains capped")
	player.environment_is_water = false
	atmosphere._process(0.65)
	check(is_zero_approx(atmosphere._water_pressure), "Water clears after leaving")
	player.environment_is_water = true
	atmosphere._process(1.0)
	check(is_equal_approx(atmosphere._water_pressure, 1.0 / 12.0), "Re-entry starts a new timer")
	player.dead = true
	atmosphere._process(0.65)
	check(is_zero_approx(atmosphere._water_pressure), "Water clears after death")
	atmosphere.queue_free()
	player.queue_free()
	await process_frame
	print("Flat tide pressure tests: ", "passed" if failures == 0 else "failed")
	quit(0 if failures == 0 else 1)
