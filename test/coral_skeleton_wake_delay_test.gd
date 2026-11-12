extends SceneTree

const SKELETON := preload("res://gameplay/enemies/coral_skeleton/coral_skeleton.tscn")
var failures: Array[String] = []
var shot_count := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arena := Node3D.new()
	root.add_child(arena)
	current_scene = arena
	arena.child_entered_tree.connect(_on_child_entered)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = CombatLayers.WORLD
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(30, 0.5, 30)
	floor_collision.shape = floor_shape
	floor_body.add_child(floor_collision)
	floor_body.position.y = -0.25
	arena.add_child(floor_body)
	var skeleton := SKELETON.instantiate() as CoralSkeleton
	skeleton.wake_duration = 0.1
	skeleton.wake_attack_delay = 1.0
	skeleton.fire_delay = 0.0
	arena.add_child(skeleton)
	var target := Node3D.new()
	target.position = Vector3(2, 0, 0)
	arena.add_child(target)
	skeleton.set_target(target)
	await create_timer(0.3).timeout
	_check(skeleton.fsm.current_state.name == &"Chase", "Skeleton did not finish waking")
	_check(shot_count == 0, "Skeleton shot immediately after waking")
	target.position.x = 6.0
	await create_timer(0.3).timeout
	_check(skeleton.position.x > 0.1, "Wake attack delay blocked pursuit")
	_check(shot_count == 0, "Skeleton shot before the wake attack delay elapsed")
	target.position.x = 3.0
	await create_timer(0.8).timeout
	_check(shot_count == 3, "Skeleton did not shoot after the wake attack delay")
	arena.queue_free()
	await process_frame
	if failures.is_empty():
		print("Coral Skeleton wake attack delay tests passed")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _on_child_entered(child: Node) -> void:
	if child is CoralSkeletonBullet:
		shot_count += 1


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
