extends EnemyState


func _enter() -> void:
	enemy._set_horizontal_velocity(Vector3.ZERO)
	enemy.play_directional_animation(&"idle")


func _update(_delta: float) -> void:
	enemy._set_horizontal_velocity(Vector3.ZERO)
