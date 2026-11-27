class_name InventoryUI
extends CanvasLayer
## Pause menu with the Inventory, Weapon, Charms and Journey tabs.
##
## Owns the open/close lifecycle, the GameManager pause gate and the mouse mode. Each tab binds
## to the live data owners (Inventory, PotionComponent, WeaponController, CharmSocketManager,
## NoteProgress) and never duplicates their state.

enum Tab { INVENTORY, WEAPONS, CHARMS, JOURNEY }

## Built-in UI actions (PageUp / PageDown) so no gameplay binding is reused while paused.
const PREVIOUS_TAB_ACTION := &"ui_page_up"
const NEXT_TAB_ACTION := &"ui_page_down"
const CANCEL_ACTION := &"ui_cancel"
const INK_PROGRESS_PARAM := &"progress"
const INK_HIDDEN := 0.0
const INK_SHOWN := 1.0
const CENTER_RATIO := 0.5

@export var inventory: Inventory
@export var toggle_action: StringName = &"inventory"
@export var potion_component: PotionComponent

@export_group("Interaction Feedback")
@export_range(0.05, 0.6, 0.01, "suffix:s") var open_duration: float = 0.3
@export_range(0.05, 0.5, 0.01, "suffix:s") var close_duration: float = 0.16
@export_range(0.5, 1.0, 0.01) var closed_frame_scale: float = 0.94
## The background ink spreads from the center before the frame springs in.
@export_range(0.1, 1.5, 0.01, "suffix:s") var ink_open_seconds: float = 0.5
@export_range(0.05, 1.0, 0.01, "suffix:s") var ink_close_seconds: float = 0.26
@export_range(0.0, 0.4, 0.01, "suffix:s") var frame_open_delay: float = 0.16
@export_range(0.0, 120.0, 1.0, "suffix:px") var page_slide_pixels: float = 40.0
@export_range(1.0, 1.3, 0.01) var back_button_lift: float = 1.08
@export_range(0.05, 0.6, 0.01, "suffix:s") var page_switch_seconds: float = 0.24

var _is_open: bool = false
var _is_closing: bool = false
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _transition_tween: Tween
var _page_tween: Tween
var _current_tab: Tab = Tab.INVENTORY

@onready var _background: TextureRect = %Background
@onready var _frame: Control = %Frame
@onready var _embers: CPUParticles2D = %Embers
@onready var _back_button: Button = %BackButton
@onready var _items_tab: InventoryItemsTab = %ItemsTab
@onready var _weapons_tab: InventoryWeaponsTab = %WeaponsTab
@onready var _charms_tab: InventoryCharmsTab = %CharmsTab
@onready var _tab_buttons: Dictionary[Tab, InventoryMenuTabButton] = {
	Tab.INVENTORY: %InventoryTabButton,
	Tab.WEAPONS: %WeaponsTabButton,
	Tab.CHARMS: %CharmsTabButton,
	Tab.JOURNEY: %JourneyTabButton,
}
@onready var _pages: Dictionary[Tab, Control] = {
	Tab.INVENTORY: %ItemsTab,
	Tab.WEAPONS: %WeaponsTab,
	Tab.CHARMS: %CharmsTab,
	Tab.JOURNEY: %JourneyTab,
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	for tab: Tab in _tab_buttons:
		_tab_buttons[tab].pressed.connect(select_tab.bind(tab))
	_back_button.pressed.connect(close_inventory)
	_back_button.tooltip_text = "Close (%s)" % InventoryMenuFormat.action_key(CANCEL_ACTION)
	InventoryHoverFeedback.attach(_back_button, null, back_button_lift)
	_frame.resized.connect(_update_frame_pivot)
	_update_frame_pivot()
	_show_page(_current_tab, false)
	if inventory == null:
		push_error("InventoryUI: inventory is not assigned")
	# Player exports are resolved once the whole player scene is ready.
	_bind_components.call_deferred()


func _input(event: InputEvent) -> void:
	# Runs before GUI so Tab toggles the menu instead of moving focus.
	if event.is_action_pressed(toggle_action):
		var was_open := _is_open
		toggle_inventory()
		# When another menu holds the screen (the shop) the bag stays shut: leave Tab to it.
		if was_open or _is_open:
			get_viewport().set_input_as_handled()
		return
	if not _is_open or _is_closing:
		return
	if event.is_action_pressed(CANCEL_ACTION):
		close_inventory()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(PREVIOUS_TAB_ACTION):
		select_tab(wrapi(_current_tab - 1, 0, Tab.size()) as Tab)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(NEXT_TAB_ACTION):
		select_tab(wrapi(_current_tab + 1, 0, Tab.size()) as Tab)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _is_open:
		_items_tab.cancel_drag()


func _exit_tree() -> void:
	if _is_open:
		Input.mouse_mode = _previous_mouse_mode
		get_node("/root/GameManager").exit_inventory()


## Refreshes the visible page from its data owner.
func refresh() -> void:
	var page := _pages[_current_tab]
	if page.has_method("refresh"):
		page.call("refresh")


func select_tab(tab: Tab) -> void:
	if not _pages.has(tab):
		return
	var previous := _current_tab
	_current_tab = tab
	var animate := _is_open and not _is_closing
	_show_page(tab, animate)
	if tab != previous and _is_open:
		if animate:
			_slide_page_in(tab, signi(tab - previous))
			InventoryMenuFx.burst(_tab_buttons[tab])
		_focus_page()


func open_inventory() -> void:
	if (_is_open and not _is_closing) or not is_instance_valid(inventory):
		return
	var player := get_parent() as Player
	if player != null and player.dead:
		return
	var fresh_open: bool = not _is_open
	if fresh_open:
		if not get_node("/root/GameManager").enter_inventory():
			return
		_previous_mouse_mode = Input.mouse_mode
	_kill_transition()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_is_open = true
	_is_closing = false
	show()
	_show_page(_current_tab, false)
	refresh()
	_embers.emitting = true
	if fresh_open:
		_set_ink_progress(INK_HIDDEN)
		_frame.modulate.a = 0.0
		_frame.scale = Vector2.ONE * closed_frame_scale
		_embers.restart()
		_focus_page()
		_play_intro()
	_transition_tween = create_tween().set_parallel()
	var ink := _transition_tween.tween_method(
		_set_ink_progress, _ink_progress(), INK_SHOWN, ink_open_seconds
	)
	ink.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var fade := _transition_tween.tween_property(_frame, "modulate:a", 1.0, open_duration)
	fade.set_delay(frame_open_delay)
	var grow := _transition_tween.tween_property(_frame, "scale", Vector2.ONE, open_duration)
	grow.set_delay(frame_open_delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close_inventory(immediate: bool = false) -> void:
	if not _is_open:
		return
	if _is_closing and not immediate:
		return
	_items_tab.cancel_drag()
	_kill_transition()
	if immediate:
		_finish_close()
		return
	_is_closing = true
	_embers.emitting = false
	_transition_tween = create_tween().set_parallel()
	_transition_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_transition_tween.tween_property(_frame, "modulate:a", 0.0, close_duration)
	_transition_tween.tween_property(
		_frame, "scale", Vector2.ONE * closed_frame_scale, close_duration
	)
	_transition_tween.tween_method(
		_set_ink_progress, _ink_progress(), INK_HIDDEN, ink_close_seconds
	)
	_transition_tween.chain().tween_callback(_finish_close)


func toggle_inventory() -> void:
	if _is_closing or not _is_open:
		open_inventory()
	else:
		close_inventory()


func is_open() -> bool:
	return _is_open


func _bind_components() -> void:
	var player := get_parent() as Player
	var weapons: WeaponController = player.weapon_controller if player != null else null
	var charms: CharmSocketManager = player.charm_socket_manager if player != null else null
	_items_tab.setup(inventory, potion_component, weapons)
	_weapons_tab.setup(weapons)
	_charms_tab.setup(charms)


func _show_page(tab: Tab, animate: bool) -> void:
	if tab != Tab.INVENTORY:
		_items_tab.cancel_drag()
	for page_tab: Tab in _pages:
		_pages[page_tab].visible = page_tab == tab
		_tab_buttons[page_tab].set_active(page_tab == tab, animate)


## Tabs drop in one by one and the current page plays its own entrance.
func _play_intro() -> void:
	InventoryMenuFx.stagger_in(_tab_buttons.values())
	_play_page_intro(_pages[_current_tab])


func _play_page_intro(page: Control) -> void:
	if page.has_method("play_intro"):
		page.call("play_intro")


## Slides the new page in from the side of the tab it came from.
func _slide_page_in(tab: Tab, direction: int) -> void:
	_reset_pages()
	var page := _pages[tab]
	page.position.x = page_slide_pixels * direction
	page.modulate.a = 0.0
	_page_tween = create_tween().set_parallel()
	_page_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_page_tween.tween_property(page, "position:x", 0.0, page_switch_seconds)
	_page_tween.tween_property(page, "modulate:a", 1.0, page_switch_seconds)
	_play_page_intro(page)


func _reset_pages() -> void:
	if _page_tween != null and _page_tween.is_valid():
		_page_tween.kill()
	for page: Control in _pages.values():
		page.position = Vector2.ZERO
		page.modulate.a = 1.0


func _focus_page() -> void:
	var page := _pages[_current_tab]
	if page.has_method("focus_default"):
		page.call("focus_default")


func _update_frame_pivot() -> void:
	_frame.pivot_offset = _frame.size * CENTER_RATIO


func _set_ink_progress(progress: float) -> void:
	(_background.material as ShaderMaterial).set_shader_parameter(INK_PROGRESS_PARAM, progress)


func _ink_progress() -> float:
	var material := _background.material as ShaderMaterial
	return float(material.get_shader_parameter(INK_PROGRESS_PARAM))


func _kill_transition() -> void:
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition_tween = null


func _finish_close() -> void:
	_is_open = false
	_is_closing = false
	hide()
	_embers.emitting = false
	_reset_pages()
	_frame.modulate.a = 1.0
	_frame.scale = Vector2.ONE
	_set_ink_progress(INK_SHOWN)
	Input.mouse_mode = _previous_mouse_mode
	get_node("/root/GameManager").exit_inventory()
