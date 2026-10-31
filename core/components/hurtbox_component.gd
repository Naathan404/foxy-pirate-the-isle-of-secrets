class_name HurtBox
extends Area3D

const Teams := preload("res://gameplay/combat/combat_teams.gd")

@export var actor: Node
@export_enum("None:0", "Player:1", "Enemy:2") var team: int = Teams.NONE

var enabled: bool = true


func take_damage(damage: DamageContext) -> float:
	if not enabled or damage == null or not is_instance_valid(actor):
		return 0
	if actor == damage.source or team == damage.source_team or damage.amount_hp <= 0:
		return 0
	if actor.has_method("receive_damage"):
		return float(actor.call("receive_damage", damage))
	if actor.has_method("take_damage"):
		return float(actor.call("take_damage", damage.amount_hp))
	return 0
