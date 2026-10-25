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
const MIN_PROC_CHANCE := 0.0
const MAX_PROC_CHANCE := 1.0
