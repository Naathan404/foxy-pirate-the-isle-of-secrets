extends SceneTree

const BULLET := preload("res://gameplay/enemies/coral_skeleton/coral_skeleton_bullet.tscn")
const VFX_SCRIPT := preload("res://gameplay/enemies/coral_skeleton/coral_skeleton_vfx.gd")

class Target extends Node3D:
	var hits := 0
	func receive_damage(damage: DamageContext) -> float:
		hits += 1
		return damage.amount_hp

var arena: Node3D
var source: Node3D
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	arena = Node3D.new()
	root.add_child(arena)
	current_scene = arena
	source = Node3D.new()
	arena.add_child(source)
	var target := Target.new()
	target.position = Vector3(2, 3, 0)
	arena.add_child(target)
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
	var bullet := _spawn()
	await physics_frame
	_check(not bullet.shadow.visible, "Shadow should stay hidden with no ground below")
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = CombatLayers.WORLD
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(30, 0.5, 30)
	floor_collision.shape = floor_shape
	floor_body.add_child(floor_collision)
	floor_body.position = Vector3(0, -0.25, 0)
	arena.add_child(floor_body)
	await create_timer(0.05).timeout
	_check(bullet.shadow.visible, "Shadow did not project onto ground below bullet")
	_check(
		absf(bullet.shadow.global_position.y - 0.025) < 0.02,
		"Shadow did not snap near ground surface"
	)
	await create_timer(0.45).timeout
	_check(target.hits == 1, "Bullet did not hit player exactly once")
	_check(not is_instance_valid(bullet), "Bullet survived player collision")
	target.queue_free()
	await physics_frame
	var wall := StaticBody3D.new()
	wall.collision_layer = CombatLayers.WORLD
	var wall_collision := CollisionShape3D.new()
	var wall_shape := BoxShape3D.new()
	wall_shape.size = Vector3(0.4, 2, 2)
	wall_collision.shape = wall_shape
	wall.add_child(wall_collision)
	wall.position = Vector3(2, 3, 0)
	arena.add_child(wall)
	await physics_frame
	bullet = _spawn()
	await create_timer(0.5).timeout
	_check(not is_instance_valid(bullet), "Bullet survived collision with wall")
	wall.queue_free()
	await physics_frame
	var smoke_before := _count_smoke()
	bullet = _spawn()
	bullet.remaining = 0.05
	await create_timer(0.15).timeout
	_check(is_instance_valid(bullet), "Bullet skipped its death duration on expiry")
	_check(
		_count_smoke() > smoke_before,
		"Bullet did not spawn rising smoke VFX when dying"
	)
	await create_timer(0.25).timeout
	_check(not is_instance_valid(bullet), "Bullet did not finish dying after death duration")
	arena.queue_free()
	await process_frame
	if failures.is_empty():
		print("Coral Skeleton projectile tests passed")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _spawn() -> CoralSkeletonBullet:
	var bullet := BULLET.instantiate() as CoralSkeletonBullet
	bullet.setup(source, CombatTeams.ENEMY, Vector3.RIGHT, 10.0, 1.0, 3.0)
	arena.add_child(bullet)
	bullet.global_position = Vector3(0, 3, 0)
	return bullet


func _count_smoke() -> int:
	var count := 0
	for child in arena.get_children():
		if child.get_script() == VFX_SCRIPT and child.get("effect") == &"smoke":
			count += 1
	return count


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
