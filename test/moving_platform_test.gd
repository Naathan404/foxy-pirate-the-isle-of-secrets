extends SceneTree

const PLATFORM_SCENE: PackedScene = preload("res://world/objects/moving_platform.tscn")

var _failures := 0


func _initialize() -> void:
	await _run()
	print("Moving platform tests: %s" % ("passed" if _failures == 0 else "failed"))
	quit(0 if _failures == 0 else 1)


func _run() -> void:
	var platform := PLATFORM_SCENE.instantiate() as MovingPlatform
	root.add_child(platform)
	var start_dock := platform.get_node("StartDock") as PlatformCallDock
	var end_dock := platform.get_node("EndDock") as PlatformCallDock
	var attacker := Node3D.new()
	root.add_child(attacker)
	var hitbox := HitBox.new()
	hitbox.actor = attacker
	hitbox.team = CombatTeams.PLAYER
	hitbox.collision_layer = CombatLayers.PLAYER_ATTACK
	hitbox.collision_mask = CombatLayers.ENEMY_HURTBOX
	attacker.add_child(hitbox)
	var hit_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.4
	hit_shape.shape = sphere
	hitbox.add_child(hit_shape)
	await physics_frame
	hitbox.global_position = platform.lever_hurtbox.global_position + Vector3.UP * 0.8

	_check(platform.platform is AnimatableBody3D, "moving body carries riders")
	_check(is_instance_valid(platform._lever_animator), "lever has an animation player")
	if is_instance_valid(platform._lever_animator):
		_check(platform._lever_animator.has_animation(&"toggle-on"), "lever has on animation")
		_check(platform._lever_animator.has_animation(&"toggle-off"), "lever has off animation")
	_check(platform.lever_hurtbox.actor == platform, "lever receives combat hits")
	_check(
		platform.lever_hurtbox.collision_layer == CombatLayers.ENEMY_HURTBOX, "lever hurtbox layer"
	)
	_check(
		platform.lever_hurtbox.collision_mask == CombatLayers.PLAYER_ATTACK,
		"player attacks can hit lever"
	)
	var start := platform.start_marker.position
	var finish := platform.end_marker.position
	_check(not start.is_equal_approx(finish), "end point differs from start")
	_check(start_dock.position != start, "Start dock can be placed away from Start")
	_check(end_dock.position != finish, "End dock can be placed away from End")
	_check(not start_dock.call_end and end_dock.call_end, "each dock calls its own end")
	_check(start_dock.hurtbox.actor == start_dock, "Start dock lever receives hits")
	_check(end_dock.hurtbox.actor == end_dock, "End dock lever receives hits")
	for _frame in 4:
		await physics_frame
	_check(platform.platform.position.is_equal_approx(start), "platform waits at Start")

	_check(hitbox.begin_attack(1.0, 1), "attack starts")
	await physics_frame
	await physics_frame
	hitbox.end_attack()
	_check(platform._moving, "physical hit on lever starts platform")
	_check(platform._lever_animator.current_animation == &"toggle-on", "lever toggles on")
	for _frame in 8:
		await physics_frame
	var outward := platform.platform.position.distance_to(start)
	_check(outward > 0.0 and outward < start.distance_to(finish), "first hit moves toward End")

	_hit(hitbox, platform.lever_hurtbox, 2)
	_check(platform._lever_animator.current_animation == &"toggle-off", "lever toggles off")
	for _frame in 4:
		await physics_frame
	_check(
		platform.platform.position.distance_to(start) < outward,
		"hit during travel reverses toward Start"
	)

	_hit(hitbox, platform.lever_hurtbox, 3)
	_check(platform._lever_animator.current_animation == &"toggle-on", "lever toggles on again")
	await _wait_until_stopped(platform)
	_check(platform.platform.position.is_equal_approx(finish), "reversed again reaches End")

	_hit(hitbox, start_dock.hurtbox, 4)
	_check(start_dock._animator.current_animation == &"toggle-on", "Start lever reacts")
	await _wait_until_stopped(platform)
	_check(platform.platform.position.is_equal_approx(start), "Start dock calls platform home")

	hitbox.global_position = end_dock.hurtbox.global_position + Vector3.UP * 0.8
	await physics_frame
	_check(hitbox.begin_attack(1.0, 5), "End dock attack starts")
	await physics_frame
	await physics_frame
	hitbox.end_attack()
	_check(end_dock._animator.current_animation == &"toggle-on", "End lever reacts")
	for _frame in 8:
		await physics_frame
	_check(platform.platform.position.distance_to(start) > 0.0, "End dock calls platform")
	_hit(hitbox, start_dock.hurtbox, 6)
	await _wait_until_stopped(platform)
	_check(platform.platform.position.is_equal_approx(start), "Start dock reverses moving platform")

	platform.queue_free()
	attacker.queue_free()
	await process_frame


func _hit(hitbox: HitBox, hurtbox: HurtBox, attack_id: int) -> void:
	_check(hitbox.begin_attack(1.0, attack_id), "attack starts")
	hitbox.try_hit(hurtbox)
	hitbox.end_attack()


func _wait_until_stopped(platform: MovingPlatform) -> void:
	var distance := platform.start_marker.position.distance_to(platform.end_marker.position)
	var max_frames := ceili(distance / platform.move_speed * Engine.physics_ticks_per_second) + 30
	for _frame in max_frames:
		if not platform._moving:
			return
		await physics_frame
	_check(false, "platform reaches its destination")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("Moving platform test failed: %s" % message)
