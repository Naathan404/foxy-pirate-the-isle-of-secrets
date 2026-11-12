extends SceneTree

const SKELETON := preload("res://gameplay/enemies/coral_skeleton/coral_skeleton.tscn")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arena := Node3D.new()
	root.add_child(arena)
	var skeleton := SKELETON.instantiate() as CoralSkeleton
	arena.add_child(skeleton)
	skeleton.set_physics_process(false)
	var visual := skeleton.visual
	visual.set_process(false)
	visual.play_directional(&"sleep", Vector3.BACK, true)
	var indicators: Array = visual.get("_sleep_indicators")
	_check(indicators.size() == 3, "Expected three reusable sleep indicators")
	if indicators.size() == 3:
		visual._process(0.1)
		var first := indicators[0] as Label3D
		var second := indicators[1] as Label3D
		var third := indicators[2] as Label3D
		var initial_height := first.position.y
		var initial_scale := first.scale.x
		_check(first.visible and not second.visible, "Sleep indicators did not start in sequence")
		visual._process(0.8)
		_check(first.position.y > initial_height, "Sleep indicator did not rise")
		_check(first.scale.x > initial_scale, "Sleep indicator did not grow")
		_check(second.visible and not third.visible, "Second sleep indicator did not appear")
		var full_alpha := first.modulate.a
		visual._process(0.8)
		_check(third.visible, "Third sleep indicator did not appear")
		visual._process(0.5)
		_check(first.modulate.a < full_alpha, "Sleep indicator did not fade before disappearing")
		visual.play_directional(&"idle", Vector3.BACK, true)
		visual._process(0.01)
		_check(not first.visible and not second.visible and not third.visible, "Indicators remained visible after waking")
		visual.set("show_sleep_indicator", false)
		visual.play_directional(&"sleep", Vector3.BACK, true)
		visual._process(0.1)
		_check(not first.visible, "Disabled sleep indicators remained visible")
	arena.queue_free()
	await process_frame
	if failures.is_empty():
		print("Coral Skeleton sleep indicator tests passed")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
