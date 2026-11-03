class_name TideGrappleAttack
extends Node3D
## Raycast mỏ neo, gây sát thương rồi chọn bên bị kéo theo loại mục tiêu.

signal grapple_resolved(result: StringName, target: Node)

const RESULT_MISS: StringName = &"miss"
const RESULT_TARGET_PULLED: StringName = &"target_pulled"
const RESULT_ACTOR_PULLED_LARGE: StringName = &"actor_pulled_large"
const RESULT_ACTOR_PULLED_BOSS: StringName = &"actor_pulled_boss"
const RESULT_ACTOR_PULLED_TERRAIN: StringName = &"actor_pulled_terrain"
const RESULT_TARGET_HIT: StringName = &"target_hit"

@export var raycast: RayCast3D

var context: AttackContext
var range_units: float = 4.0
var pull_stop_distance: float = 1.0
var pull_speed_units_per_second: float = 16.0
var stun_seconds: float = 1.0


func validate() -> bool:
	return is_instance_valid(raycast)


func activate() -> bool:
	if not validate() or context == null or not is_instance_valid(context.actor):
		return false
	if context.direction.is_zero_approx() or context.damage_hp <= 0 or range_units <= 0.0:
		return false
	look_at(global_position + context.direction, Vector3.UP)
	raycast.target_position = Vector3(0.0, 0.0, -range_units)
	raycast.enabled = true
	raycast.force_raycast_update()
	if raycast.is_colliding():
		resolve_hit(raycast.get_collider(), raycast.get_collision_point())
	else:
		grapple_resolved.emit(RESULT_MISS, null)
	queue_free()
	return true


func resolve_hit(collider: Object, hit_position: Vector3) -> StringName:
	if collider == null or context == null or not is_instance_valid(context.actor):
		grapple_resolved.emit(RESULT_MISS, null)
		return RESULT_MISS
	var target := _get_damage_target(collider)
	if target == null:
		var terrain_result := _pull_actor(hit_position, RESULT_ACTOR_PULLED_TERRAIN)
		grapple_resolved.emit(terrain_result, collider as Node)
		return terrain_result
	_apply_damage(collider, target)
	var result := _resolve_target_pull(target)
	grapple_resolved.emit(result, target)
	return result


func _get_damage_target(collider: Object) -> Node:
	if collider is HurtBox:
		var hurtbox := collider as HurtBox
		return hurtbox.actor if is_instance_valid(hurtbox.actor) else null
	if collider is Node and (collider as Node).has_method("receive_damage"):
		return collider as Node
	return null


func _apply_damage(collider: Object, target: Node) -> void:
	var damage := context.create_damage_context()
	var applied_hp := 0.0
	if collider is HurtBox:
		applied_hp = (collider as HurtBox).take_damage(damage)
	elif target.has_method("receive_damage"):
		applied_hp = float(target.call("receive_damage", damage))
	if applied_hp > 0:
		context.damage_applied.emit(damage, target, applied_hp)


func _resolve_target_pull(target: Node) -> StringName:
	if not target is Node3D:
		return RESULT_TARGET_HIT
	if target.has_method("apply_charm_grapple"):
		return (
			target.call(
				"apply_charm_grapple",
				context.actor,
				pull_stop_distance,
				pull_speed_units_per_second,
				stun_seconds
			)
			as StringName
		)
	return RESULT_TARGET_HIT


func _pull_actor(target_position: Vector3, result: StringName) -> StringName:
	if not context.actor.has_method("apply_charm_grapple_pull"):
		return RESULT_MISS
	var pulled := bool(
		context.actor.call(
			"apply_charm_grapple_pull",
			target_position,
			pull_stop_distance,
			pull_speed_units_per_second
		)
	)
	return result if pulled else RESULT_MISS
