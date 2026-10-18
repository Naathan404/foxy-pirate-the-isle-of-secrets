class_name PlayerState
extends FsmState

var player: Player:
	get:
		return obj as Player


# Gửi yêu cầu đổi state đến Fsm
func request_state(state_name: String, priority: int = 0) -> bool:
	return change_state(fsm.states.get(state_name) as FsmState, priority)


# refresh trạng thái
func return_to_locomotion() -> void:
	if player.dead:
		return
	if not player.is_on_floor():
		request_state("fall", 20)
	else:
		var s
		if player.move_direction.is_zero_approx():
			s = "idle"
		else:
			s = "run"
		request_state(s)


# xử lý chuyển animation theo thứ tự
func try_action_transition() -> bool:
	if player.dead:
		return true

	if not player.is_on_floor():
		return request_state("fall", 20)

	if player.dash_buffer_remaining > 0.0:
		if is_instance_valid(player.stamina) and player.stamina.has_method("try_consume"):
			return request_state("dash", 10)

		player.dash_buffer_remaining = 0.0
		player.action_rejected.emit(&"dash")

	if player.attack_requested:
		if is_instance_valid(player.attack_controller):
			return request_state("attack", 10)
		player.action_rejected.emit(&"normal_attack")
	return false
