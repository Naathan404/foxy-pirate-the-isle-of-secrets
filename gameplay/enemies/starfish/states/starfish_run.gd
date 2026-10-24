class_name StarfishRun
extends EnemyState

@export_range(0.0, 10.0, 0.1) var speed_scale: float = 1.0
@export var turn_on_wall: bool = true
@export var turn_at_ledge: bool = true


func _enter() -> void:
	enemy.play_directional_animation(&"run")
	enemy._start_contact_damage()


func _exit() -> void:
	enemy._stop_contact_damage()


func _update(delta: float) -> void:
	if enemy.has_target():
		enemy.face_target()
		request_state(&"attack")
		return
	enemy.move_forward(delta, speed_scale)
	enemy.play_directional_animation(&"run")
	if turn_on_wall and enemy.is_front_blocked():
		enemy.turn_around()
	elif turn_at_ledge and not enemy.is_ground_ahead():
		enemy.turn_around()
