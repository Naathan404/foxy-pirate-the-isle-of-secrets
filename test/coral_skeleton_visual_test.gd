extends SceneTree

const SKELETON := preload("res://gameplay/enemies/coral_skeleton/coral_skeleton.tscn")
const VFX_SCRIPT := preload("res://gameplay/enemies/coral_skeleton/coral_skeleton_vfx.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arena := Node3D.new()
	root.add_child(arena)
	current_scene = arena
	var skeleton := SKELETON.instantiate() as CoralSkeleton
	arena.add_child(skeleton)
	skeleton.set_physics_process(false)
	var target := Node3D.new()
	target.position = Vector3(3, 0, 0)
	arena.add_child(target)
	skeleton.set_target(target)
	_check(_count_effect(arena, &"alert") == 1, "Target acquisition did not spawn alert VFX")
	skeleton.fire_fan()
	_check(_count_effect(arena, &"muzzle") == 1, "A fan burst should spawn one muzzle effect")
	for child in arena.get_children():
		if child is CoralSkeletonBullet:
			child.queue_free()
	var visual := skeleton.visual
	visual.play_directional(&"sleep", Vector3.BACK, true)
	await create_timer(0.03).timeout
	_check(visual.sprite.texture.resource_path.ends_with("sleep_6.png"), "Sleep sheet was not selected")
	_check(visual.sleep_indicator.visible, "Sleep indicator was not shown")
	visual.play_directional(&"idle", Vector3.BACK, true)
	await process_frame
	var first_frame := visual.sprite.frame
	await create_timer(0.25).timeout
	_check(visual.sprite.frame != first_frame, "Idle animation did not advance")
	_check(visual.sprite.hframes == 6 and visual.sprite.vframes == 3, "Sprite sheet does not have six frames per direction")
	visual.play_directional(&"walk", Vector3.RIGHT, true)
	await create_timer(0.03).timeout
	_check(visual.sprite.texture.resource_path.ends_with("walk_6.png"), "Walk sheet was not selected")
	_check(visual.sprite.frame >= 6 and visual.sprite.frame < 12, "Side direction did not select side row")
	await create_timer(0.5).timeout
	_check(visual.sprite.texture.resource_path.ends_with("walk_opposite_6.png"), "Walk did not switch to the opposite step")
	visual.play_directional(&"shoot", Vector3.RIGHT, true)
	visual.call("show_fire")
	await create_timer(0.03).timeout
	_check(visual.sprite.texture.resource_path.ends_with("shoot_6.png"), "Shoot sheet was not selected")
	_check(visual.sprite.frame == 9, "Muzzle flash frame is not synchronized with shot")
	visual.play_hit_feedback()
	await create_timer(0.03).timeout
	_check(visual.sprite.texture.resource_path.ends_with("hit_death_6.png"), "Hit sheet was not selected")
	skeleton.set_physics_process(true)
	skeleton.die()
	await create_timer(1.8).timeout
	_check(not is_instance_valid(skeleton), "Death animation did not finish and free enemy")
	await create_timer(1.0).timeout
	for child in arena.get_children():
		_check(child.get_script() != VFX_SCRIPT, "Transient VFX was not cleaned up")
	arena.queue_free()
	await process_frame
	if failures.is_empty():
		print("Coral Skeleton visual and death lifecycle tests passed")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _count_effect(arena: Node, kind: StringName) -> int:
	var count := 0
	for child in arena.get_children():
		if child.get_script() == VFX_SCRIPT and child.get("effect") == kind:
			count += 1
	return count
