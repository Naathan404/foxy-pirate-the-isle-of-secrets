class_name CrabPatrol
extends EnemyPatrol

## Crab-specific GDD rule: after surviving a hit, resume patrol on the other axis.

var _change_axis_after_hit: bool = false


func _enter() -> void:
	super()
	if _change_axis_after_hit:
		_change_to_orthogonal_axis()
		_change_axis_after_hit = false
	if not enemy.damaged.is_connected(_on_enemy_damaged):
		enemy.damaged.connect(_on_enemy_damaged)


func _exit() -> void:
	if enemy.damaged.is_connected(_on_enemy_damaged):
		enemy.damaged.disconnect(_on_enemy_damaged)
	super()


func _on_enemy_damaged(_applied_hp: float) -> void:
	if enemy.hp.is_alive():
		_change_axis_after_hit = true
