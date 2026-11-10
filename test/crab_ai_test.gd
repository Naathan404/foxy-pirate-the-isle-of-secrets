extends SceneTree

const CRAB_SCENE := preload("res://gameplay/enemies/crab/crab.tscn")
const ELITE_SCENE := preload("res://gameplay/enemies/crab/elite_crab.tscn")
const EGG_SCENE := preload("res://gameplay/enemies/crab/crab_egg.tscn")

class TestPlayer extends CharacterBody3D:
	var accepts_damage := true

	func receive_damage(damage: DamageContext) -> float:
		return damage.amount_hp if accepts_damage else 0.0


var failures: Array[String] = []
var arena: Node3D
var player: TestPlayer
var player_hurtbox: HurtBox


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	arena = Node3D.new()
	root.add_child(arena)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = CombatLayers.WORLD
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(50, 0.5, 50)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	arena.add_child(floor_body)
	floor_body.position.y = -0.25
	player = TestPlayer.new()
	player.collision_layer = CombatLayers.PLAYER_BODY
	player.collision_mask = 0
	player.add_to_group("player")
	var player_shape := CollisionShape3D.new()
	var player_cylinder := CylinderShape3D.new()
	player_cylinder.radius = 0.3
	player_cylinder.height = 1.5
	player_shape.shape = player_cylinder
	player_shape.position.y = 0.75
	player.add_child(player_shape)
	player_hurtbox = HurtBox.new()
	player_hurtbox.actor = player
	player_hurtbox.team = CombatTeams.PLAYER
	player_hurtbox.collision_layer = 0
	player_hurtbox.collision_mask = 0
	player.add_child(player_hurtbox)
	arena.add_child(player)
	player.position = Vector3(4, 0, 3)
	_check_delivery_context()
	await _check_chase_and_anger()
	await _check_movement_speeds()
	await _check_disengage(CRAB_SCENE, false)
	await _check_disengage(ELITE_SCENE, false)
	await _check_disengage(ELITE_SCENE, true)
	await _check_eggs()
	await _check_egg_lifecycle()
	await _check_egg_entity()
	arena.queue_free()
	await process_frame
	if not failures.is_empty():
		for message in failures:
			push_error(message)
		quit(1)
		return
	print("Crab AI and egg scenarios passed")
	quit(0)


func _check_delivery_context() -> void:
	var attack := AttackContext.new()
	attack.delivery_type = AttackData.DeliveryType.PROJECTILE
	var damage := attack.create_damage_context()
	var copy := damage.create_hit_copy()
	_check(
		copy.delivery_type == AttackData.DeliveryType.PROJECTILE,
		"Projectile delivery must survive context snapshots"
	)
	_check(DamageContext.new().delivery_type == -1, "Unknown damage must not default to melee")


func _check_chase_and_anger() -> void:
	var crab := CRAB_SCENE.instantiate() as Crab
	crab.player_detection_radius = 6.5
	arena.add_child(crab)
	var other := CRAB_SCENE.instantiate() as Crab
	other.position = Vector3(-10, 0, 0)
	arena.add_child(other)
	await create_timer(0.35).timeout
	_check(is_instance_valid(crab.target_detector), "Normal crab needs a target detector")
	_check(crab.has_target(), "Normal crab should detect the player")
	var other_shape := other.target_detector.get_node("CollisionShape3D").shape as CylinderShape3D
	var original_radius := other_shape.radius
	var before := crab.global_position
	var diagonal := false
	for _frame in 21:
		await physics_frame
		if absf(crab.velocity.x) > 0.05 and absf(crab.velocity.z) > 0.05:
			diagonal = true
	var travel := crab.global_position - before
	_check(travel.length() > 0.1, "Crab should approach detected player")
	_check(not diagonal, "Crab velocity must never move along both axes")
	var patrol := crab.get_node("States/Patrol") as CrabPatrol
	player.position = crab.position + Vector3(2, 0, 5)
	patrol._set_chase_direction(Vector3.RIGHT)
	patrol._segment_start = crab.global_position
	patrol._update(0.016)
	_check(patrol._chase_direction == Vector3.RIGHT, "Crab must honor minimum segment length")
	patrol._segment_start = crab.global_position - Vector3.RIGHT * crab.min_chase_segment_distance
	patrol._update(0.016)
	_check(patrol._chase_direction == Vector3.BACK, "Crab may change axis after minimum distance")
	var melee := _damage(AttackData.DeliveryType.MELEE, 0.1)
	crab.receive_damage(melee)
	_check(is_zero_approx(crab.anger_remaining), "Melee should not provoke anger")
	player.position = Vector3(10, 0, 0)
	await create_timer(0.2).timeout
	_check(not crab.has_target(), "Player outside normal detection should be lost")
	var projectile := _damage(AttackData.DeliveryType.PROJECTILE, 0.1)
	crab.receive_damage(projectile)
	_check(crab.anger_remaining > 0.0, "Player projectile should provoke anger")
	crab.anger_remaining = 1.0
	crab.receive_damage(projectile)
	_check(crab.anger_remaining > 4.0, "Repeated projectile should refresh anger")
	await create_timer(0.2).timeout
	var shape := crab.target_detector.get_node("CollisionShape3D").shape as CylinderShape3D
	_check(shape.radius > crab.player_detection_radius, "Anger should expand detection")
	_check(crab.has_target(), "Expanded detection should acquire player after ranged hit")
	_check(is_equal_approx(other_shape.radius, original_radius), "Detector shapes must be independent")
	crab.anger_remaining = 0.05
	await create_timer(0.2).timeout
	_check(is_zero_approx(crab.anger_remaining), "Anger should expire")
	_check(is_equal_approx(shape.radius, crab.player_detection_radius), "Detection should reset")
	crab.queue_free()
	other.queue_free()
	await physics_frame


func _check_movement_speeds() -> void:
	var crab := CRAB_SCENE.instantiate() as Crab
	arena.add_child(crab)
	crab.set_physics_process(false)
	player.position = Vector3(5, 0, 0)
	await physics_frame
	crab.set_target(player)
	var patrol := crab.get_node("States/Patrol") as CrabPatrol
	patrol._update(0.5)
	var chase_speed := Vector2(crab.velocity.x, crab.velocity.z).length()
	crab.set_target(null)
	patrol._update(0.5)
	var patrol_speed := Vector2(crab.velocity.x, crab.velocity.z).length()
	_check(is_equal_approx(patrol_speed, crab.data.move_speed), "Patrol must use its own speed")
	_check(
		is_equal_approx(chase_speed, crab.data.move_speed * crab.chase_speed_scale),
		"Chase must use its own speed"
	)
	_check(chase_speed > patrol_speed, "Normal crab must chase faster than it patrols")
	var elite := ELITE_SCENE.instantiate() as EliteCrab
	arena.add_child(elite)
	elite.set_physics_process(false)
	elite.set_target(player)
	var elite_patrol := elite.get_node("States/Patrol") as EliteCrabPatrol
	elite_patrol.start_charge_cooldown()
	elite_patrol._update(0.5)
	var elite_chase_speed := Vector2(elite.velocity.x, elite.velocity.z).length()
	_check(
		is_equal_approx(elite_chase_speed, elite.data.move_speed * elite.chase_speed_scale),
		"Elite chase must use its configured speed"
	)
	crab.queue_free()
	elite.queue_free()
	await physics_frame


func _check_disengage(scene: PackedScene, active_attack: bool) -> void:
	player.position = Vector3(2, 0, 0)
	var crab := scene.instantiate() as Crab
	arena.add_child(crab)
	crab.set_physics_process(false)
	await create_timer(0.2).timeout
	crab.set_target(player)
	var hitbox := crab.active_hitbox if active_attack else crab.contact_hitbox
	_check(is_instance_valid(hitbox), "Crab must have the expected attack hitbox")
	if not is_instance_valid(hitbox):
		crab.queue_free()
		return
	hitbox.begin_attack(1.0)
	player.accepts_damage = false
	hitbox.try_hit(player_hurtbox)
	_check(crab.can_chase_target(), "Damage rejected by player must not stop pursuit")
	player.accepts_damage = true
	hitbox.try_hit(player_hurtbox)
	_check(not crab.has_target(), "Confirmed hit must clear Crab's target")
	crab._refresh_target()
	_check(not crab.can_chase_target(), "Crab must ignore player still in detection area")
	crab.anger_remaining = 5.0
	crab._apply_detection_radius()
	crab.set_physics_process(true)
	await create_timer(0.15).timeout
	_check(not crab.can_chase_target(), "Detector refresh must not cancel the ignore state")
	crab.set_physics_process(false)
	var patrol := crab.get_node("States/Patrol") as CrabPatrol
	patrol._update(0.1)
	_check(patrol._chase_direction.is_zero_approx(), "Crab must patrol while ignoring player")
	player.position = Vector3(20, 0, 0)
	await create_timer(0.2).timeout
	_check(crab._ignored_player == null, "Player leaving detection must clear ignore state")
	player.position = Vector3(2, 0, 0)
	await create_timer(0.2).timeout
	_check(crab.can_chase_target(), "Crab must chase again when player re-enters detection")
	crab.queue_free()
	await physics_frame


func _check_eggs() -> void:
	player.position = Vector3(-12, 0, -12)
	var elite := ELITE_SCENE.instantiate() as EliteCrab
	elite.position = Vector3(8, 0, 0)
	elite.egg_count_min = 2
	elite.egg_count_max = 2
	elite.egg_flight_duration = 0.2
	elite.egg_hatch_delay = 0.1
	arena.add_child(elite)
	await physics_frame
	var half_hp := elite.hp.get_max_hp() * 0.5
	elite.receive_damage(_damage(AttackData.DeliveryType.MELEE, half_hp))
	_check(elite.egg_spawn_used, "Half health should reserve the egg ability")
	await create_timer(1.5).timeout
	var children := 0
	for child in arena.get_children():
		if child is Crab and not child is EliteCrab:
			children += 1
	_check(children == 2, "Two eggs should hatch two normal crabs")
	elite.hp.heal(half_hp)
	elite.receive_damage(_damage(AttackData.DeliveryType.MELEE, half_hp))
	await create_timer(0.8).timeout
	var children_after := 0
	for child in arena.get_children():
		if child is Crab and not child is EliteCrab:
			children_after += 1
	_check(children_after == children, "Egg ability must not repeat after healing")
	elite.queue_free()
	await physics_frame
	var lethal := ELITE_SCENE.instantiate() as EliteCrab
	lethal.position = Vector3(-8, 0, 0)
	arena.add_child(lethal)
	lethal.receive_damage(_damage(AttackData.DeliveryType.MELEE, lethal.hp.get_max_hp()))
	_check(not lethal.egg_spawn_used, "Lethal damage should not reserve egg spawning")
	lethal.queue_free()


func _damage(delivery: int, amount: float) -> DamageContext:
	var result := DamageContext.new()
	result.source = player
	result.source_team = CombatTeams.PLAYER
	result.base_amount_hp = amount
	result.amount_hp = amount
	result.delivery_type = delivery
	return result


func _check_egg_lifecycle() -> void:
	var elite := ELITE_SCENE.instantiate() as EliteCrab
	elite.position = Vector3(8, 0, -8)
	elite.egg_count_min = 2
	elite.egg_count_max = 2
	elite.egg_flight_duration = 1.0
	elite.egg_hatch_delay = 0.1
	elite.egg_warning_duration = 0.08
	elite.egg_shake_distance = 0.16
	elite.egg_shake_frequency = 9.0
	arena.add_child(elite)
	await physics_frame
	var before := _normal_crab_count()
	elite.receive_damage(_damage(AttackData.DeliveryType.MELEE, elite.hp.get_max_hp() * 0.5))
	await create_timer(0.2).timeout
	var eggs := 0
	for child in arena.get_children():
		if child is CrabEgg:
			eggs += 1
			_check(is_equal_approx(child.hatch_delay, elite.egg_hatch_delay), "Egg must inherit incubation time")
			_check(is_equal_approx(child.warning_duration, elite.egg_warning_duration), "Egg must inherit warning time")
			_check(is_equal_approx(child.shake_distance, elite.egg_shake_distance), "Egg must inherit shake distance")
			_check(is_equal_approx(child.shake_frequency, elite.egg_shake_frequency), "Egg must inherit shake frequency")
	_check(eggs == 2, "Elite should release eggs before dying")
	elite.receive_damage(_damage(AttackData.DeliveryType.MELEE, elite.hp.current_hp))
	await create_timer(1.3).timeout
	_check(_normal_crab_count() == before + 2, "Launched eggs must hatch after Elite dies")
	if is_instance_valid(elite):
		elite.queue_free()
	var obstacle := StaticBody3D.new()
	obstacle.collision_layer = CombatLayers.WORLD
	var collision := CollisionShape3D.new()
	var block := BoxShape3D.new()
	block.size = Vector3(3, 2, 3)
	collision.shape = block
	obstacle.add_child(collision)
	arena.add_child(obstacle)
	obstacle.position = Vector3(0, 1, 10)
	await physics_frame
	before = _normal_crab_count()
	var egg := EGG_SCENE.instantiate() as CrabEgg
	egg.hatch_delay = 0.0
	egg.setup(Vector3(0, 2, 10), Vector3(0, 0, 10), 0.2, 1.0)
	arena.add_child(egg)
	await create_timer(0.4).timeout
	_check(_normal_crab_count() == before, "Egg must not hatch inside an obstacle")
	obstacle.queue_free()


func _check_egg_entity() -> void:
	player.position = Vector3(-20, 0, -20)
	var before := _normal_crab_count()
	var egg := EGG_SCENE.instantiate() as CrabEgg
	egg.hatch_delay = 0.8
	egg.warning_duration = 0.4
	egg.shake_distance = 0.2
	egg.shake_frequency = 7.0
	egg.setup(Vector3(-15, 1, 10), Vector3(-15, 0, 10), 0.2, 0.5)
	arena.add_child(egg)
	await create_timer(0.35).timeout
	_check(is_instance_valid(egg) and egg._landed, "Egg should land and wait before hatching")
	_check(egg.body.collision_layer == CombatLayers.ENEMY_BODY, "Egg must have a solid body")
	_check(egg.hurtbox.collision_layer == CombatLayers.ENEMY_HURTBOX, "Egg needs an enemy hurtbox")
	var enemy_damage := _damage(AttackData.DeliveryType.MELEE, 1.0)
	enemy_damage.source_team = CombatTeams.ENEMY
	_check(is_zero_approx(egg.hurtbox.take_damage(enemy_damage)), "Enemy attacks must not damage eggs")
	_check(_normal_crab_count() == before, "Egg must not hatch before incubation ends")
	await create_timer(0.4).timeout
	var shook := false
	for _frame in 10:
		await physics_frame
		if is_instance_valid(egg) and absf(egg.sprite.position.x) > 0.01:
			shook = true
	_check(shook, "Egg should shake during its warning period")
	await create_timer(0.45).timeout
	_check(_normal_crab_count() == before + 1, "Egg should hatch exactly one crab after incubation")

	before = _normal_crab_count()
	egg = EGG_SCENE.instantiate() as CrabEgg
	egg.hatch_delay = 0.6
	egg.setup(Vector3(0, 1, 15), Vector3(0, 0, 15), 0.2, 0.5)
	arena.add_child(egg)
	await create_timer(0.3).timeout
	var hitbox := HitBox.new()
	hitbox.actor = player
	hitbox.team = CombatTeams.PLAYER
	hitbox.collision_layer = CombatLayers.PLAYER_ATTACK
	hitbox.collision_mask = CombatLayers.ENEMY_HURTBOX
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.8
	collision.shape = shape
	hitbox.add_child(collision)
	arena.add_child(hitbox)
	hitbox.global_position = egg.global_position
	await physics_frame
	hitbox.begin_attack(1.0)
	hitbox.sample_shape()
	_check(egg.is_queued_for_deletion(), "A player hit must destroy the 1 HP egg")
	_check(arena.has_node("DestructibleSmoke"), "Destroying an egg must produce smoke")
	await create_timer(0.9).timeout
	_check(_normal_crab_count() == before, "A destroyed egg must not hatch")
	hitbox.queue_free()

	egg = EGG_SCENE.instantiate() as CrabEgg
	var other_egg := EGG_SCENE.instantiate() as CrabEgg
	for flying_egg in [egg, other_egg]:
		flying_egg.hatch_delay = 1.0
	egg.setup(Vector3(14, 2, 12), Vector3(12, 0, 12), 0.8, 1.0)
	other_egg.setup(Vector3(14, 2, 12), Vector3(16, 0, 12), 0.8, 1.0)
	arena.add_child(egg)
	arena.add_child(other_egg)
	hitbox = HitBox.new()
	hitbox.actor = player
	hitbox.team = CombatTeams.PLAYER
	hitbox.collision_mask = CombatLayers.ENEMY_HURTBOX
	collision = CollisionShape3D.new()
	collision.shape = shape
	hitbox.add_child(collision)
	arena.add_child(hitbox)
	hitbox.global_position = Vector3(14, 2, 12)
	await physics_frame
	hitbox.begin_attack(1.0)
	hitbox.sample_shape()
	_check(egg.hurtbox.collision_layer == 0 and other_egg.hurtbox.collision_layer == 0, "Flying eggs must not intercept attacks")
	_check(is_zero_approx(egg.receive_damage(_damage(AttackData.DeliveryType.MELEE, 1.0))), "Flying eggs must reject direct damage")
	_check(is_equal_approx(egg._hp, 1.0) and is_equal_approx(other_egg._hp, 1.0), "One attack must not damage eggs as they launch")
	hitbox.end_attack()
	hitbox.queue_free()
	await create_timer(0.9).timeout
	_check(egg._landed and other_egg._landed, "Surviving eggs should land")
	_check(egg.hurtbox.enabled and egg.hurtbox.collision_layer == CombatLayers.ENEMY_HURTBOX, "Landed eggs must become vulnerable")
	_check(is_equal_approx(egg.hurtbox.take_damage(_damage(AttackData.DeliveryType.MELEE, 0.4)), 0.4), "Landed egg should have one HP")
	_check(not egg.is_queued_for_deletion(), "Partial damage must not destroy a landed egg")
	_check(is_equal_approx(egg.hurtbox.take_damage(_damage(AttackData.DeliveryType.MELEE, 0.6)), 0.6), "Remaining HP should be damageable after landing")
	_check(egg.is_queued_for_deletion(), "A landed egg should be destroyable")
	await create_timer(1.1).timeout
	_check(_normal_crab_count() == before + 1, "Only the surviving egg should hatch")


func _normal_crab_count() -> int:
	var count := 0
	for child in arena.get_children():
		if child is Crab and not child is EliteCrab:
			count += 1
	return count


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
