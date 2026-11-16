class_name CoralSkeleton
extends EnemyBase

enum ShotMode { FAN, SEQUENTIAL }

const BULLET := preload("res://gameplay/enemies/coral_skeleton/coral_skeleton_bullet.tscn")
const VFX := preload("res://gameplay/enemies/coral_skeleton/coral_skeleton_vfx.tscn")

@export_group("Detection and sleep")
@export var can_sleep := true
## Radius used while asleep. A player entering this area wakes the skeleton.
@export_range(0.1, 50.0, 0.1, "suffix:m") var sleep_detection_radius := 3.5:
	set(value):
		sleep_detection_radius = maxf(0.1, value)
		_queue_detection_update()
## Radius while awake, including the return and guard phases.
@export_range(0.1, 50.0, 0.1, "suffix:m") var detection_radius := 8.0:
	set(value):
		detection_radius = maxf(0.1, value)
		_queue_detection_update()
@export_range(0.0, 30.0, 0.1, "suffix:s") var sleep_delay := 4.0
@export_range(0.0, 5.0, 0.05, "suffix:s") var wake_duration := 0.35
## Time after the waking animation before the first attack can begin.
@export_range(0.0, 20.0, 0.1, "suffix:s") var wake_attack_delay := 1.0

@export_group("Movement")
@export_range(0.1, 30.0, 0.1) var shooting_range := 4.5
@export_range(0.1, 5.0, 0.1) var home_tolerance := 0.6
@export var roam_when_guarding := false
@export_range(0.5, 12.0, 0.1, "suffix:m") var guard_roam_radius := 3.5
@export_range(0.2, 5.0, 0.1, "suffix:s") var guard_roam_segment_time := 1.2
@export_range(0.2, 5.0, 0.1, "suffix:s") var guard_roam_pause_time := 1.0
@export_range(0.1, 5.0, 0.1) var return_segment_time := 0.8
@export_range(0.0, 3.0, 0.1) var return_pause_time := 0.35
@export_range(0.0, 80.0, 1.0, "suffix:deg") var return_min_turn_angle := 20.0
@export_range(0.0, 80.0, 1.0, "suffix:deg") var return_max_turn_angle := 49.0

@export_group("Shooting")
@export var randomize_shot_mode := true
@export var shot_mode: ShotMode = ShotMode.FAN
@export_range(1, 20, 1) var bullets_per_burst := 3
@export_range(0.0, 180.0, 1.0, "suffix:deg") var fan_angle := 30.0
@export_range(0.01, 5.0, 0.01, "suffix:s") var shot_interval := 0.2
@export_range(0.0, 5.0, 0.01, "suffix:s") var fire_delay := 0.4
@export_range(0.0, 20.0, 0.1, "suffix:s") var burst_cooldown := 2.0
@export_range(0.0, 5.0, 0.01, "suffix:s") var shoot_recovery_time := 0.24
@export_range(0.1, 50.0, 0.1) var bullet_speed := 10.0
@export_range(0.1, 20.0, 0.1) var bullet_lifetime := 3.0
@export_range(0.0, 3.0, 0.05, "suffix:m") var aim_height_offset := 0.85
@export_range(5.0, 80.0, 1.0, "suffix:deg") var max_aim_pitch_deg := 42.0

var home_position := Vector3.ZERO
var is_awake := false
var cooldown_remaining := 0.0
var _dust_remaining := 0.0
@onready var muzzle: Marker3D = $Direction/BulletSpawn


func _ready() -> void:
	home_position = global_position
	if not can_sleep:
		is_awake = true
	var collision := $TargetDetector/CollisionShape3D as CollisionShape3D
	collision.shape = collision.shape.duplicate()
	var shape := collision.shape as CylinderShape3D
	if shape != null:
		shape.radius = (
			maxf(sleep_detection_radius, detection_radius) if is_awake else sleep_detection_radius
		)
	super()
	target_changed.connect(_on_coral_target_changed)
	damaged.connect(_on_coral_damaged)
	died.connect(_on_coral_died)


func choose_shot_mode() -> ShotMode:
	if randomize_shot_mode:
		return ShotMode.FAN if randf() < 0.5 else ShotMode.SEQUENTIAL
	return shot_mode


func is_special_attack_ready() -> bool:
	return false


func fire_special_attack() -> void:
	pass


func notify_normal_burst_completed() -> void:
	pass


func notify_special_burst_completed() -> void:
	pass


func set_awake(value: bool) -> void:
	if is_awake == value:
		return
	is_awake = value
	_queue_detection_update()


func _queue_detection_update() -> void:
	if is_inside_tree() and is_node_ready():
		_apply_detection_radius.call_deferred()


func _apply_detection_radius() -> void:
	if not is_inside_tree():
		return
	var collision := get_node_or_null(^"TargetDetector/CollisionShape3D") as CollisionShape3D
	if collision == null:
		return
	var shape := collision.shape as CylinderShape3D
	if shape != null:
		shape.radius = (
			maxf(sleep_detection_radius, detection_radius) if is_awake else sleep_detection_radius
		)


func _physics_process(delta: float) -> void:
	cooldown_remaining = maxf(0.0, cooldown_remaining - maxf(0.0, delta))
	super(delta)
	_dust_remaining = maxf(0.0, _dust_remaining - maxf(0.0, delta))
	if not dead and _dust_remaining <= 0.0 and Vector2(velocity.x, velocity.z).length() > 0.5:
		_spawn_vfx(&"dust", global_position + Vector3.UP * 0.08)
		_dust_remaining = 0.3


func distance_from_home() -> float:
	var offset := global_position - home_position
	offset.y = 0.0
	return offset.length()


func safe_direction(direction: Vector3) -> bool:
	if direction.is_zero_approx():
		return false
	face_direction(direction)
	_refresh_direction_checks()
	return not is_front_blocked() and is_ground_ahead()


func choose_safe_direction(preferred: Vector3) -> Vector3:
	for angle in [0.0, 0.65, -0.65, 1.25, -1.25, 2.0, -2.0]:
		var candidate := preferred.rotated(Vector3.UP, angle).normalized()
		if safe_direction(candidate):
			return candidate
	return Vector3.ZERO


func fire_bullet(angle: float = 0.0, muzzle_effect: bool = true) -> void:
	if dead or not has_target() or data == null:
		return
	face_target()
	var direction := _compute_aim_direction(angle)
	var bullet := BULLET.instantiate() as CoralSkeletonBullet
	bullet.setup(self, team, direction, bullet_speed, data.attack_damage, bullet_lifetime)
	var parent := get_tree().current_scene
	if not is_instance_valid(parent):
		parent = get_tree().root
	parent.add_child(bullet)
	bullet.global_position = muzzle.global_position
	if muzzle_effect:
		_show_muzzle_effect()


func _compute_aim_direction(angle: float) -> Vector3:
	var to_aim := _get_target_aim_point() - muzzle.global_position
	var horizontal := Vector3(to_aim.x, 0.0, to_aim.z)
	var horiz_dist := horizontal.length()
	if horiz_dist < 0.05:
		horizontal = Vector3(last_facing_direction.x, 0.0, last_facing_direction.z)
		if horizontal.is_zero_approx():
			horizontal = Vector3.FORWARD
		horiz_dist = 0.05
	var forward_flat := horizontal.normalized()
	var max_pitch_rad := deg_to_rad(max_aim_pitch_deg)
	var pitch_rad := clampf(atan2(to_aim.y, horiz_dist), -max_pitch_rad, max_pitch_rad)
	var pitched := (forward_flat * cos(pitch_rad) + Vector3.UP * sin(pitch_rad)).normalized()
	return pitched.rotated(Vector3.UP, angle)


func _get_target_aim_point() -> Vector3:
	var hurt_shape := target.get_node_or_null(^"HurtBox/CollisionShape3D") as Node3D
	if is_instance_valid(hurt_shape):
		return hurt_shape.global_position
	var hurtbox := target.get_node_or_null(^"HurtBox") as Node3D
	if is_instance_valid(hurtbox):
		return hurtbox.global_position + Vector3.UP * aim_height_offset
	return target.global_position + Vector3.UP * aim_height_offset


func fire_fan() -> void:
	var count := maxi(1, bullets_per_burst)
	var arc := deg_to_rad(fan_angle)
	for index in count:
		var angle := 0.0 if count == 1 else -arc * 0.5 + arc * index / (count - 1)
		fire_bullet(angle, false)
	if not dead and has_target():
		_show_muzzle_effect()


func _show_muzzle_effect() -> void:
	_spawn_vfx(&"muzzle", muzzle.global_position)
	if is_instance_valid(visual) and visual.has_method("show_fire"):
		visual.call("show_fire")


func _spawn_vfx(kind: StringName, at: Vector3) -> void:
	if not is_inside_tree():
		return
	var parent := get_tree().current_scene
	if not is_instance_valid(parent):
		parent = get_tree().root
	var effect := VFX.instantiate()
	effect.effect = kind
	parent.add_child(effect)
	effect.global_position = at


func _on_coral_target_changed(next_target: Node3D) -> void:
	if is_instance_valid(next_target) and not dead:
		_spawn_vfx(&"alert", global_position + Vector3.UP * 2.3)


func _on_coral_damaged(_amount: float) -> void:
	if not dead:
		_spawn_vfx(&"hit", global_position + Vector3.UP * 1.2)


func _on_coral_died() -> void:
	_spawn_vfx(&"death", global_position + Vector3.UP * 0.9)
