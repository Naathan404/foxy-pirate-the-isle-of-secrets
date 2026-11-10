extends SceneTree

const BARREL := preload("res://gameplay/enemies/barrel/barrel.tscn")
const BULLET := preload("res://gameplay/enemies/barrel/barrel_bullet.tscn")

class Target extends Node3D:
	var hits: int = 0
	var last_knockback: float = -1.0

	func receive_damage(damage: DamageContext) -> float:
		hits += 1
		last_knockback = damage.knockback_multiplier
		return damage.amount_hp


var failures: Array[String] = []
var arena: Node3D
var source: Node3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	arena = Node3D.new()
	root.add_child(arena)
	source = Node3D.new()
	arena.add_child(source)
	await _check_aim()
	await _check_bounce(CombatLayers.WORLD)
	await _check_bounce(CombatLayers.ENEMY_BODY)
	await _check_player_hit()
	await _check_bounce_then_player()
	await _check_ground_bounces()
	await _check_lifetime()
	arena.queue_free()
	await process_frame
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("Barrel projectile scenarios passed")
	quit(0)


func _check_aim() -> void:
	var barrel := BARREL.instantiate() as Barrel
	arena.add_child(barrel)
	barrel.process_mode = Node.PROCESS_MODE_DISABLED
	var target := Node3D.new()
	arena.add_child(target)
	target.position = Vector3(5, 0, 3)
	barrel.set_target(target)
	barrel.bullet_lifetime = 7.0
	barrel.bullet_gravity = 12.0
	barrel.bullet_ground_bounce = 0.8
	barrel.aim_at_target()
	var expected := target.global_position - barrel.bullet_spawn.global_position
	expected.y = 0.0
	_check(barrel._get_firing_direction().distance_to(expected.normalized()) < 0.001, "Diagonal aim")
	barrel.fire_single()
	_check(barrel._projectiles.size() == 1, "Single shot was not spawned")
	if barrel._projectiles.size() == 1:
		var projectile := barrel._projectiles[0]
		_check(is_equal_approx(projectile.lifetime, 7.0), "Lifetime was not passed to bullet")
		_check(is_equal_approx(projectile.gravity, 12.0), "Gravity was not passed to bullet")
		_check(is_equal_approx(projectile.ground_bounce, 0.8), "Bounce was not passed to bullet")
		_check(
			barrel._projectiles[0]._direction.distance_to(expected.normalized()) < 0.001,
			"Single shot did not aim at player"
		)
	barrel._clear_projectiles()
	barrel.fire_fan_volley(5, 50.0)
	_check(barrel._projectiles.size() == 5, "Fan did not spawn five bullets")
	if barrel._projectiles.size() == 5:
		_check(
			barrel._projectiles[2]._direction.distance_to(expected.normalized()) < 0.001,
			"Fan center did not aim at player"
		)
	barrel._clear_projectiles()
	barrel.set_target(null)
	_check(not barrel.can_trigger_attack(), "Targetless aiming should pause")
	barrel.queue_free()
	target.queue_free()
	await process_frame


func _check_bounce(layer: int) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.3, 2, 3)
	collision.shape = box
	body.add_child(collision)
	arena.add_child(body)
	body.position = Vector3(2, 5, 0)
	await physics_frame
	var bullet := _spawn_bullet(Vector3(0, 5, 0), Vector3.RIGHT)
	await create_timer(0.35).timeout
	_check(is_instance_valid(bullet) and not bullet._finished, "Bullet ended on obstacle")
	if is_instance_valid(bullet) and not bullet._finished:
		_check(bullet._direction.x < -0.9, "Bullet did not reflect from obstacle")
		bullet.finish()
	_check(body.position.is_equal_approx(Vector3(2, 5, 0)), "Obstacle was pushed")
	body.queue_free()
	await physics_frame


func _check_player_hit() -> void:
	var target := Target.new()
	arena.add_child(target)
	target.position = Vector3(2, 5, 0)
	var hurtbox := HurtBox.new()
	hurtbox.actor = target
	hurtbox.team = CombatTeams.PLAYER
	hurtbox.collision_layer = CombatLayers.PLAYER_HURTBOX
	hurtbox.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.5
	collision.shape = shape
	hurtbox.add_child(collision)
	target.add_child(hurtbox)
	await physics_frame
	_spawn_bullet(Vector3(0, 5, 0), Vector3.RIGHT)
	await create_timer(0.35).timeout
	_check(target.hits == 1, "Player did not receive exactly one hit")
	_check(is_zero_approx(target.last_knockback), "Player hit applied knockback")
	target.queue_free()
	await physics_frame


func _check_bounce_then_player() -> void:
	var wall := StaticBody3D.new()
	wall.collision_layer = CombatLayers.WORLD
	var wall_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.3, 2, 3)
	wall_shape.shape = box
	wall.add_child(wall_shape)
	arena.add_child(wall)
	wall.position = Vector3(2, 5, 0)
	var target := Target.new()
	arena.add_child(target)
	target.position = Vector3(-1, 5, 0)
	var hurtbox := HurtBox.new()
	hurtbox.actor = target
	hurtbox.team = CombatTeams.PLAYER
	hurtbox.collision_layer = CombatLayers.PLAYER_HURTBOX
	hurtbox.collision_mask = 0
	var target_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.5
	target_shape.shape = sphere
	hurtbox.add_child(target_shape)
	target.add_child(hurtbox)
	await physics_frame
	_spawn_bullet(Vector3(0, 5, 0), Vector3.RIGHT)
	await create_timer(0.6).timeout
	_check(target.hits == 1, "Bullet did not hit player after reflecting")
	wall.queue_free()
	target.queue_free()
	await physics_frame


func _check_ground_bounces() -> void:
	var ground := StaticBody3D.new()
	ground.collision_layer = CombatLayers.WORLD
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(40, 0.5, 10)
	collision.shape = shape
	ground.add_child(collision)
	arena.add_child(ground)
	ground.position = Vector3(0, -0.25, 0)
	await physics_frame
	var previous_impacts: Array[int] = []
	for child in arena.get_children():
		if child.name.begins_with("BarrelBulletImpact"):
			previous_impacts.append(child.get_instance_id())
	var bullet := _spawn_bullet(Vector3(0, 1.2, 0), Vector3.ZERO)
	bullet.gravity = 22.0
	bullet.ground_bounce = 0.95
	var moving := _spawn_bullet(Vector3(-4, 1.12, 2), Vector3.RIGHT)
	moving._velocity = Vector3.RIGHT * 3.6
	moving.gravity = 22.0
	moving.ground_bounce = 0.95
	var previous_y := 0.0
	var bounce_count := 0
	var previous_moving_y := 0.0
	var moving_bounces := 0
	var peak_after_bounce := 0.0
	var impact_seen := false
	for _frame in 150:
		await physics_frame
		if not is_instance_valid(bullet):
			break
		if previous_y < 0.0 and bullet._velocity.y > 0.0:
			bounce_count += 1
		previous_y = bullet._velocity.y
		if previous_moving_y < 0.0 and moving._velocity.y > 0.0:
			moving_bounces += 1
		previous_moving_y = moving._velocity.y
		if moving_bounces > 0:
			peak_after_bounce = maxf(peak_after_bounce, moving.global_position.y)
		for child in arena.get_children():
			if (
				child.name.begins_with("BarrelBulletImpact")
				and not previous_impacts.has(child.get_instance_id())
			):
				impact_seen = true
	_check(bounce_count >= 2, "Bullet did not bounce repeatedly on ground")
	_check(moving_bounces >= 4, "Moving bullet did not bounce frequently on ground")
	_check(peak_after_bounce >= 0.7, "Moving bullet bounce is too low")
	_check(impact_seen, "Ground bounce did not spawn impact VFX")
	if is_instance_valid(bullet):
		bullet.finish()
	if is_instance_valid(moving):
		moving.finish()
	ground.queue_free()
	await physics_frame


func _check_lifetime() -> void:
	var bullet := _spawn_bullet(Vector3(0, 5, 0), Vector3.FORWARD)
	bullet._remaining_lifetime = 0.05
	await create_timer(0.15).timeout
	_check(not is_instance_valid(bullet), "Expired bullet was not removed")


func _spawn_bullet(position: Vector3, direction: Vector3) -> BarrelBullet:
	var bullet := BULLET.instantiate() as BarrelBullet
	bullet.gravity = 0.0
	bullet.launch(source, CombatTeams.ENEMY, direction, 10.0, 2.0)
	arena.add_child(bullet)
	bullet.global_position = position
	return bullet


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
