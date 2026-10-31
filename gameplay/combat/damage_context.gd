class_name DamageContext
extends RefCounted
## Snapshot có thể truy vết cho một lần damage lên đúng một target.

const Teams := preload("res://gameplay/combat/combat_teams.gd")

# Soure gây daamge
var source: Node
var target: Node
var source_team: int = Teams.NONE

# Thông tin nguồn
var attack_id: int = 0
var base_amount_hp: float = 1
var amount_hp: float = 1

# đánh dấu tag loại tấn công, đánh thường != mất máu theo thời gian
var tag: StringName = &"normal"
var weapon_category: int = -1
var origin: Vector3 = Vector3.ZERO
var direction: Vector3 = Vector3.BACK
var target_defeated: bool = false
var knockback_multiplier: float = 1.0

# Mỗi Charm ghi kết quả theo ID để event lặp không roll hoặc áp dụng lần hai.
var proc_results: Dictionary[StringName, Dictionary] = {}


func create_hit_copy(hit_target: Node = null) -> DamageContext:
	var result := DamageContext.new()
	result.source = source
	result.target = hit_target
	result.source_team = source_team
	result.attack_id = attack_id
	result.base_amount_hp = base_amount_hp
	result.amount_hp = base_amount_hp
	result.tag = tag
	result.weapon_category = weapon_category
	result.origin = origin
	result.direction = direction
	result.knockback_multiplier = knockback_multiplier
	return result


func is_normal_attack() -> bool:
	return tag == &"normal"


func is_melee_normal_attack() -> bool:
	return is_normal_attack() and weapon_category == WeaponData.WeaponCategory.MELEE


func has_proc_result(charm_id: StringName) -> bool:
	return proc_results.has(charm_id)


func record_proc(
	charm_id: StringName, success: bool, reason: StringName, amount_multiplier: float = 1.0
) -> void:
	if charm_id.is_empty() or proc_results.has(charm_id):
		return
	proc_results[charm_id] = {
		&"success": success,
		&"reason": reason,
		&"amount_multiplier": amount_multiplier,
	}
