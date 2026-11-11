extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()
	create_timer(10.0, true, false, true).timeout.connect(
		func() -> void:
			push_error("Platform lever animation test timed out")
			quit(1)
	)


func _run() -> void:
	var platform := load("res://world/objects/moving_platform.tscn").instantiate() as MovingPlatform
	root.add_child(platform)
	var moving_lever := platform.get_node("Platform/Lever/AnimatedSprite3D") as AnimatedSprite3D
	var dock := platform.get_node("StartDock") as PlatformCallDock
	var dock_lever := dock.get_node("Lever/AnimatedSprite3D") as AnimatedSprite3D
	_check(
		moving_lever.animation == &"idle" and dock_lever.animation == &"idle", "Levers start idle"
	)
	var damage := DamageContext.new()
	damage.source_team = CombatTeams.PLAYER
	damage.amount_hp = 1.0
	_check(platform.receive_damage(damage) > 0.0, "Platform lever accepts interaction")
	_check(
		moving_lever.animation == &"active" and moving_lever.is_playing(),
		"Platform lever plays active"
	)
	await moving_lever.animation_finished
	_check(moving_lever.animation == &"idle", "Platform lever returns to idle")
	_check(dock.receive_damage(damage) > 0.0, "Dock lever accepts interaction")
	_check(dock_lever.animation == &"active" and dock_lever.is_playing(), "Dock lever plays active")
	await dock_lever.animation_finished
	_check(dock_lever.animation == &"idle", "Dock lever returns to idle")
	platform.receive_damage(damage)
	_check(moving_lever.animation == &"active", "Later interaction replays active")
	for failure: String in failures:
		push_error(failure)
	if failures.is_empty():
		print("Platform lever animation checks: PASS")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
