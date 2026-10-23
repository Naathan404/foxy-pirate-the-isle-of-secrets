class_name AttackContext
extends RefCounted

### Context chứa ngồn đánh, hướng, mục tiêu, damage

# Lượng máu thật sự mất
signal damage_applied(damage: DamageContext, target: Node, applied_hp: int)

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

# chỉ số sau khi rèn
var damage_hp: int = 1
var range_units: float = 1.5
var hitbox_multiplier: float = 1.0


# Tạo damage context cho 1 lần gây sát thương
func create_damage_context() -> DamageContext:
	var damage = DamageContext.new()
	damage.source = actor
	damage.source_team = team
	damage.attack_id = attack_id
	damage.amount_hp = damage_hp
	damage.tag = action
	return damage
