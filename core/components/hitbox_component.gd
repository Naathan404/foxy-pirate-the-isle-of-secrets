class_name HitBox
extends Area3D

@export var actor: Node
@export var team: int = 1

var _active: bool = false
var _damage: DamageContext
var _hit_actors: Dictionary = {}


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	set_physics_process(false)


func _physics_process(_delta: float) -> void:
	for area in get_overlapping_areas():
		_on_area_entered(area)


func begin_attack(amount_hp: int, attack_id: int = 0, tag: StringName = &"normal") -> bool:
	end_attack()
	if not is_instance_valid(actor) or amount_hp <= 0:
		return false
	_damage = DamageContext.new()
	_damage.source = actor
	_damage.source_team = team
	_damage.amount_hp = amount_hp
	_damage.attack_id = attack_id
	_damage.tag = tag
	_active = true
	set_physics_process(true)
	return true


func end_attack() -> void:
	_active = false
	_damage = null
	_hit_actors.clear()
	set_physics_process(false)


func _on_area_entered(area: Area3D) -> void:
	if not _active or not area is HurtBox:
		return
	var hurtbox := area as HurtBox
	if not is_instance_valid(hurtbox.actor):
		return
	var target_id := hurtbox.actor.get_instance_id()
	if _hit_actors.has(target_id):
		return
	# Reserve before dispatch because damage callbacks can cancel the attack.
	_hit_actors[target_id] = true
	if hurtbox.take_damage(_damage) <= 0:
		_hit_actors.erase(target_id)
