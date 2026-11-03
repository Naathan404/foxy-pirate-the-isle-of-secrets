class_name CrescentCleaveAttack
extends Node3D
## Một lần quét vùng bán nguyệt phía trước và chỉ gây sát thương một lần mỗi mục tiêu.

signal target_hit(target: Node, applied_hp: float)

@export var hit_area: Area3D

var context: AttackContext
var radius_units: float = 2.8
var half_angle_degrees: float = 90.0
var active_seconds: float = 0.12

var _active: bool = false
var _remaining_seconds: float = 0.0
var _hit_actor_ids: Dictionary[int, bool] = {}


func _ready() -> void:
	set_physics_process(false)
	if is_instance_valid(hit_area):
		hit_area.area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	if not _active:
		return
	if not is_instance_valid(context) or not is_instance_valid(context.actor):
		_finish()
		return
	if bool(context.actor.get("dead")):
		_finish()
		return
	for area: Area3D in hit_area.get_overlapping_areas():
		_try_hit(area)
	_remaining_seconds = maxf(0.0, _remaining_seconds - maxf(0.0, delta))
	if _remaining_seconds <= 0.0:
		_finish()


func _exit_tree() -> void:
	_active = false
	_hit_actor_ids.clear()


func validate() -> bool:
	return is_instance_valid(hit_area)


func activate() -> bool:
	if not validate() or context == null or not is_instance_valid(context.actor):
		return false
	if context.direction.is_zero_approx() or context.damage_hp <= 0:
		return false
	look_at(global_position + context.direction, Vector3.UP)
	var shape_node := hit_area.get_node_or_null("CollisionShape3D") as CollisionShape3D
	var sphere := shape_node.shape as SphereShape3D if shape_node != null else null
	if sphere == null:
		return false
	sphere.radius = radius_units
	_hit_actor_ids.clear()
	_remaining_seconds = maxf(0.01, active_seconds)
	_active = true
	set_physics_process(true)
	return true


func cancel() -> void:
	_finish()


func _on_area_entered(area: Area3D) -> void:
	if _active:
		_try_hit(area)


func _try_hit(area: Area3D) -> void:
	if not area is HurtBox:
		return
	var hurtbox := area as HurtBox
	if (
		not is_instance_valid(hurtbox.actor)
		or hurtbox.actor == context.actor
		or not hurtbox.actor is Node3D
	):
		return
	var target_id := hurtbox.actor.get_instance_id()
	if _hit_actor_ids.has(target_id):
		return
	var offset := (hurtbox.actor as Node3D).global_position - global_position
	offset.y = 0.0
	if offset.length() > radius_units:
		return
	var forward := context.direction.normalized()
	var target_direction := forward if offset.is_zero_approx() else offset.normalized()
	var minimum_dot := cos(deg_to_rad(clampf(half_angle_degrees, 0.0, 180.0)))
	if forward.dot(target_direction) < minimum_dot:
		return
	_hit_actor_ids[target_id] = true
	var damage := context.create_damage_context()
	var applied_hp := hurtbox.take_damage(damage)
	if applied_hp > 0:
		context.damage_applied.emit(damage, hurtbox.actor, applied_hp)
		target_hit.emit(hurtbox.actor, applied_hp)


func _finish() -> void:
	_active = false
	set_physics_process(false)
	queue_free()
