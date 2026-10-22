extends EnemyState


func _init() -> void:
	is_terminal = true


func _enter() -> void:
	enemy._set_horizontal_velocity(Vector3.ZERO)
	enemy.end_attack()
	enemy._play_death_animation()


func _update(_delta: float) -> void:
	enemy._set_horizontal_velocity(Vector3.ZERO)
