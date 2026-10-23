class_name EnemyContactDamage
extends Node

@export var hitbox: HitBox
@export_range(0, 100000, 1) var damage_override: int = 0
@export var attack_id: int = 0
@export var tag: StringName = &"contact"

var enemy: EnemyBase


func _ready() -> void:
	enemy = get_parent() as EnemyBase
	if enemy == null or not is_instance_valid(hitbox):
		push_error("EnemyContactDamage: EnemyBase parent and HitBox are required")
		return
	enemy.died.connect(disable)
	call_deferred("enable")


func enable() -> bool:
	if enemy == null or enemy.dead or enemy.data == null or not is_instance_valid(hitbox):
		return false
	var amount_hp := damage_override if damage_override > 0 else enemy.data.attack_damage
	if amount_hp <= 0:
		return false
	hitbox.actor = enemy
	hitbox.team = enemy.team
	hitbox.collision_layer = CombatLayers.ENEMY_ATTACK
	hitbox.collision_mask = CombatLayers.PLAYER_HURTBOX
	return hitbox.begin_attack(amount_hp, attack_id, tag, HitBox.RehitPolicy.ONCE_PER_CONTACT)


func disable() -> void:
	if is_instance_valid(hitbox):
		hitbox.end_attack()
