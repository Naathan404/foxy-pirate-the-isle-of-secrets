extends SceneTree

const TIDE_SCRIPT: Script = preload("res://world/gimmick/coral_valley/tide_controller.gd")

var _failures: int = 0
var _states: Array[int] = []
var _warnings: Array[float] = []
var _heights: Array[float] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	world.position = Vector3(20, 10, -10)
	var water := Node3D.new()
	world.add_child(water)
	water.position = Vector3(3, 1, 7)
	var horizontal := Vector2(water.global_position.x, water.global_position.z)
	var tide = TIDE_SCRIPT.new()
	tide.water = water
	tide.autoplay = false
	tide.low_height = 4.0
	tide.high_height = 8.0
	tide.low_duration = 2.0
	tide.rise_duration = 1.0
	tide.high_duration = 2.0
	tide.fall_duration = 1.0
	tide.warning_seconds = 0.5
	world.add_child(tide)
	tide.state_changed.connect(func(value: int) -> void: _states.append(value))
	tide.rising_warned.connect(func(value: float) -> void: _warnings.append(value))
	tide.water_level_changed.connect(func(value: float) -> void: _heights.append(value))
	_check(not tide.is_running(), "Autoplay can be disabled")
	_check(tide.start(), "Configured controller starts")
	tide.set_process(false)
	_check(tide.state == tide.State.LOW and tide.get_water_height() == 4.0, "Start at low tide")
	tide._process(1.5)
	_check(_warnings.size() == 1 and is_equal_approx(_warnings[0], 0.5), "Warn before rising")
	tide._process(0.25)
	_check(_warnings.size() == 1, "Only one warning per low tide")
	_check(tide.get_water_height() == 4.0, "Low tide holds height")
	tide._process(0.75)
	_check(tide.state == tide.State.RISING, "Excess delta carries into rising phase")
	_check(is_equal_approx(tide.get_water_height(), 6.0), "Rise reaches midpoint smoothly")
	_check(is_equal_approx(tide.get_phase_time_remaining(), 0.5), "Phase timer is readable")
	tide._process(0.5)
	_check(tide.state == tide.State.HIGH and tide.get_water_height() == 8.0, "Rise ends at high")
	tide._process(2.5)
	_check(tide.state == tide.State.FALLING, "High tide transitions to falling")
	_check(is_equal_approx(tide.get_water_height(), 6.0), "Fall reaches midpoint smoothly")
	tide._process(0.5)
	_check(tide.state == tide.State.LOW and tide.get_water_height() == 4.0, "Cycle returns to low")
	_check(_states == [0, 1, 2, 3, 0], "Signals follow all four phases in order")
	_check(
		Vector2(water.global_position.x, water.global_position.z) == horizontal,
		"Height is world-space and never moves water sideways"
	)
	for height in _heights:
		_check(height >= 4.0 and height <= 8.0, "Water never overshoots configured levels")
	tide._process(12.0)
	_check(tide.state == tide.State.LOW, "Large delta advances multiple complete cycles")
	_check(is_equal_approx(tide.get_phase_time_remaining(), 2.0), "Multiple cycles have no drift")
	_check(_warnings.size() == 3, "Warning is available again in later cycles")
	tide._process(2.4)
	tide.stop()
	var held: float = tide.get_water_height()
	tide._process(10.0)
	_check(not tide.is_running() and tide.get_water_height() == held, "Stop holds current height")
	tide.start()
	_check(tide.state == tide.State.LOW and tide.get_water_height() == 4.0, "Start resets cycle")
	paused = true
	_check(not tide.can_process(), "Inventory pause blocks tide processing")
	await process_frame
	await process_frame
	_check(tide.get_phase_time_remaining() == 2.0, "Paused frames do not advance tide")
	tide.set_process(false)
	paused = false
	water.free()
	tide._process(0.1)
	_check(not tide.is_running(), "Deleting water stops controller safely")
	world.free()
	await _check_authored_scene()
	if _failures == 0:
		print("Tide phases, warning, smooth heights, time carry, pause and scene wiring passed")
	quit(0 if _failures == 0 else 1)


func _check_authored_scene() -> void:
	var level := load("res://world/tests/tidal_shift_test.tscn").instantiate() as Node3D
	root.add_child(level)
	var tide = level.get_node("TideController")
	var water := level.get_node("SeaWater") as Node3D
	_check(tide.water == water and tide.is_running(), "Test scene binds water and autoplays")
	_check(water.global_position.y == tide.low_height, "Authored scene starts at its low level")
	var player := level.get_node("Foxy") as Player
	player.inventory_ui.open_inventory()
	_check(paused and not tide.can_process(), "Real inventory pauses scene tide")
	var remaining: float = tide.get_phase_time_remaining()
	await process_frame
	await process_frame
	_check(tide.get_phase_time_remaining() == remaining, "Real inventory freezes countdown")
	player.inventory_ui.close_inventory(true)
	_check(not paused and tide.can_process(), "Closing inventory resumes tide")
	level.free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
