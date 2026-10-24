class_name Barrel
extends EnemyBase

const BULLET_SCENE := preload("res://gameplay/enemies/barrel/barrel_bullet.tscn")

@export_range(0.1, 100.0, 0.1) var bullet_speed: float = 12.0
@export_group("Volley")
@export_range(1, 20, 1) var min_bullets_per_volley: int = 1
@export_range(1, 20, 1) var max_bullets_per_volley: int = 5
@export_range(0.0, 90.0, 1.0, "suffix:deg") var max_bullet_angle_offset_degrees: float = 20.0

var _attack_cooldown_remaining: float = 0.0

@onready var bullet_spawn: Marker3D = $Direction/BulletSpawn


func get_bullet_count() -> int:
	var minimum := mini(min_bullets_per_volley, max_bullets_per_volley)
	var maximum := maxi(min_bullets_per_volley, max_bullets_per_volley)
	return randi_range(minimum, maximum)


func start_attack_cooldown(duration: float) -> void:
	_attack_cooldown_remaining = maxf(0.0, duration)


func update_attack_cooldown(delta: float) -> bool:
	_attack_cooldown_remaining = maxf(0.0, _attack_cooldown_remaining - maxf(0.0, delta))
	return _attack_cooldown_remaining <= 0.0


func fire() -> void:
	if dead or data == null:
		return
	var maximum_offset := deg_to_rad(max_bullet_angle_offset_degrees)
	var offset := randf_range(-maximum_offset, maximum_offset)
	_fire_in_direction(last_facing_direction.rotated(Vector3.UP, offset))


func aim_at_target() -> bool:
	if not has_target():
		return false
	var offset := target.global_position - global_position
	if absf(offset.x) >= absf(offset.z):
		face_direction(Vector3.RIGHT if offset.x >= 0.0 else Vector3.LEFT)
	else:
		face_direction(Vector3.BACK if offset.z >= 0.0 else Vector3.FORWARD)
	return true


func _fire_in_direction(direction: Vector3) -> void:
	var bullet := BULLET_SCENE.instantiate() as BarrelBullet
	if bullet == null:
		return
	bullet.launch(self, team, direction, bullet_speed, data.attack_damage)
	var projectile_parent := get_tree().current_scene
	if not is_instance_valid(projectile_parent):
		projectile_parent = get_tree().root
	projectile_parent.add_child(bullet)
	bullet.global_position = bullet_spawn.global_position
