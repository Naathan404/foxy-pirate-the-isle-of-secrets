class_name Fsm
extends Node

signal state_changed(old_state: FsmState, new_state: FsmState)

var debug: bool = false
# Trả trạng thái bằng tên thường như idle, attack
var states: Dictionary = {}
var current_state: FsmState = null
var previous_state: FsmState = null
# Trạng thái được yêu cầu cần chuyển sang
var next_state: FsmState = null
var default_state: FsmState = null
var obj: Node = null

# Chống config nhieuf lần
var _configured: bool = false

# Chặn gọi update lồng nhau từ nhiều trạng thái
var _updating: bool = false
# Giữ yêu cầu trạng thái quan trọng, không bị trạng thái khác ghi đè không đúng
var _pending_priority: int = 0
var _terminal_locked: bool = false


# Khởi tạo
func _init(target_obj: Node = null, state_parent_node: Node = null, initial_state: FsmState = null, debug_mode: bool = false) -> void:
	if target_obj != null or state_parent_node != null or initial_state != null:
		setup(target_obj, state_parent_node, initial_state, debug_mode)


# Setup fsm
func setup(target_obj: Node = null, state_parent_node: Node = null, initial_state: FsmState = null, debug_mode: bool = false) -> bool:
	if _configured:
		push_error("Fsm: setup() chỉ được gọi 1 lần")
		return false
	if not is_instance_valid(target_obj) or not is_instance_valid(state_parent_node):
		push_error("Fsm: Node invalid")
		return false
	if not is_instance_valid(initial_state):
		push_error("Fsm State khởi tạo không hợp lệ")
		return false

	var registered: Dictionary = {}
	for child in state_parent_node.get_children():
		if not child is FsmState:
			continue
		var state = child as FsmState
		var key = state.name.to_lower()

		# kiểm tra key trong registered
		if registered.has(key):
			push_error("Fsm: duplicate tên state: " + key)
			return false
		if is_instance_valid(state.fsm) and state.fsm != self:
			push_error("Fsm: state không thuộc Fsm này: " + key)
			return false

		registered[key] = state
	
	if registered.get(initial_state.name.to_lower()) != initial_state:
		push_error("Fsm: initial state phải là node con trực tiếp của node States cha")
		return false

	# gán 
	obj = target_obj
	debug = debug_mode
	states = registered
	for state: FsmState in states.values():
		state.fsm = self
		state.obj = obj
	default_state = initial_state
	next_state = initial_state
	_configured = true
	return true

func change_state(new_state: FsmState, priority: int = 0) -> bool:
	if not _configured or not is_instance_valid(new_state):
		push_error("fsm: fsm chưa được setup")
		return false
	if states.get(new_state.name.to_lower()) != new_state:
		push_error("Fsm: state được yêu cầu không thuộc fsm này")
		return false
	if _terminal_locked:
		return false
	if is_instance_valid(next_state) and next_state.is_terminal and not new_state.is_terminal:
		return false
	if not new_state.is_terminal and priority < _pending_priority:
		return false

	next_state = new_state
	_pending_priority = priority
	return true

# được goi cùng với update physics
func _update(delta: float) -> void:
	if not _configured or _updating:
		return
	if not is_instance_valid(obj) or not is_instance_valid(next_state):
		push_error("Fsm: free actor hoặc state đang chờ")
		_configured = false
		return
	if current_state != null and not is_instance_valid(current_state):
		push_error("Fsm: free state hiện tại")
		_configured = false
		return

	_updating = true
	_pending_priority = 0

	if next_state != current_state:
		var target = next_state
		_terminal_locked = target.is_terminal

		if is_instance_valid(current_state):
			current_state._exit()
		if not is_instance_valid(target):
			push_error("Fsm: free state tiếp theo")
			_configured = false
			_updating = false
			return

		previous_state = current_state
		current_state = target
		current_state.timer = 0.0
		current_state._enter()

		if is_instance_valid(current_state):
			if debug and is_instance_valid(obj):
				print(obj.name, ": entered ", current_state.name)
			state_changed.emit(previous_state, current_state)

	if is_instance_valid(obj) and is_instance_valid(current_state):
		current_state._update(delta)
	_updating = false
