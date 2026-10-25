class_name CharmRuntime
extends RefCounted
## Trạng thái runtime của một Charm đang sở hữu hoặc được gắn.

signal cooldown_changed(remaining_seconds: float)

var definition: CharmData
var socket_id: int = CharmConstants.SocketId.UNASSIGNED
var effect: CharmEffect
var cooldown_remaining: float = 0.0
var equipped: bool = false


func setup(charm_definition: CharmData, assigned_socket_id: int) -> bool:
	if charm_definition == null or charm_definition.validate().size() > 0:
		return false
	definition = charm_definition
	socket_id = assigned_socket_id
	cooldown_remaining = 0.0
	equipped = false
	return true


func advance(delta: float) -> void:
	if delta <= 0.0 or cooldown_remaining <= 0.0:
		return
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	cooldown_changed.emit(cooldown_remaining)


func can_activate() -> bool:
	return (
		equipped
		and definition != null
		and definition.is_active()
		and cooldown_remaining <= 0.0
		and is_instance_valid(effect)
	)


func start_cooldown() -> void:
	if definition == null:
		return
	cooldown_remaining = maxf(0.0, definition.cooldown_seconds)
	cooldown_changed.emit(cooldown_remaining)


func reset_cooldown() -> void:
	cooldown_remaining = 0.0
	cooldown_changed.emit(cooldown_remaining)
