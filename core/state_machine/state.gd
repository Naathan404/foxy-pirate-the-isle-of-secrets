class_name FsmState
extends Node

# khi vào trạng thái có is_terminal true thì không thể chuyển sang trạng thái khác
@export var is_terminal: bool = false

var fsm: Fsm = null
var timer: float = 0.0
# nhan vat so huu state nay
var obj: Node = null


# Chay 1 lấn duy nhất khi vừa vào trạng thái
func _enter() -> void:
	pass

# Gọi trước khi thoát trạng thái
func _exit() -> void:
	pass

# Chạy liên tục mỗi lần update vật lý
func _update(_delta: float) -> void:
	pass

# 
func update_timer(delta: float) -> bool:
	if timer <= 0:
		return false
	timer = maxf(0.0, timer - maxf(delta, 0.0))
	if timer <= 0:
		return true
	return false

func change_state(new_state: FsmState, priority: int = 0) -> bool:
	if not is_instance_valid(fsm):
		push_error("FsmState: State chưa được gán cho một Fsm hợp lệ")
		return false
	return fsm.change_state(new_state, priority)
