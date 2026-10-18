class_name HurtBox
extends Area3D

@export var actor: Node
@export var team: int = 2

var enabled: bool = true


func take_damage(damage: DamageContext) -> int:
	if not enabled or damage == null or not is_instance_valid(actor):
		return 0
	if actor == damage.source or team == damage.source_team or damage.amount_hp <= 0:
		return 0
	if actor.has_method("receive_damage"):
		return int(actor.call("receive_damage", damage))
	if actor.has_method("take_damage"):
		return int(actor.call("take_damage", damage.amount_hp))
	return 0
