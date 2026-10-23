extends SceneTree

const ENEMY_BASE_SCENE := preload("res://gameplay/enemies/base/enemy_base.tscn")

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var enemy := _create_enemy()
	enemy.fsm._update(0.0)
	_expect(enemy.fsm.current_state.name == &"Idle", "Enemy FSM starts in Idle")
	_expect(is_instance_valid(enemy.visual), "Enemy scene includes an EnemyVisual component")
	_expect(enemy.hp.current_hp == enemy.data.max_hp, "Enemy initializes health")
	_expect(enemy.hurtbox.actor == enemy, "Enemy HurtBox targets its owner")
	_expect(enemy.active_hitbox.actor == enemy, "Enemy active HitBox targets its owner")
	_expect(enemy.hurtbox.team == enemy.team, "Enemy HurtBox inherits team")
	_expect(enemy.active_hitbox.team == enemy.team, "Enemy active HitBox inherits team")
	_expect(enemy.collision_layer == CombatLayers.ENEMY_BODY, "Enemy uses EnemyBody layer")
	_expect(enemy.collision_mask == CombatLayers.ENEMY_BODY_MASK, "Enemy body mask is explicit")
	_expect(
		enemy.hurtbox.collision_layer == CombatLayers.ENEMY_HURTBOX,
		"Enemy HurtBox uses EnemyHurtBox layer"
	)
	_expect(
		enemy.hurtbox.collision_mask == CombatLayers.PLAYER_ATTACK,
		"Enemy HurtBox only queries PlayerAttack"
	)
	_expect(
		enemy.active_hitbox.collision_layer == CombatLayers.ENEMY_ATTACK,
		"Enemy active HitBox uses EnemyAttack"
	)
	_expect(
		enemy.active_hitbox.collision_mask == CombatLayers.PLAYER_HURTBOX,
		"Enemy active HitBox only queries PlayerHurtBox"
	)
	_expect(
		enemy.target_detector.collision_mask == CombatLayers.PLAYER_BODY,
		"TargetDetector only queries PlayerBody"
	)
	_expect(enemy.direction_pivot.is_ancestor_of(enemy.hurtbox), "HurtBox is under Direction")
	_expect(
		enemy.direction_pivot.is_ancestor_of(enemy.active_hitbox),
		"ActiveHitBox is under Direction"
	)
	_expect(enemy.direction_pivot.is_ancestor_of(enemy.front_ray), "Front ray is under Direction")
	_expect(enemy.direction_pivot.is_ancestor_of(enemy.ground_ray), "Ground ray is under Direction")
	_expect(not enemy.front_ray.enabled, "Front ray is opt-in by default")
	_expect(not enemy.ground_ray.enabled, "Ground ray is opt-in by default")
	_expect(not enemy.show_debug_health, "Debug health is disabled by default")
	enemy.show_debug_health = true
	_expect(enemy.debug_health_label.visible, "Debug health can be enabled")
	_expect(
		enemy.debug_health_label.text == "HP: %d / %d" % [enemy.hp.current_hp, enemy.hp.get_max_hp()],
		"Debug health displays the current and maximum HP"
	)
	_expect(
		enemy.direction_pivot.is_ancestor_of(enemy.target_detector),
		"TargetDetector is under Direction"
	)

	var player := Node3D.new()
	player.add_to_group(&"player")
	root.add_child(player)
	player.global_position = Vector3(5.0, 0.0, 0.0)
	enemy.set_target(player)
	_expect(enemy.has_target(), "Enemy accepts a player target")
	enemy.fsm._update(0.0)
	_expect(enemy.fsm.current_state.name == &"Idle", "Base Idle does not impose chase behavior")
	_expect(enemy.move_toward_target(1.0, 0.0), "Enemy moves toward a distant target")
	_expect(enemy.velocity.x > 0.0, "Enemy movement points at its target")
	_expect(
		enemy.active_hitbox.global_position.is_equal_approx(enemy.global_position + Vector3.RIGHT),
		"ActiveHitBox rotates to enemy facing"
	)

	_expect(enemy.begin_active_attack(3), "Enemy starts an active attack")
	enemy.end_active_attack()
	var damage := DamageContext.new()
	damage.source = player
	damage.source_team = enemy.team
	damage.amount_hp = 1
	_expect(enemy.receive_damage(damage) == 0, "Enemy rejects friendly damage")
	damage.source_team = enemy.team + 1
	_expect(enemy.receive_damage(damage) == 1, "Enemy receives hostile damage")
	_expect(enemy.fsm.next_state.name == &"Hit", "Non-lethal damage enters Hit state")
	enemy.fsm._update(0.0)
	_expect(enemy.fsm.current_state.name == &"Hit", "Enemy enters shared Hit state")
	damage.amount_hp = enemy.hp.current_hp
	_expect(
		enemy.receive_damage(damage) == damage.amount_hp, "Lethal damage consumes remaining health"
	)
	_expect(enemy.dead, "Lethal damage kills enemy")
	enemy.fsm._update(0.0)
	_expect(enemy.fsm.current_state.name == &"Death", "Lethal damage enters terminal Death state")
	_expect(enemy.collision_layer == 0, "Death disables enemy body collisions")
	_expect(enemy.hurtbox.collision_layer == 0, "Death disables HurtBox collisions")
	_expect(not enemy.hurtbox.enabled, "Death disables enemy HurtBox")
	_expect(not enemy.target_detector.monitoring, "Death stops target detection")

	enemy.free()
	player.free()
	_test_death_animation_cleanup()
	print("Enemy base tests: ", _failures, " failures")
	quit(0 if _failures == 0 else 1)


func _create_enemy() -> EnemyBase:
	var enemy := ENEMY_BASE_SCENE.instantiate() as EnemyBase
	var active_hitbox := HitBox.new()
	active_hitbox.name = &"ActiveHitBox"
	_add_shape(active_hitbox)
	active_hitbox.position = Vector3(0.0, 0.0, 1.0)
	enemy.get_node("Direction").add_child(active_hitbox)
	var target_detector := Area3D.new()
	target_detector.name = &"TargetDetector"
	_add_shape(target_detector)
	enemy.get_node("Direction").add_child(target_detector)
	root.add_child(enemy)
	enemy.set_physics_process(false)
	return enemy


func _add_shape(area: Area3D) -> void:
	var collision := CollisionShape3D.new()
	collision.shape = SphereShape3D.new()
	area.add_child(collision)


func _test_death_animation_cleanup() -> void:
	var enemy := _create_enemy()
	var library := AnimationLibrary.new()
	var animation := Animation.new()
	animation.length = 0.1
	library.add_animation(&"death_right", animation)
	enemy.visual.animation_player.add_animation_library(&"", library)
	enemy.destroy_on_death = true
	enemy.face_direction(Vector3.RIGHT)
	enemy.die()
	enemy.fsm._update(0.0)
	_expect(
		not enemy.is_queued_for_deletion(),
		"Enemy remains until the death animation has finished"
	)
	enemy.visual.animation_finished.emit(&"death_right")
	_expect(not enemy.is_queued_for_deletion(), "Enemy remains during death feedback")
	enemy.visual.death_feedback_finished.emit()
	_expect(enemy.is_queued_for_deletion(), "Enemy is removed after death feedback")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
