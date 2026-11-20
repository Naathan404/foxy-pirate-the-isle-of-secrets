class_name BossBehavior
extends Node
## Replace this node to give a boss its own AI, movement and attack lifecycle.

var boss: BossBase


func setup(owner_boss: BossBase) -> void:
	boss = owner_boss


func fight_started() -> void:
	pass


func fight_tick(_delta: float) -> void:
	pass


func can_receive_damage(_damage: DamageContext) -> bool:
	return true


func phase_entered(_index: int) -> void:
	pass


func fight_ended() -> void:
	pass
