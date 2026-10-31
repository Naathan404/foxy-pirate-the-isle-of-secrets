class_name Barrel
extends EnemyBase

const BULLET_SCENE := preload("res://gameplay/enemies/barrel/barrel_bullet.tscn")

@export_range(0.1, 100.0, 0.1) var bullet_speed: float = 12.0
@export_group("Target Detection")
@export_range(0.1, 50.0, 0.1, "suffix:m") var player_detection_radius: float = 6.5:
	set(value):
		player_detection_radius = maxf(0.1, value)
		_configure_player_detector()
@export_group("Volley")
@export_range(1, 20, 1) var min_bullets_per_volley: int = 1
@export_range(1, 20, 1) var max_bullets_per_volley: int = 5
@export_range(0.0, 90.0, 1.0, "suffix:deg") var max_bullet_angle_offset_degrees: float = 20.0

var _attack_cooldown_remaining: float = 0.0
var _projectiles: Array[BarrelBullet] = []

@onready var bullet_spawn: Marker3D = $Direction/BulletSpawn


func get_bullet_count() -> int:
	var minimum := mini(min_bullets_per_volley, max_bullets_per_volley)
	var maximum := maxi(min_bullets_per_volley, max_bullets_per_volley)
	return randi_range(minimum, maximum)


func _ready() -> void:
	_configure_player_detector()
	if Engine.is_editor_hint():
		return
	died.connect(_clear_projectiles)
	super()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_configure_player_detector()


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


func fire_fan_volley(count: int, arc_degrees: float) -> void:
	if dead or data == null:
		return
	var bullet_count := maxi(1, count)
	var arc_radians := deg_to_rad(maxf(0.0, arc_degrees))
	var angle_step := 0.0 if bullet_count == 1 else arc_radians / float(bullet_count - 1)
	var start_angle := -arc_radians * 0.5
	for index in range(bullet_count):
		var angle := start_angle + angle_step * index
		_fire_in_direction(last_facing_direction.rotated(Vector3.UP, angle))


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
	_projectiles.append(bullet)
	bullet.tree_exited.connect(_on_projectile_tree_exited.bind(bullet), CONNECT_ONE_SHOT)


func _clear_projectiles() -> void:
	for projectile: BarrelBullet in _projectiles:
		if is_instance_valid(projectile):
			projectile.queue_free()
	_projectiles.clear()


func _on_projectile_tree_exited(projectile: BarrelBullet) -> void:
	_projectiles.erase(projectile)


func _configure_player_detector() -> void:
	if not is_inside_tree():
		return
	var collision := get_node_or_null("TargetDetector/CollisionShape3D") as CollisionShape3D
	if collision == null:
		return
	var shape := collision.shape as CylinderShape3D
	if shape != null and not is_equal_approx(shape.radius, player_detection_radius):
		shape.radius = player_detection_radius
