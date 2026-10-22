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
	_expect(enemy.hitbox.actor == enemy, "Enemy HitBox targets its owner")
	_expect(enemy.hurtbox.team == enemy.team, "Enemy HurtBox inherits team")
	_expect(enemy.hitbox.team == enemy.team, "Enemy HitBox inherits team")
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
	_expect(enemy.hitbox.collision_layer == CombatLayers.ENEMY_ATTACK, "Enemy HitBox uses EnemyAttack")
	_expect(
		enemy.hitbox.collision_mask == CombatLayers.PLAYER_HURTBOX,
		"Enemy HitBox only queries PlayerHurtBox"
	)
	_expect(
		enemy.target_detector.collision_mask == CombatLayers.PLAYER_BODY,
		"TargetDetector only queries PlayerBody"
	)
	_expect(enemy.direction_pivot.is_ancestor_of(enemy.hurtbox), "HurtBox is under Direction")
	_expect(enemy.direction_pivot.is_ancestor_of(enemy.hitbox), "HitBox is under Direction")
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
		enemy.hitbox.global_position.is_equal_approx(enemy.global_position + Vector3.RIGHT),
		"HitBox rotates to enemy facing"
	)

	_expect(enemy.begin_attack(3, &"contact"), "Enemy starts a hitbox attack")
	enemy.end_attack()
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
	_expect(enemy.collision_layer == 0, "Death disables enemy body collisions")
	_expect(enemy.hurtbox.collision_layer == 0, "Death disables HurtBox collisions")
	enemy.fsm._update(0.0)
	_expect(enemy.fsm.current_state.name == &"Death", "Lethal damage enters terminal Death state")
	_expect(not enemy.hurtbox.enabled, "Death disables enemy HurtBox")
	_expect(not enemy.target_detector.monitoring, "Death stops target detection")

	enemy.free()
	player.free()
	_test_death_animation_cleanup()
	print("Enemy base tests: ", _failures, " failures")
	quit(0 if _failures == 0 else 1)


func _create_enemy() -> EnemyBase:
	var enemy := ENEMY_BASE_SCENE.instantiate() as EnemyBase
	enemy.hitbox = HitBox.new()
	_add_shape(enemy.hitbox)
	enemy.hitbox.position = Vector3(0.0, 0.0, 1.0)
	enemy.direction_pivot.add_child(enemy.hitbox)
	enemy.target_detector = Area3D.new()
	_add_shape(enemy.target_detector)
	enemy.direction_pivot.add_child(enemy.target_detector)
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
	_expect(enemy.is_queued_for_deletion(), "Enemy is removed after the death animation")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
