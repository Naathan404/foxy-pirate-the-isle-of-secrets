extends SceneTree

const PLATFORM_SCENE := preload("res://world/objects/moving_platform.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()
	create_timer(10.0, true, false, true).timeout.connect(
		func() -> void:
			push_error("Multi-target platform lever test timed out")
			quit(1)
	)


func _run() -> void:
	var first := PLATFORM_SCENE.instantiate() as MovingPlatform
	var second := PLATFORM_SCENE.instantiate() as MovingPlatform
	first.name = "FirstPlatform"
	second.name = "SecondPlatform"
	root.add_child(first)
	root.add_child(second)
	var lever := (
		load("res://world/objects/platform_puzzle_lever.tscn").instantiate() as PlatformLever
	)
	root.add_child(lever)
	var body_shape := lever.get_node("CollisionShape3D") as CollisionShape3D
	var hurtbox := lever.get_node("Lever/HurtBox") as HurtBox
	var hurt_shape := hurtbox.get_node("CollisionShape3D") as CollisionShape3D
	_check(body_shape.shape != null, "Standalone lever has a root collision shape")
	_check(
		hurt_shape.shape != null and hurtbox.actor == lever,
		"HurtBox has a shape and points to the lever"
	)
	await physics_frame
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = hurt_shape.shape
	query.transform = hurt_shape.global_transform
	query.collision_mask = CombatLayers.ENEMY_HURTBOX
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var found_hurtbox := false
	for hit in lever.get_world_3d().direct_space_state.intersect_shape(query):
		if hit.collider == hurtbox:
			found_hurtbox = true
	_check(found_hurtbox, "Player attack shape can detect the lever HurtBox")
	lever.target_platforms = [first, second, first]
	var damage := DamageContext.new()
	damage.source_team = CombatTeams.PLAYER
	damage.amount_hp = 1.0
	_check(lever.receive_damage(damage) > 0.0, "Independent lever accepts player hit")
	_check(
		first.is_targeting_end() and second.is_targeting_end(), "Toggle sends both platforms to End"
	)
	lever.receive_damage(damage)
	_check(
		not first.is_targeting_end() and not second.is_targeting_end(),
		"Second hit reverses both while moving"
	)
	lever.destination_mode = PlatformLever.DestinationMode.END
	lever.receive_damage(damage)
	_check(first.is_targeting_end() and second.is_targeting_end(), "End mode calls both platforms")
	lever.destination_mode = PlatformLever.DestinationMode.START
	lever.receive_damage(damage)
	_check(
		not first.is_targeting_end() and not second.is_targeting_end(),
		"Start mode calls both platforms"
	)
	lever.target_platforms.clear()
	_check(lever.receive_damage(damage) == 0.0, "Unassigned independent lever does nothing")
	var dock := first.get_node("EndDock") as PlatformCallDock
	_check(
		dock.receive_damage(damage) > 0.0 and first.is_targeting_end(),
		"Existing EndDock still calls its parent"
	)
	_check(not second.is_targeting_end(), "Existing dock does not affect other platforms")
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("Multi-target platform lever checks: PASS")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
