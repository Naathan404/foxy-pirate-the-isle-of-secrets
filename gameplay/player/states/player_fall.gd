extends PlayerState


func _enter() -> void:
	player.play_directional_animation("fall", true)


func _update(delta: float) -> void:
	if player.dead:
		return
	player.update_movement(delta, false)

	# chạm sàn thì reset
	if player.is_on_floor():
		return_to_locomotion()
