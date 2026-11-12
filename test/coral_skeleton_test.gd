extends SceneTree

const SKELETON := preload("res://gameplay/enemies/coral_skeleton/coral_skeleton.tscn")
var failures: Array[String] = []
var arena: Node3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	arena = Node3D.new()
	root.add_child(arena)
	current_scene = arena
	var skeleton := SKELETON.instantiate() as CoralSkeleton
	skeleton.wake_duration = 0.0
	skeleton.wake_attack_delay = 0.0
	arena.add_child(skeleton)
	skeleton.process_mode = Node.PROCESS_MODE_DISABLED
	var target := Node3D.new()
	target.position = Vector3(3, 0, 0)
	arena.add_child(target)
	skeleton.set_target(target)
	skeleton.fsm._update(0.01)
	skeleton.fsm._update(0.01)
	skeleton.fsm._update(0.01)
	_check(skeleton.fsm.current_state.name == &"Chase", "Sleeping skeleton did not wake and chase")
	skeleton.fsm._update(0.01)
	_check(skeleton.fsm.current_state.name == &"Shoot", "Chase did not begin shooting")
	skeleton.fsm._update(0.5)
	_check(_bullets().size() == 3, "Fan did not create three simultaneous bullets")
	var fan := _bullets()
	if fan.size() == 3:
		_check(fan[0].direction.dot(fan[2].direction) < 0.99, "Fan directions are not separated")
	_clear_bullets()
	skeleton.shot_mode = CoralSkeleton.ShotMode.SEQUENTIAL
	skeleton.fsm._update(0.25)
	skeleton.fsm._update(0.01)
	skeleton.cooldown_remaining = 0.0
	skeleton.request_state(&"shoot")
	skeleton.fsm._update(0.01)
	skeleton.fsm._update(0.4)
	_check(_bullets().size() == 1, "Sequential mode did not fire first bullet")
	skeleton.fsm._update(0.2)
	_check(_bullets().size() == 2, "Sequential mode did not wait between bullets")
	skeleton.fsm._update(0.2)
	_check(_bullets().size() == 3, "Sequential mode did not fire three bullets")
	_check(skeleton.cooldown_remaining > 0.0, "Burst did not start cooldown")
	_clear_bullets()
	skeleton.position = Vector3(3, 0, 0)
	skeleton.set_target(null)
	skeleton.request_state(&"return")
	skeleton.fsm._update(0.01)
	_check(skeleton.fsm.current_state.name == &"Return", "Lost target did not enter return")
	skeleton.position = skeleton.home_position
	skeleton.fsm._update(0.01)
	skeleton.fsm._update(0.01)
	_check(skeleton.fsm.current_state.name == &"Guard", "Returning home did not resume guard")
	arena.queue_free()
	await process_frame
	if failures.is_empty():
		print("Coral Skeleton state and shooting tests passed")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _bullets() -> Array[CoralSkeletonBullet]:
	var bullets: Array[CoralSkeletonBullet] = []
	for child in arena.get_children():
		if child is CoralSkeletonBullet and not child.is_queued_for_deletion():
			bullets.append(child)
	return bullets


func _clear_bullets() -> void:
	for bullet in _bullets():
		bullet.queue_free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
