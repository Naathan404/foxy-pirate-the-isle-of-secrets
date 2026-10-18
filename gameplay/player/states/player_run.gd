extends PlayerState


func _enter() -> void:
	player.update_facing()
	player.play_directional_animation("run")


func _update(delta: float) -> void:
	if player.dead:
		return
	# ưu tiên xử lý dash, atk trước rồi mới idle
	if try_action_transition():
		return
	if player.move_direction.is_zero_approx():
		player.update_movement(delta, false)
		request_state("idle")
		return

	player.update_facing()
	player.update_movement(delta, true)
	player.play_directional_animation("run")
