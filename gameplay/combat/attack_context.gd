class_name AttackContext
extends RefCounted

### Context chứa ngồn đánh, hướng, mục tiêu, damage

# Lượng máu thật sự mất
signal damage_applied(damage: DamageContext, target: Node, applied_hp: float)
signal damage_prepared(damage: DamageContext, target: Node)

const Teams := preload("res://gameplay/combat/combat_teams.gd")

var actor: Node3D
var team: int = Teams.NONE
var attack_id: int = 0
var action: StringName = &"normal"

# vị trí bắt đầu đòn đánh trong thế giời
var origin: Vector3
var direction: Vector3 = Vector3.BACK
var target_position: Vector3
var has_target: bool = false

var weapon: WeaponInstance
var weapon_category: int = -1

# chỉ số sau khi rèn
var damage_hp: float = 1
var range_units: float = 1.5
var hitbox_multiplier: float = 1.0
## Forge snapshot; the combo step's authored knockback is applied when building damage.
var knockback_multiplier: float = 1.0
var combo_index: int = 0
var combo_step: MeleeComboStep
var active_seconds: float = 0.125
var charge_progress: float = 0.0
var projectile_count: int = 1


# Tạo damage context cho 1 lần gây sát thương
func create_damage_context() -> DamageContext:
	var damage = DamageContext.new()
	damage.source = actor
	damage.source_team = team
	damage.attack_id = attack_id
	damage.base_amount_hp = damage_hp
	damage.amount_hp = damage_hp
	damage.tag = action
	damage.weapon_category = weapon_category
	damage.origin = origin
	damage.direction = direction
	damage.knockback_multiplier = knockback_multiplier
	if combo_step != null:
		damage.knockback_multiplier *= combo_step.knockback_multiplier
	return damage
