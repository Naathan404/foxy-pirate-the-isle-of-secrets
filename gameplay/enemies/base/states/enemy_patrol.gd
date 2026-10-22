class_name EnemyPatrol
extends EnemyState

## Reusable straight-line patrol. A child scene can use this directly or extend it.

@export var turn_on_wall: bool = true
@export var turn_at_ledge: bool = true
@export_range(0.0, 10.0, 0.1) var speed_scale: float = 1.0


func _update(delta: float) -> void:
	enemy.move_forward(delta, speed_scale)
	enemy.play_directional_animation(&"run")
	if turn_on_wall and enemy.is_front_blocked():
		enemy.turn_around()
	elif turn_at_ledge and not enemy.is_ground_ahead():
		enemy.turn_around()
