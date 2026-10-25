class_name CharmConstants
extends RefCounted
## Hằng số dùng chung cho domain Charm.

enum CharmType {
	ACTIVE,
	PASSIVE,
}

enum SocketId {
	Q,
	SPACE,
	E,
	UNASSIGNED = -1,
}

const MAX_SOCKET_COUNT := 3
const STARTING_SOCKET_COUNT := 1
const SOCKET_UNLOCK_ORDER := [SocketId.Q, SocketId.E, SocketId.SPACE]
const MIN_PROC_CHANCE := 0.0
const MAX_PROC_CHANCE := 1.0


# Thứ tự mở ô độc lập với ID của socket và thứ tự áp dụng hiệu ứng Charm.
static func is_socket_unlocked(socket_id: int, unlocked_count: int) -> bool:
	var index := SOCKET_UNLOCK_ORDER.find(socket_id)
	return index >= 0 and index < clampi(unlocked_count, 0, MAX_SOCKET_COUNT)
