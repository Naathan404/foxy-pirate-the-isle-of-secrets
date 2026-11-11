extends SceneTree

class TestPlayer extends Player:
	var hits := 0
	var hit_direction := Vector3.ZERO

	func _ready() -> void:
		set_physics_process(false)

	func _exit_tree() -> void:
		pass

	func apply_environment_knockback(direction: Vector3, _speed: float, _duration: float) -> void:
		hits += 1
		hit_direction = direction


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var zone := FlatTideZone.new()
	root.add_child(zone)
	var actor := TestPlayer.new()
	var visual := PlayerVisual.new()
	visual.name = "Visual"
	actor.add_child(visual)
	var fsm := Fsm.new()
	fsm.name = "FSM"
	actor.add_child(fsm)
	root.add_child(actor)
	var controller := FlatTideController.new()
	controller.player = actor
	controller.zones = [zone]
	controller.player_ground_offset = 0.0
	root.add_child(controller)
	controller.set_physics_process(false)
	var failures := 0
	for direction in range(4):
		zone.flow_direction = direction as FlatTideZone.FlowDirection
		controller._enter_state(FlatTideController.State.LOW)
		controller._apply_coverage()
		controller._enter_state(FlatTideController.State.RISING)
		actor.position = zone.to_global(zone._from_flow(Vector3(-2.0, 0.0, 0.0)))
		var previous_hits := actor.hits
		controller._elapsed = controller.rise_duration * 0.5
		controller._apply_coverage()
		if actor.hits != previous_hits + 1 or actor.hit_direction.dot(zone.get_flow_direction()) < 0.99:
			push_error("Advancing wave did not push in direction %d" % direction)
			failures += 1
		controller._apply_coverage()
		controller._enter_state(FlatTideController.State.FALLING)
		controller._elapsed = controller.fall_duration * 0.5
		controller._apply_coverage()
		if actor.hits != previous_hits + 1:
			push_error("Wave pushed repeatedly or during retreat in direction %d" % direction)
			failures += 1
	controller.queue_free()
	actor.queue_free()
	zone.queue_free()
	if failures == 0:
		print("Flat tide wave knockback checks: PASS")
	quit(0 if failures == 0 else 1)
