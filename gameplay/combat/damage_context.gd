class_name DamageContext
extends RefCounted
## Snapshot có thể truy vết cho một lần damage lên đúng một target.

const Teams := preload("res://gameplay/combat/combat_teams.gd")
## Keep hit confirmation visible at zero knockback and cap presentation independently of physics.
const MIN_IMPACT_SCALE: float = 0.45
const MAX_IMPACT_SCALE: float = 2.0

# Soure gây daamge
var source: Node
var target: Node
var source_team: int = Teams.NONE

# Thông tin nguồn
var attack_id: int = 0
var base_amount_hp: float = 1
var amount_hp: float = 1
var critical_rate: float = 0.0
var critical_damage_multiplier: float = 1.5
var is_critical: bool = false

# đánh dấu tag loại tấn công, đánh thường != mất máu theo thời gian
var tag: StringName = &"normal"
var weapon_category: int = -1
var origin: Vector3 = Vector3.ZERO
var direction: Vector3 = Vector3.BACK
var target_defeated: bool = false
var knockback_multiplier: float = 1.0

# Mỗi Charm ghi kết quả theo ID để event lặp không roll hoặc áp dụng lần hai.
var proc_results: Dictionary[StringName, Dictionary] = {}

var _critical_resolved: bool = false


func create_hit_copy(hit_target: Node = null) -> DamageContext:
	var result := DamageContext.new()
	result.source = source
	result.target = hit_target
	result.source_team = source_team
	result.attack_id = attack_id
	result.base_amount_hp = base_amount_hp
	result.amount_hp = base_amount_hp
	result.critical_rate = critical_rate
	result.critical_damage_multiplier = critical_damage_multiplier
	result.tag = tag
	result.weapon_category = weapon_category
	result.origin = origin
	result.direction = direction
	result.knockback_multiplier = knockback_multiplier
	return result


## Called once per target hit, before outgoing charm modifiers.
func resolve_critical() -> void:
	if _critical_resolved:
		return
	_critical_resolved = true
	is_critical = critical_rate > 0.0 and randf() < clampf(critical_rate, 0.0, 1.0)
	if is_critical:
		amount_hp *= maxf(1.0, critical_damage_multiplier)


func is_normal_attack() -> bool:
	return tag == &"normal"


## Attack strength before target resistance; bosses still receive readable hit confirmation.
## Square-root scaling preserves differences without doubling every screen effect at +100% KB.
func get_impact_scale() -> float:
	if not is_finite(knockback_multiplier) or knockback_multiplier <= 0.0:
		return MIN_IMPACT_SCALE
	return clampf(sqrt(knockback_multiplier), MIN_IMPACT_SCALE, MAX_IMPACT_SCALE)


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
