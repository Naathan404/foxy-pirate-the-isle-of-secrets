extends PlayerState

func _enter() -> void:
	player.play_directional_animation("idle")


func _update(delta: float) -> void:
	if player.dead:
		return
	player.update_movement(delta, false)
	# ưu tiên xử lý dash, atk trước rồi mới chạy
	if try_action_transition():
		return

	if not player.move_direction.is_zero_approx():
		player.update_facing()
		request_state("run")