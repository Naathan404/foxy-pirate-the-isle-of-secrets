class_name CharmActivationContext
extends RefCounted
## Dữ liệu đầu vào cho một lần kích hoạt Active Charm.

var actor: Node3D
var socket_id: int = CharmConstants.SocketId.UNASSIGNED
var direction: Vector3 = Vector3.ZERO
var target_position: Vector3 = Vector3.ZERO
var has_target: bool = false


func is_valid() -> bool:
	return is_instance_valid(actor) and socket_id != CharmConstants.SocketId.UNASSIGNED
