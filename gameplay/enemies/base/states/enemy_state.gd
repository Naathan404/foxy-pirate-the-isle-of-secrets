class_name EnemyState
extends FsmState

var enemy: EnemyBase:
	get:
		return obj as EnemyBase


func request_state(state_name: StringName, priority: int = 0) -> bool:
	if not is_instance_valid(fsm):
		return false
	return change_state(fsm.states.get(String(state_name).to_lower()) as FsmState, priority)


func return_to_behavior() -> void:
	if enemy.dead:
		return
	change_state(fsm.default_state)
