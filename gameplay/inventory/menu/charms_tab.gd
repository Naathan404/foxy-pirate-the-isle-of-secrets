class_name InventoryCharmsTab
extends Control
## Charms page: the three sockets, the charm catalog and the selected charm. Every equip/unequip
## goes through CharmSocketManager, which owns ownership, safe-location and socket rules.

enum Filter { ALL, ACTIVE, PASSIVE }

const SLOT_SCENE: PackedScene = preload("res://gameplay/inventory/menu/catalog_slot.tscn")
const EQUIPPED_BADGE: Texture2D = preload("res://assets/ui/HUD_Fox/Weapons/Deco_4.png")
const GRID_COLUMNS := 4
const MIN_VISIBLE_ROWS := 3
const PERCENT_SCALE := 100.0
const NO_VALUE := "—"
const LOCKED_NAME := "???"
const LOCKED_EFFECT := "Find this charm to learn what it does."
const SILHOUETTE_MATERIAL: ShaderMaterial = preload(
	"res://gameplay/inventory/menu/silhouette_material.tres"
)
const SP_PER_SECOND_PARAM := &"sp_per_second"
const SOCKET_ACTIONS := {
	CharmConstants.SocketId.Q: &"charm_slot_q",
	CharmConstants.SocketId.SPACE: &"charm_slot_space",
	CharmConstants.SocketId.E: &"charm_slot_e",
}
const REJECTION_TEXT := {
	&"unsafe_location": "Charms can only be changed at a safe location.",
	&"socket_locked": "That socket is still locked.",
	&"charm_not_owned": "You have not acquired this charm yet.",
	&"duplicate_charm": "This charm is already in another socket.",
	&"socket_occupied": "Unequip the charm in this socket first.",
	&"registry_rejected": "This charm could not be changed right now.",
}

var charms: CharmSocketManager

var _filter: Filter = Filter.ALL
var _entries: Array[CharmData] = []
var _selected_id: StringName = &""
var _target_socket: int = CharmConstants.SocketId.Q
var _slots: Array[InventoryCatalogSlot] = []
var _awaiting_result: bool = false
var _last_rejection: StringName = &""
var _dirty: bool = true

@onready var _grid: GridContainer = %Grid
@onready var _counter_label: Label = %CounterLabel
@onready var _empty_label: Label = %EmptyLabel
@onready var _safe_label: Label = %SafeLabel
@onready var _socket_count_label: Label = %SocketCountLabel
@onready var _big_icon: TextureRect = %BigIcon
@onready var _charm_name: Label = %CharmName
@onready var _type_banner: Label = %TypeBanner
@onready var _type_banner_art: TextureRect = %TypeBannerArt
@onready var _status_banner: Label = %StatusBanner
@onready var _cost_value: Label = %CostValue
@onready var _type_value: Label = %TypeValue
@onready var _socket_value: Label = %SocketValue
@onready var _cooldown_value: Label = %CooldownValue
@onready var _chance_value: Label = %ChanceValue
@onready var _owned_value: Label = %OwnedValue
@onready var _effect_scroll: ScrollContainer = %EffectScroll
@onready var _effect_text: Label = %EffectText
@onready var _action_hint: Label = %ActionHint
@onready var _action_button: Button = %ActionButton
@onready var _socket_buttons: Dictionary[int, InventoryCharmSocketButton] = {
	CharmConstants.SocketId.Q: %SocketQ,
	CharmConstants.SocketId.SPACE: %SocketSpace,
	CharmConstants.SocketId.E: %SocketE,
}
@onready var _filter_chips: Dictionary[Filter, InventoryFilterChip] = {
	Filter.ALL: %FilterAll,
	Filter.ACTIVE: %FilterActive,
	Filter.PASSIVE: %FilterPassive,
}


func _ready() -> void:
	for socket_id: int in _socket_buttons:
		_socket_buttons[socket_id].pressed.connect(_select_socket.bind(socket_id))
	for filter: Filter in _filter_chips:
		_filter_chips[filter].pressed.connect(_set_filter.bind(filter))
	_action_button.pressed.connect(_on_action_pressed)
	visibility_changed.connect(_on_visibility_changed)
	InventoryHoverFeedback.attach(_action_button)


func setup(manager: CharmSocketManager) -> void:
	if is_instance_valid(charms):
		return
	charms = manager
	if is_instance_valid(charms):
		charms.loadout_changed.connect(_on_loadout_changed)
		charms.socket_unlocked.connect(_on_socket_unlocked)
		charms.safe_location_changed.connect(_on_safe_location_changed)
		charms.loadout_change_rejected.connect(_on_loadout_change_rejected)
		if is_instance_valid(charms.registry):
			charms.registry.charm_owned.connect(_on_ownership_changed)
			charms.registry.charm_ownership_removed.connect(_on_ownership_changed)
			charms.registry.charm_registered.connect(_on_ownership_changed)
			charms.registry.charm_unregistered.connect(_on_ownership_changed)
		_target_socket = _default_target_socket()
	_request_refresh()


func refresh() -> void:
	_dirty = false
	_rebuild_entries()
	if not _has_entry(_selected_id):
		_selected_id = _entries[0].charm_id if not _entries.is_empty() else &""
	_refresh_grid()
	_refresh_sockets(false)
	_refresh_details()


## Entrance animation played by the menu when this page appears.
func play_intro() -> void:
	InventoryMenuFx.stagger_in(_slots)
	InventoryMenuFx.stagger_in(_socket_buttons.values())
	InventoryMenuFx.pop(_big_icon, InventoryMenuFx.ICON_POP_FROM_SCALE)


func focus_default() -> void:
	var index := _index_of(_selected_id)
	var target: Control = _slots[index] if index >= 0 else _socket_buttons[_target_socket]
	target.grab_focus.call_deferred()


func _request_refresh() -> void:
	if is_visible_in_tree():
		refresh()
	else:
		_dirty = true


func _on_visibility_changed() -> void:
	if is_visible_in_tree() and _dirty:
		refresh()


func _on_loadout_changed(_socket_id: int, _charm_id: StringName) -> void:
	_request_refresh()


func _on_socket_unlocked(_socket_id: int, _count: int) -> void:
	_request_refresh()


func _on_safe_location_changed(_safe: bool) -> void:
	_request_refresh()


func _on_ownership_changed(_charm_id: StringName) -> void:
	_request_refresh()


func _on_loadout_change_rejected(reason: StringName) -> void:
	if _awaiting_result:
		_last_rejection = reason


## Prototype and disabled charms stay hidden unless already owned (e.g. granted by debug tools),
## matching the registry rule that only playable charms can be acquired.
func _rebuild_entries() -> void:
	_entries.clear()
	if not is_instance_valid(charms) or not is_instance_valid(charms.registry):
		return
	var registry := charms.registry
	var visible_total: int = 0
	var owned_total: int = 0
	for charm_id: StringName in registry.get_registered_ids():
		var definition := registry.get_definition(charm_id)
		if definition == null:
			continue
		var owned := registry.is_owned(charm_id)
		if not definition.is_playable() and not owned:
			continue
		visible_total += 1
		owned_total += 1 if owned else 0
		if _matches(definition):
			_entries.append(definition)
	_counter_label.text = "%d/%d" % [owned_total, visible_total]


func _matches(definition: CharmData) -> bool:
	match _filter:
		Filter.ACTIVE:
			return definition.is_active()
		Filter.PASSIVE:
			return definition.is_passive()
	return true


func _set_filter(filter: Filter) -> void:
	var changed := filter != _filter
	_filter = filter
	for chip_filter: Filter in _filter_chips:
		_filter_chips[chip_filter].set_active(chip_filter == _filter)
	refresh()
	if changed:
		InventoryMenuFx.stagger_in(_slots)


func _refresh_grid() -> void:
	for chip_filter: Filter in _filter_chips:
		_filter_chips[chip_filter].set_active(chip_filter == _filter)
	var rows: int = maxi(MIN_VISIBLE_ROWS, ceili(float(_entries.size()) / GRID_COLUMNS))
	var cell_count: int = rows * GRID_COLUMNS
	while _slots.size() < cell_count:
		var slot := SLOT_SCENE.instantiate() as InventoryCatalogSlot
		_grid.add_child(slot)
		slot.pressed.connect(_select_index.bind(_slots.size()))
		_slots.append(slot)
	for index in range(_slots.size()):
		var slot := _slots[index]
		slot.visible = index < cell_count
		if index >= _entries.size():
			slot.present_placeholder()
			continue
		var definition := _entries[index]
		var owned := charms.registry.is_owned(definition.charm_id)
		var socket_id := _equipped_socket(definition.charm_id)
		slot.present(definition.sprite, true, not owned, EQUIPPED_BADGE if socket_id >= 0 else null)
		slot.set_selected(definition.charm_id == _selected_id)
		slot.tooltip_text = (
			definition.display_name + _state_suffix(owned, socket_id)
			if owned
			else "Undiscovered charm"
		)
	_empty_label.visible = _entries.is_empty()


func _refresh_sockets(animate: bool) -> void:
	var unlocked_count: int = 0
	for socket_id: int in _socket_buttons:
		var unlocked := is_instance_valid(charms) and charms.is_socket_unlocked(socket_id)
		var definition := _equipped_definition(socket_id)
		unlocked_count += 1 if unlocked else 0
		var key := InventoryMenuFormat.action_key(SOCKET_ACTIONS[socket_id])
		var button := _socket_buttons[socket_id]
		var icon := definition.sprite if definition != null else null
		button.present(key, icon, unlocked, socket_id == _target_socket, animate)
		button.tooltip_text = (
			"%s socket: %s" % [key, definition.display_name if definition != null else "empty"]
			if unlocked
			else "%s socket is locked. Sockets open in the order Q, E, Space." % key
		)
	var safe := is_instance_valid(charms) and charms.can_change_loadout()
	_safe_label.text = (
		"Safe location: charms can be changed here."
		if safe
		else "Not a safe location: rest at a checkpoint or the hub to change charms."
	)
	if not safe and is_instance_valid(charms) and charms.can_debug_change_loadout():
		_safe_label.text = "Debug: owned charms can be equipped here."
	_socket_count_label.text = (
		"Sockets open: %d/%d" % [unlocked_count, CharmConstants.MAX_SOCKET_COUNT]
	)


func _select_index(index: int) -> void:
	if index < _entries.size():
		var changed := _entries[index].charm_id != _selected_id
		_selected_id = _entries[index].charm_id
		_awaiting_result = false
		refresh()
		if changed:
			InventoryMenuFx.pop(_big_icon, InventoryMenuFx.ICON_POP_FROM_SCALE)


func _select_socket(socket_id: int) -> void:
	_target_socket = socket_id
	var definition := _equipped_definition(socket_id)
	if definition != null:
		if not _matches(definition):
			_set_filter(Filter.ALL)
		_selected_id = definition.charm_id
	refresh()
	_refresh_sockets(true)


func _refresh_details() -> void:
	_effect_scroll.scroll_vertical = 0
	var definition := _selected_definition()
	if definition == null:
		_big_icon.texture = null
		_big_icon.material = null
		_type_banner_art.visible = false
		_charm_name.text = "No charm selected"
		_charm_name.tooltip_text = ""
		_type_banner.text = ""
		_status_banner.text = ""
		for label: Label in [
			_cost_value, _type_value, _socket_value, _cooldown_value, _chance_value, _owned_value
		]:
			label.text = NO_VALUE
		_effect_text.text = "Charms you discover appear in the list."
		_action_button.text = "Equip"
		_action_button.disabled = true
		_action_hint.text = ""
		return

	var owned := charms.registry.is_owned(definition.charm_id)
	var socket_id := _equipped_socket(definition.charm_id)
	_big_icon.texture = definition.sprite
	_big_icon.material = null if owned else SILHOUETTE_MATERIAL
	if not owned:
		_show_locked_details()
		_refresh_action(owned, socket_id)
		return
	_charm_name.text = definition.display_name
	_charm_name.tooltip_text = definition.display_name
	_type_banner_art.visible = true
	_type_banner.text = "Active" if definition.is_active() else "Passive"
	_status_banner.text = _status_text(definition, owned)
	_cost_value.text = _cost_text(definition)
	_type_value.text = _type_banner.text
	_socket_value.text = _socket_name(socket_id) if socket_id >= 0 else "None"
	_cooldown_value.text = (
		InventoryMenuFormat.number(definition.cooldown_seconds) + "s"
		if definition.cooldown_seconds > 0.0
		else NO_VALUE
	)
	_chance_value.text = InventoryMenuFormat.number(definition.proc_chance * PERCENT_SCALE) + "%"
	_owned_value.text = "Owned" if owned else "Not owned"
	_effect_text.text = (
		definition.description.strip_edges()
		if not definition.description.strip_edges().is_empty()
		else "No effect description yet."
	)
	_refresh_action(owned, socket_id)


## Undiscovered charms reveal nothing but their silhouette.
func _show_locked_details() -> void:
	_charm_name.text = LOCKED_NAME
	_charm_name.tooltip_text = ""
	_type_banner.text = ""
	_type_banner_art.visible = false
	_status_banner.text = "Not owned"
	for label: Label in [
		_cost_value, _type_value, _socket_value, _cooldown_value, _chance_value, _owned_value
	]:
		label.text = NO_VALUE
	_effect_text.text = LOCKED_EFFECT


func _refresh_action(owned: bool, equipped_socket: int) -> void:
	var target_name := _socket_name(_target_socket)
	var in_target := equipped_socket == _target_socket
	var debug_loadout := charms.can_debug_change_loadout(_selected_id)
	_action_button.text = "Unequip" if in_target else "Equip to %s" % target_name
	var reason := ""
	if not owned:
		reason = "You have not acquired this charm yet."
	elif not charms.is_socket_unlocked(_target_socket) and not debug_loadout:
		reason = "The %s socket is locked." % target_name
	elif not in_target and equipped_socket >= 0:
		reason = "Already in %s. Unequip it there first." % _socket_name(equipped_socket)
	elif not in_target and not charms.get_equipped_charm(_target_socket).is_empty():
		var occupant := _equipped_definition(_target_socket)
		reason = (
			"%s holds %s. Unequip it first."
			% [target_name, occupant.display_name if occupant != null else "a charm"]
		)
	# Safe location is checked by the manager on press so the player sees its rejection.
	_action_button.disabled = not reason.is_empty()
	if not reason.is_empty():
		_action_hint.text = reason
	elif debug_loadout and not charms.is_socket_unlocked(_target_socket):
		_action_hint.text = "Equipping this charm will unlock %s in debug." % target_name
	elif debug_loadout and not charms.can_change_loadout():
		_action_hint.text = "Debug: equip or remove an owned charm on this map."
	elif not charms.can_change_loadout():
		_action_hint.text = "Not a safe location: changes will be refused."
	else:
		_action_hint.text = "Target: %s socket. Click a socket to change it." % target_name


func _on_action_pressed() -> void:
	var definition := _selected_definition()
	if definition == null or not is_instance_valid(charms):
		return
	var unequip := charms.get_equipped_charm(_target_socket) == definition.charm_id
	_awaiting_result = true
	_last_rejection = &""
	var changed: bool
	if charms.can_debug_change_loadout(definition.charm_id):
		changed = (
			charms.debug_unequip_charm(_target_socket)
			if unequip
			else charms.debug_equip_charm(definition.charm_id, _target_socket)
		)
	else:
		changed = (
			charms.unequip_charm(_target_socket)
			if unequip
			else charms.equip_charm(definition.charm_id, _target_socket)
		)
	_awaiting_result = false
	refresh()
	if changed:
		_action_hint.text = (
			("%s removed from %s." if unequip else "%s equipped to %s.")
			% [definition.display_name, _socket_name(_target_socket)]
		)
		_socket_buttons[_target_socket].play_change_feedback()
	else:
		_action_hint.text = REJECTION_TEXT.get(_last_rejection, "The charm loadout did not change.")
		InventoryMenuFx.shake(_action_button)


func _default_target_socket() -> int:
	for socket_id: int in CharmConstants.SOCKET_UNLOCK_ORDER:
		if charms.is_socket_unlocked(socket_id) and charms.get_equipped_charm(socket_id).is_empty():
			return socket_id
	return CharmConstants.SocketId.Q


func _selected_definition() -> CharmData:
	if _selected_id.is_empty() or not is_instance_valid(charms):
		return null
	if not is_instance_valid(charms.registry):
		return null
	return charms.registry.get_definition(_selected_id)


func _equipped_definition(socket_id: int) -> CharmData:
	if not is_instance_valid(charms) or not is_instance_valid(charms.registry):
		return null
	var charm_id := charms.get_equipped_charm(socket_id)
	return charms.registry.get_definition(charm_id) if not charm_id.is_empty() else null


func _equipped_socket(charm_id: StringName) -> int:
	if not is_instance_valid(charms):
		return -1
	for socket_id: int in SOCKET_ACTIONS:
		if charms.get_equipped_charm(socket_id) == charm_id:
			return socket_id
	return -1


func _has_entry(charm_id: StringName) -> bool:
	return _index_of(charm_id) >= 0


func _index_of(charm_id: StringName) -> int:
	for index in range(_entries.size()):
		if _entries[index].charm_id == charm_id:
			return index
	return -1


func _socket_name(socket_id: int) -> String:
	return InventoryMenuFormat.action_key(SOCKET_ACTIONS.get(socket_id, &""))


func _status_text(definition: CharmData, owned: bool) -> String:
	if definition.is_prototype():
		return "Prototype"
	return "Owned" if owned else "Not owned"


func _state_suffix(owned: bool, socket_id: int) -> String:
	if not owned:
		return " (not acquired)"
	if socket_id >= 0:
		return " (equipped: %s)" % _socket_name(socket_id)
	return ""


func _cost_text(definition: CharmData) -> String:
	if definition.effect_params.has(SP_PER_SECOND_PARAM):
		return InventoryMenuFormat.number(definition.get_param_float(SP_PER_SECOND_PARAM)) + " SP/s"
	if definition.resource_cost > 0.0:
		return InventoryMenuFormat.number(definition.resource_cost) + " SP"
	return NO_VALUE
