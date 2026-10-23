extends SceneTree

const CRAB_SCENE := preload("res://gameplay/enemies/crab/crab.tscn")
const CRAB_PLAYER_TEST_SCENE := preload("res://test/crab_player_test.tscn")

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_player_sandbox_scene()
	_test_hit_reaction()
	_test_random_pause_patrol()
	_test_random_axis_change_patrol()
	var crab := CRAB_SCENE.instantiate() as EnemyBase
	root.add_child(crab)
	crab.set_physics_process(false)
	crab.fsm._update(0.0)
	_expect(crab.fsm.current_state.name == &"Patrol", "Crab starts in Patrol")
	_expect(crab.data.move_speed == 2.5, "Crab retains lesson patrol speed")
	var contact_damage := crab.get_node_or_null("ContactDamage") as EnemyContactDamage
	_expect(is_instance_valid(contact_damage), "Crab has a passive ContactDamage component")
	_expect(is_instance_valid(contact_damage.hitbox), "Crab has a contact HitBox")
	var hurt_shape := crab.hurtbox.get_node("CollisionShape3D").shape as BoxShape3D
	var contact_shape := contact_damage.hitbox.get_node("CollisionShape3D").shape as BoxShape3D
	_expect(
		hurt_shape.size.x > contact_shape.size.x and hurt_shape.size.z > contact_shape.size.z,
		"Crab HurtBox is wider than its contact damage area"
	)
	_expect(is_instance_valid(crab.front_ray), "Crab has a wall-check ray")
	_expect(is_instance_valid(crab.ground_ray), "Crab has a ledge-check ray")
	_expect(crab.front_ray.enabled, "Crab enables wall checking")
	_expect(crab.ground_ray.enabled, "Crab enables ledge checking")
	_expect(
		crab.direction_pivot.is_ancestor_of(contact_damage.hitbox),
		"Crab contact HitBox rotates with Direction"
	)
	var patrol := crab.get_node_or_null("States/Patrol") as EnemyPatrol
	_expect(is_instance_valid(patrol), "Crab uses the shared Patrol state")
	_expect(crab.hitbox == null, "Crab Patrol does not own an active attack HitBox")
	_expect(crab.visual.has_animation(&"run_left"), "Crab has directional run animation")
	_expect(crab.visual.has_animation(&"hit_right"), "Crab maps hurt frames to hit animation")
	_expect(crab.visual.has_animation(&"death_down"), "Crab maps dead frames to death animation")
	_expect(crab.destroy_on_death, "Crab removes itself after death animation")
	crab.free()
	print("Crab tests: ", _failures, " failures")
	quit(0 if _failures == 0 else 1)


func _test_player_sandbox_scene() -> void:
	var sandbox := CRAB_PLAYER_TEST_SCENE.instantiate()
	_expect(sandbox.get_node_or_null("Foxy") is Player, "Sandbox includes Foxy")
	_expect(sandbox.get_node_or_null("Crab") is EnemyBase, "Sandbox includes Crab")
	sandbox.free()


func _test_hit_reaction() -> void:
	var attacker := Node3D.new()
	root.add_child(attacker)
	var crab := CRAB_SCENE.instantiate() as EnemyBase
	root.add_child(crab)
	crab.set_physics_process(false)
	crab.fsm._update(0.0)
	var damage := DamageContext.new()
	damage.source = attacker
	damage.source_team = 1
	damage.amount_hp = 1
	_expect(crab.receive_damage(damage) == 1, "Crab receives player damage")
	crab.fsm._update(0.0)
	_expect(crab.fsm.current_state.name == &"Hit", "Crab enters Hit after taking damage")
	_expect(
		String(crab.visual.animation_player.assigned_animation).begins_with("hit_"),
		"Crab plays its hit animation"
	)
	crab.free()
	attacker.free()


func _test_random_pause_patrol() -> void:
	var crab := CRAB_SCENE.instantiate() as EnemyBase
	var patrol := crab.get_node("States/Patrol") as EnemyPatrol
	patrol.use_random_pauses = true
	patrol.move_duration_min = 0.05
	patrol.move_duration_max = 0.05
	patrol.pause_duration_min = 0.05
	patrol.pause_duration_max = 0.05
	root.add_child(crab)
	crab.set_physics_process(false)
	crab.fsm._update(0.0)
	_expect(patrol._is_moving, "Patrol starts with a movement phase")
	crab.fsm._update(0.05)
	_expect(not patrol._is_moving, "Patrol changes from movement to pause")
	crab.fsm._update(0.05)
	_expect(patrol._is_moving, "Patrol resumes movement after pause")
	crab.free()


func _test_random_axis_change_patrol() -> void:
	var crab := CRAB_SCENE.instantiate() as EnemyBase
	var patrol := crab.get_node("States/Patrol") as EnemyPatrol
	patrol.use_random_axis_changes = true
	patrol.axis_change_duration_min = 0.05
	patrol.axis_change_duration_max = 0.05
	root.add_child(crab)
	crab.set_physics_process(false)
	crab.fsm._update(0.0)
	_expect(
		absf(crab.last_facing_direction.x) > absf(crab.last_facing_direction.z),
		"Crab begins patrol on its horizontal axis"
	)
	crab.fsm._update(0.05)
	_expect(
		absf(crab.last_facing_direction.z) > absf(crab.last_facing_direction.x),
		"Patrol changes from horizontal to vertical axis"
	)
	crab.free()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
