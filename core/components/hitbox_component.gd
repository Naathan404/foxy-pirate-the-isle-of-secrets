class_name HitBox
extends Area3D

signal hit_confirmed(
	damage: DamageContext,
	target: Node,
	applied_hp: int
)

enum RehitPolicy {
	ONCE_PER_ATTACK,
	ONCE_PER_CONTACT,
}

const Teams := preload("res://gameplay/combat/combat_teams.gd")

@export var actor: Node
@export_enum("None:0", "Player:1", "Enemy:2") var team: int = Teams.NONE

var _active: bool = false
var _damage: DamageContext
var _hit_actors: Dictionary = {}
var _contact_areas_by_actor: Dictionary = {}
var _rehit_policy: RehitPolicy = RehitPolicy.ONCE_PER_ATTACK


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	set_physics_process(false)


func _physics_process(_delta: float) -> void:
	for area in get_overlapping_areas():
		_on_area_entered(area)


func begin_attack(
	amount_hp: int,
	attack_id: int = 0,
	tag: StringName = &"normal",
	rehit_policy: RehitPolicy = RehitPolicy.ONCE_PER_ATTACK
) -> bool:
	end_attack()
	if not is_instance_valid(actor) or amount_hp <= 0:
		return false
	_damage = DamageContext.new()
	_damage.source = actor
	_damage.source_team = team
	_damage.amount_hp = amount_hp
	_damage.attack_id = attack_id
	_damage.tag = tag
	_rehit_policy = rehit_policy
	_active = true
	set_physics_process(true)
	return true


func end_attack() -> void:
	_active = false
	_damage = null
	_hit_actors.clear()
	_contact_areas_by_actor.clear()
	_rehit_policy = RehitPolicy.ONCE_PER_ATTACK
	set_physics_process(false)


func is_active() -> bool:
	return _active


func _on_area_entered(area: Area3D) -> void:
	if not _active or not area is HurtBox:
		return
	var hurtbox := area as HurtBox
	if not is_instance_valid(hurtbox.actor):
		return
	var target_id := hurtbox.actor.get_instance_id()
	if _rehit_policy == RehitPolicy.ONCE_PER_CONTACT:
		_register_contact_area(target_id, hurtbox.get_instance_id())
	if _hit_actors.has(target_id):
		return
	# Reserve before dispatch because damage callbacks can cancel the attack.
	_hit_actors[target_id] = true

	var damage = _damage
	var target = hurtbox.actor
	var applied_hp = hurtbox.take_damage(damage)
	if applied_hp <= 0:
		_hit_actors.erase(target_id)
		return

	hit_confirmed.emit(damage, target, applied_hp)


func _on_area_exited(area: Area3D) -> void:
	if not _active or _rehit_policy != RehitPolicy.ONCE_PER_CONTACT or not area is HurtBox:
		return
	var hurtbox := area as HurtBox
	if not is_instance_valid(hurtbox.actor):
		return
	var target_id := hurtbox.actor.get_instance_id()
	if not _contact_areas_by_actor.has(target_id):
		return
	var overlapping_areas: Dictionary = _contact_areas_by_actor[target_id]
	overlapping_areas.erase(hurtbox.get_instance_id())
	if not overlapping_areas.is_empty():
		return
	_contact_areas_by_actor.erase(target_id)
	_hit_actors.erase(target_id)


func _register_contact_area(target_id: int, area_id: int) -> void:
	var overlapping_areas: Dictionary = {}
	if _contact_areas_by_actor.has(target_id):
		overlapping_areas = _contact_areas_by_actor[target_id]
	else:
		overlapping_areas = {}
		_contact_areas_by_actor[target_id] = overlapping_areas
	overlapping_areas[area_id] = true
