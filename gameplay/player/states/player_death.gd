extends PlayerState

# vào death thì terminal luôn
func _init() -> void:
	is_terminal = true


func _enter() -> void:
	player.dead = true
	player.dash_buffer_remaining = 0.0
	player.attack_requested = false
	player.cancel_attack()
	player.set_horizontal_velocity(Vector3.ZERO)
	player.play_directional_animation("death", true)


func _update(_delta: float) -> void:
	player.set_horizontal_velocity(Vector3.ZERO)
