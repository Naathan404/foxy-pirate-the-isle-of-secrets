class_name CharmSocket
extends RefCounted
## Trạng thái của một socket Charm cố định.

var socket_id: int = CharmConstants.SocketId.UNASSIGNED
var input_action: StringName = &""
var unlocked: bool = false
var charm_id: StringName = &""


func setup(assigned_socket_id: int, assigned_input_action: StringName) -> void:
	socket_id = assigned_socket_id
	input_action = assigned_input_action
	unlocked = false
	charm_id = &""


func has_charm() -> bool:
	return not charm_id.is_empty()


func clear_charm() -> void:
	charm_id = &""
