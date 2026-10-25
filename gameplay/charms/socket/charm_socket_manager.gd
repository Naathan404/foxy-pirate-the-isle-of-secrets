class_name CharmSocketManager
extends Node
## Quản lý ba socket cố định và quyền đổi Charm tại safe location.

signal socket_unlocked(socket_id: int, unlocked_socket_count: int)
signal safe_location_changed(is_safe: bool)
signal loadout_changed(socket_id: int, charm_id: StringName)
signal loadout_change_rejected(reason: StringName)
signal charm_activation_rejected(socket_id: int, reason: StringName)

const MANUAL_SAFE_LOCATION_SOURCE_ID := 0
const DEBUG_SOCKET_LABELS := ["Q", "Space", "E"]
const DEBUG_CHARM_NONE := "<Unequip>"

@export var registry: CharmRegistry
@export var actor: Node3D
@export var loadout: CharmLoadout

var _safe_location: bool = false
var _safe_location_sources: Dictionary[int, bool] = {}
var _sockets: Dictionary[int, CharmSocket] = {}
var _debug_socket_id: int = CharmConstants.SocketId.Q
var _debug_charm_id: StringName = &""


func _ready() -> void:
	if not is_instance_valid(actor):
		actor = get_parent() as Node3D
	if loadout == null:
		loadout = CharmLoadout.new()
	loadout.normalize()
	_setup_sockets()
	_apply_loadout()
	_connect_actor_events()
	notify_property_list_changed()
	if not _debug_charm_id.is_empty():
		_apply_debug_charm_selection.call_deferred()


func _get_property_list() -> Array[Dictionary]:
	if not OS.is_debug_build():
		return []
	return [
		{
			"name": "Runtime Charm Debug (Debug Builds Only)",
			"type": TYPE_NIL,
			"usage": PROPERTY_USAGE_CATEGORY,
		},
		{
			"name": "debug_socket",
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Q:0,E:2,Space:1",
			"usage": PROPERTY_USAGE_EDITOR,
		},
		{
			"name": "debug_charm",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": ",".join(_get_debug_charm_options()),
			"usage": PROPERTY_USAGE_EDITOR,
		},
	]


func _get(property: StringName) -> Variant:
	match property:
		&"debug_socket":
			return _debug_socket_id
		&"debug_charm":
			return _get_debug_charm_label(_debug_charm_id)
	return null


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"debug_socket":
			_debug_socket_id = clampi(
				int(value), CharmConstants.SocketId.Q, CharmConstants.SocketId.E
			)
			if is_node_ready() and not _debug_charm_id.is_empty():
				_apply_debug_charm_selection.call_deferred()
			return true
		&"debug_charm":
			_debug_charm_id = _get_debug_charm_id(String(value))
			if is_node_ready():
				_apply_debug_charm_selection.call_deferred()
			return true
	return false


func _physics_process(_delta: float) -> void:
	_handle_slot_input()


func _setup_sockets() -> void:
	_sockets.clear()
	var socket_definitions := {
		CharmConstants.SocketId.Q: &"charm_slot_q",
		CharmConstants.SocketId.SPACE: &"charm_slot_space",
		CharmConstants.SocketId.E: &"charm_slot_e",
	}
	for socket_id: int in socket_definitions:
		var socket := CharmSocket.new()
		socket.setup(socket_id, socket_definitions[socket_id])
		socket.unlocked = CharmConstants.is_socket_unlocked(
			socket_id, loadout.unlocked_socket_count
		)
		_sockets[socket_id] = socket


func _apply_loadout() -> void:
	if not is_instance_valid(registry) or not is_instance_valid(actor):
		return
	var equipped_ids: Dictionary[StringName, bool] = {}
	for socket_id: int in _sockets:
		var charm_id := loadout.get_equipped_charm(socket_id)
		if charm_id.is_empty() or not _sockets[socket_id].unlocked:
			continue
		if not registry.is_owned(charm_id) or equipped_ids.has(charm_id):
			loadout.set_equipped_charm(socket_id, &"")
			continue
		if not registry.equip_charm(charm_id, socket_id, actor):
			loadout.set_equipped_charm(socket_id, &"")
			continue
		var socket := _sockets[socket_id] as CharmSocket
		socket.charm_id = charm_id
		equipped_ids[charm_id] = true


func set_safe_location(is_safe: bool) -> void:
	if is_safe:
		_safe_location_sources[MANUAL_SAFE_LOCATION_SOURCE_ID] = true
	else:
		_safe_location_sources.erase(MANUAL_SAFE_LOCATION_SOURCE_ID)
	_refresh_safe_location()


func enter_safe_location(source: Node) -> void:
	if not is_instance_valid(source):
		return
	var source_id := source.get_instance_id()
	_safe_location_sources[source_id] = true
	if not source.tree_exiting.is_connected(_on_safe_location_source_exiting.bind(source_id)):
		source.tree_exiting.connect(
			_on_safe_location_source_exiting.bind(source_id), CONNECT_ONE_SHOT
		)
	_refresh_safe_location()


func exit_safe_location(source: Node) -> void:
	if not is_instance_valid(source):
		return
	_safe_location_sources.erase(source.get_instance_id())
	_refresh_safe_location()


func can_change_loadout() -> bool:
	return _safe_location


func get_unlocked_socket_count() -> int:
	return loadout.unlocked_socket_count if loadout != null else 0


func is_socket_unlocked(socket_id: int) -> bool:
	var socket := _sockets.get(socket_id) as CharmSocket
	return socket != null and socket.unlocked


func can_unlock_next_socket() -> bool:
	return (
		can_change_loadout()
		and loadout != null
		and loadout.unlocked_socket_count < CharmConstants.MAX_SOCKET_COUNT
	)


func unlock_next_socket() -> bool:
	if not can_change_loadout():
		loadout_change_rejected.emit(&"unsafe_location")
		return false
	if loadout.unlocked_socket_count >= CharmConstants.MAX_SOCKET_COUNT:
		loadout_change_rejected.emit(&"max_socket_count")
		return false
	loadout.unlocked_socket_count += 1
	var socket_id: int = CharmConstants.SOCKET_UNLOCK_ORDER[loadout.unlocked_socket_count - 1]
	var socket := _sockets.get(socket_id) as CharmSocket
	if socket == null:
		loadout.unlocked_socket_count -= 1
		return false
	socket.unlocked = true
	socket_unlocked.emit(socket_id, loadout.unlocked_socket_count)
	return true


func restore_progression(
	unlocked_socket_count: int, equipped_charm_ids: Dictionary[int, StringName]
) -> bool:
	if not is_instance_valid(registry) or not is_instance_valid(actor):
		return false
	for socket_id: int in range(CharmConstants.MAX_SOCKET_COUNT):
		registry.unequip_socket(socket_id)
	loadout.unlocked_socket_count = clampi(
		unlocked_socket_count, CharmConstants.STARTING_SOCKET_COUNT, CharmConstants.MAX_SOCKET_COUNT
	)
	loadout.equipped_charm_ids = equipped_charm_ids.duplicate()
	loadout.normalize()
	_setup_sockets()
	_apply_loadout()
	return true


func equip_charm(charm_id: StringName, socket_id: int) -> bool:
	if not can_change_loadout():
		loadout_change_rejected.emit(&"unsafe_location")
		return false
	if not is_socket_unlocked(socket_id):
		loadout_change_rejected.emit(&"socket_locked")
		return false
	if not is_instance_valid(registry) or not registry.is_owned(charm_id):
		loadout_change_rejected.emit(&"charm_not_owned")
		return false
	if _is_equipped_elsewhere(charm_id, socket_id):
		loadout_change_rejected.emit(&"duplicate_charm")
		return false
	var socket := _sockets[socket_id] as CharmSocket
	if socket.has_charm():
		loadout_change_rejected.emit(&"socket_occupied")
		return false
	if not registry.equip_charm(charm_id, socket_id, actor):
		loadout_change_rejected.emit(&"registry_rejected")
		return false
	socket.charm_id = charm_id
	loadout.set_equipped_charm(socket_id, charm_id)
	loadout_changed.emit(socket_id, charm_id)
	return true


func unequip_charm(socket_id: int) -> bool:
	if not can_change_loadout():
		loadout_change_rejected.emit(&"unsafe_location")
		return false
	var socket := _sockets.get(socket_id) as CharmSocket
	if socket == null or not socket.has_charm():
		return false
	if not is_instance_valid(registry) or not registry.unequip_socket(socket_id):
		loadout_change_rejected.emit(&"registry_rejected")
		return false
	socket.clear_charm()
	loadout.set_equipped_charm(socket_id, &"")
	loadout_changed.emit(socket_id, &"")
	return true


func get_equipped_charm(socket_id: int) -> StringName:
	var socket := _sockets.get(socket_id) as CharmSocket
	return socket.charm_id if socket != null else &""


func _debug_equip_charm(charm_id: StringName, socket_id: int) -> bool:
	if not OS.is_debug_build():
		return false
	var definition := registry.get_definition(charm_id) if is_instance_valid(registry) else null
	if not is_instance_valid(registry) or not is_instance_valid(actor) or definition == null:
		push_warning("Charm debug: selected Charm is not registered on this Player")
		return false
	if socket_id < CharmConstants.SocketId.Q or socket_id > CharmConstants.SocketId.E:
		push_warning("Charm debug: invalid socket")
		return false
	var added_debug_safe_source := not can_change_loadout()
	if added_debug_safe_source:
		enter_safe_location(self)
	while not is_socket_unlocked(socket_id):
		if not unlock_next_socket():
			_end_debug_loadout_change(added_debug_safe_source)
			return false
	for other_socket_id: int in range(CharmConstants.MAX_SOCKET_COUNT):
		if other_socket_id != socket_id and get_equipped_charm(other_socket_id) == charm_id:
			unequip_charm(other_socket_id)
	var current_charm_id := get_equipped_charm(socket_id)
	if current_charm_id == charm_id:
		_end_debug_loadout_change(added_debug_safe_source)
		return true
	if not current_charm_id.is_empty():
		unequip_charm(socket_id)
	var equipped := registry._debug_equip_charm(charm_id, socket_id, actor)
	if equipped:
		var socket := _sockets[socket_id] as CharmSocket
		socket.charm_id = charm_id
		loadout.set_equipped_charm(socket_id, charm_id)
		loadout_changed.emit(socket_id, charm_id)
		print(
			(
				"Charm debug: equipped %s in %s"
				% [definition.display_name, DEBUG_SOCKET_LABELS[socket_id]]
			)
		)
	_end_debug_loadout_change(added_debug_safe_source)
	return equipped


func _debug_unequip_charm(socket_id: int) -> bool:
	if not OS.is_debug_build():
		return false
	if socket_id < CharmConstants.SocketId.Q or socket_id > CharmConstants.SocketId.E:
		return false
	var added_debug_safe_source := not can_change_loadout()
	if added_debug_safe_source:
		enter_safe_location(self)
	var had_charm := not get_equipped_charm(socket_id).is_empty()
	var unequipped := unequip_charm(socket_id) if had_charm else true
	_end_debug_loadout_change(added_debug_safe_source)
	if unequipped and had_charm:
		print("Charm debug: unequipped %s" % DEBUG_SOCKET_LABELS[socket_id])
	return unequipped


func activate_socket(socket_id: int) -> bool:
	var socket := _sockets.get(socket_id) as CharmSocket
	if socket == null or not socket.unlocked or not socket.has_charm():
		charm_activation_rejected.emit(socket_id, &"socket_unavailable")
		return false
	if is_instance_valid(actor) and bool(actor.get("dead")):
		charm_activation_rejected.emit(socket_id, &"actor_unavailable")
		return false
	if not is_instance_valid(actor) or not actor.has_method("build_attack_context"):
		charm_activation_rejected.emit(socket_id, &"actor_context_unavailable")
		return false
	var attack_context := actor.call("build_attack_context") as AttackContext
	if attack_context == null:
		charm_activation_rejected.emit(socket_id, &"attack_context_unavailable")
		return false
	var context := CharmActivationContext.new()
	context.actor = actor
	context.socket_id = socket_id
	context.direction = attack_context.direction
	context.target_position = attack_context.target_position
	context.has_target = attack_context.has_target
	if not is_instance_valid(registry):
		charm_activation_rejected.emit(socket_id, &"registry_unavailable")
		return false
	if not registry.activate_socket(socket_id, context):
		charm_activation_rejected.emit(socket_id, &"registry_rejected")
		return false
	return true


func modify_outgoing_damage(amount_hp: int, damage: DamageContext) -> int:
	if not is_instance_valid(registry):
		return amount_hp
	return registry.modify_outgoing_damage(amount_hp, damage)


func modify_attack_damage(amount_hp: int, attack: AttackContext) -> int:
	if not is_instance_valid(registry):
		return amount_hp
	return registry.modify_attack_damage(amount_hp, attack)


func modify_incoming_damage(amount_hp: int, damage: DamageContext) -> int:
	if not is_instance_valid(registry):
		return amount_hp
	return registry.modify_incoming_damage(amount_hp, damage)


func modify_stats(stats: Dictionary[StringName, float]) -> void:
	if is_instance_valid(registry):
		registry.modify_stats(stats)


func dispatch_event(event_name: StringName, payload: Array) -> void:
	if is_instance_valid(registry):
		registry.dispatch_event(event_name, payload)


func reset_active_cooldowns() -> void:
	if is_instance_valid(registry):
		registry.reset_active_cooldowns()


func _handle_slot_input() -> void:
	for socket_id: int in _sockets:
		var socket := _sockets[socket_id] as CharmSocket
		if socket != null and Input.is_action_just_pressed(socket.input_action):
			activate_socket(socket_id)


func _apply_debug_charm_selection() -> void:
	if not OS.is_debug_build() or not is_node_ready():
		return
	if _debug_charm_id.is_empty():
		_debug_unequip_charm(_debug_socket_id)
	else:
		_debug_equip_charm(_debug_charm_id, _debug_socket_id)


func _get_debug_charm_options() -> PackedStringArray:
	var options := PackedStringArray([DEBUG_CHARM_NONE])
	for charm_id: StringName in _get_debug_charm_ids():
		options.append(_get_debug_charm_label(charm_id))
	return options


func _get_debug_charm_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	if not is_instance_valid(registry):
		return result
	result = registry.get_registered_ids()
	if result.is_empty():
		for definition: CharmData in registry.definitions:
			if definition != null and not definition.charm_id.is_empty():
				result.append(definition.charm_id)
	result.sort()
	return result


func _get_debug_charm_label(charm_id: StringName) -> String:
	if charm_id.is_empty():
		return DEBUG_CHARM_NONE
	var definition := registry.get_definition(charm_id) if is_instance_valid(registry) else null
	return definition.display_name if definition != null else String(charm_id)


func _get_debug_charm_id(label: String) -> StringName:
	if label == DEBUG_CHARM_NONE:
		return &""
	for charm_id: StringName in _get_debug_charm_ids():
		if label == _get_debug_charm_label(charm_id) or label == String(charm_id):
			return charm_id
	push_warning("Charm debug: unknown selection '%s'" % label)
	return &""


func _end_debug_loadout_change(added_debug_safe_source: bool) -> void:
	if added_debug_safe_source:
		exit_safe_location(self)


func _connect_actor_events() -> void:
	if not is_instance_valid(actor):
		return
	if actor.has_signal("dash_started") and not actor.dash_started.is_connected(_on_dash_started):
		actor.dash_started.connect(_on_dash_started)
	if (
		actor.has_signal("dash_finished")
		and not actor.dash_finished.is_connected(_on_dash_finished)
	):
		actor.dash_finished.connect(_on_dash_finished)


func _on_dash_started() -> void:
	dispatch_event(&"dash_started", [])


func _on_dash_finished(interrupted: bool) -> void:
	dispatch_event(&"dash_finished", [interrupted])


func _is_equipped_elsewhere(charm_id: StringName, requested_socket_id: int) -> bool:
	for socket_id: int in _sockets:
		var socket := _sockets[socket_id] as CharmSocket
		if socket_id != requested_socket_id and socket != null and socket.charm_id == charm_id:
			return true
	return false


func _refresh_safe_location() -> void:
	var next_value := not _safe_location_sources.is_empty()
	if _safe_location == next_value:
		return
	_safe_location = next_value
	safe_location_changed.emit(_safe_location)


func _on_safe_location_source_exiting(source_id: int) -> void:
	_safe_location_sources.erase(source_id)
	_refresh_safe_location()
