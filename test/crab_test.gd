extends SceneTree

const CRAB_SCENE := preload("res://gameplay/enemies/crab/crab.tscn")
const CRAB_PLAYER_TEST_SCENE := preload("res://test/crab_player_test.tscn")
const Teams := preload("res://gameplay/combat/combat_teams.gd")

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_player_sandbox_scene()
	_test_hit_reaction()
	_test_death_reaction()
	_test_random_pause_patrol()
	_test_random_axis_change_patrol()
	var crab := CRAB_SCENE.instantiate() as EnemyBase
	root.add_child(crab)
	crab.set_physics_process(false)
	crab.fsm._update(0.0)
	_expect(crab.fsm.current_state.name == &"Patrol", "Crab starts in Patrol")
	_expect(crab.data.move_speed == 2.5, "Crab retains lesson patrol speed")
	_expect(is_instance_valid(crab.contact_hitbox), "Crab has a contact HitBox")
	_expect(crab.contact_hitbox.is_active(), "Patrol enables contact damage")
	var hurt_shape := crab.hurtbox.get_node("CollisionShape3D").shape as BoxShape3D
	var contact_shape := crab.contact_hitbox.get_node("CollisionShape3D").shape as BoxShape3D
	_expect(
		hurt_shape.size.x > contact_shape.size.x and hurt_shape.size.z > contact_shape.size.z,
		"Crab HurtBox is wider than its contact damage area"
	)
	_expect(is_instance_valid(crab.front_ray), "Crab has a wall-check ray")
	_expect(is_instance_valid(crab.ground_ray), "Crab has a ledge-check ray")
	_expect(crab.front_ray.enabled, "Crab enables wall checking")
	_expect(crab.ground_ray.enabled, "Crab enables ledge checking")
	_expect(
		crab.direction_pivot.is_ancestor_of(crab.contact_hitbox),
		"Crab contact HitBox rotates with Direction"
	)
	var patrol := crab.get_node_or_null("States/Patrol") as EnemyPatrol
	_expect(is_instance_valid(patrol), "Crab uses the shared Patrol state")
	_expect(patrol.use_contact_damage, "Crab Patrol owns contact damage activation")
	_expect(crab.active_hitbox == null, "Crab has no active attack HitBox")
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
	damage.source_team = Teams.PLAYER
	damage.amount_hp = 1
	_expect(crab.receive_damage(damage) == 1, "Crab receives player damage")
	crab.fsm._update(0.0)
	_expect(crab.fsm.current_state.name == &"Hit", "Crab enters Hit after taking damage")
	_expect(not crab.contact_hitbox.is_active(), "Hit disables contact damage")
	_expect(
		String(crab.visual.animation_player.assigned_animation).begins_with("hit_"),
		"Crab plays its hit animation"
	)
	crab.fsm._update(crab.data.hit_duration + 0.01)
	crab.fsm._update(0.0)
	_expect(crab.fsm.current_state.name == &"Hit", "Crab remains in Hit during recovery")
	_expect(not crab.contact_hitbox.is_active(), "Recovery keeps contact damage disabled")
	_expect(crab.velocity.is_zero_approx(), "Recovery stops knockback movement")
	_expect(
		String(crab.visual.animation_player.assigned_animation).begins_with("idle_"),
		"Recovery switches from hit to idle animation"
	)
	crab.fsm._update(crab.data.hit_recovery_duration + 0.01)
	crab.fsm._update(0.0)
	_expect(crab.fsm.current_state.name == &"Patrol", "Crab returns to Patrol after recovery")
	_expect(crab.contact_hitbox.is_active(), "Patrol restores contact damage after recovery")
	crab.free()
	attacker.free()


func _test_death_reaction() -> void:
	var attacker := Node3D.new()
	root.add_child(attacker)
	var crab := CRAB_SCENE.instantiate() as EnemyBase
	root.add_child(crab)
	crab.set_physics_process(false)
	crab.fsm._update(0.0)
	var damage := DamageContext.new()
	damage.source = attacker
	damage.source_team = Teams.PLAYER
	damage.amount_hp = crab.hp.current_hp
	_expect(crab.receive_damage(damage) > 0, "Crab receives lethal player damage")
	crab.fsm._update(0.0)
	_expect(crab.dead, "Crab is marked dead after lethal damage")
	_expect(crab.fsm.current_state.name == &"Death", "Crab enters Death after lethal damage")
	_expect(
		String(crab.visual.animation_player.assigned_animation).begins_with("death_"),
		"Crab plays its death animation"
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
