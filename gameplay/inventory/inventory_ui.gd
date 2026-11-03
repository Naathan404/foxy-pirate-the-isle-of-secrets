class_name InventoryUI
extends CanvasLayer

const SLOT_SCENE: PackedScene = preload("res://gameplay/inventory/inventory_slot_ui.tscn")

# túi dữ liệu
@export var inventory: Inventory
@export var toggle_action: StringName = &"inventory"
@export var potion_component: PotionComponent

@export_group("Interaction Feedback")
@export_range(0.05, 0.5, 0.01) var open_duration: float = 0.18
@export_range(0.05, 0.5, 0.01) var close_duration: float = 0.12
@export var selected_tab_scale: Vector2 = Vector2(1.12, 1.05)
@export_range(0.05, 0.3, 0.01) var tab_feedback_duration: float = 0.12

@export_group("Button labels")
@export var equip_text: String = "Equip"
@export var unequip_text: String = "Unequip"

var blue_button = preload("res://assets/ui/player_hud/inventory/Blue_Markbook.png")
var white_button = preload("res://assets/ui/player_hud/inventory/Gray_Markbook.png")
var orange_button = preload("res://assets/ui/player_hud/inventory/Orange_Markbook.png")

# các ô hiển thị trên giao diện tương ứng với inventory
var slot_uis: Array[InventorySlotUI] = []
var selected_slot_index: int = -1

var _is_open: bool = false
var _is_closing: bool = false
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _transition_tween: Tween
var _info_tween: Tween
var _book_scale: Vector2
var _tab_base_scales: Dictionary[TextureButton, Vector2] = {}
var _tab_tweens: Dictionary[TextureButton, Tween] = {}

@onready var panel: PanelContainer = $PanelContainer
@onready var book_background: TextureRect = $PanelContainer/Background
@onready var tab_buttons: Control = $TabButtons
@onready var tabs: TabContainer = $PanelContainer/MarginContainer/Tabs
@onready var grid: GridContainer = tabs.get_node("Material/Content/ItemScroll/GridContainer")
@onready var material_button: TextureButton = $TabButtons/MaterialButton
@onready var equipment_button: TextureButton = $TabButtons/EquipmentButton
@onready var notes_button: TextureButton = $TabButtons/NotesButton
@onready var info_layout: Control = tabs.get_node(
	"Material/Content/ItemInfo/MarginContainer/VBoxContainer"
)
@onready var equip_potion_button: TextureButton = info_layout.get_node("EquipPotionButton")
@onready var equip_potion_label: Label = equip_potion_button.get_node("Label")
@onready var item_icon: TextureRect = info_layout.get_node("IconCenter/IconFrame/ItemIcon")
@onready var item_name: Label = info_layout.get_node("ItemName")
@onready var item_type: Label = info_layout.get_node("ItemType")
@onready var item_description: Label = info_layout.get_node("Description")
@onready var item_quantity: Label = info_layout.get_node("Quantity")
@onready var equipment_tab: Control = tabs.get_node("Equipment")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_book_scale = book_background.scale
	for button: TextureButton in [material_button, equipment_button, notes_button]:
		_tab_base_scales[button] = button.scale
		button.resized.connect(_update_tab_pivot.bind(button))
	_restore_tab_feedback.call_deferred()
	_bind_equipment.call_deferred()
	hide()
	if inventory == null:
		push_error("Chưa gán inventory cho ui")
		return

	for index in range(inventory.slots.size()):
		var slot_ui = SLOT_SCENE.instantiate() as InventorySlotUI
		slot_ui.inventory = inventory
		slot_ui.slot_index = index
		grid.add_child(slot_ui)
		slot_ui.clicked.connect(_on_slot_clicked.bind(index))
		slot_ui.item_dropped.connect(_on_item_dropped)
		slot_uis.append(slot_ui)
		slot_ui.refresh(inventory.slots[index])
		slot_ui.set_potion_assignment(_potion_assignment(inventory.slots[index]))

	inventory.changed.connect(refresh)
	if is_instance_valid(potion_component):
		potion_component.equipped_potion_changed.connect(_on_equipped_potion_changed)
		potion_component.secondary_potion_changed.connect(_on_equipped_potion_changed)
	_select_tab(0)
	_refresh_item_info()


func _input(event: InputEvent) -> void:
	# Xử lý trước GUI để Tab không bị dùng làm phím chuyển focus.
	if event.is_action_pressed(toggle_action):
		toggle_inventory()
		get_viewport().set_input_as_handled()
	elif _is_open and event.is_action_pressed(&"ui_cancel"):
		close_inventory()
		get_viewport().set_input_as_handled()


func refresh() -> void:
	for index in range(slot_uis.size()):
		slot_uis[index].refresh(inventory.slots[index])
		slot_uis[index].set_potion_assignment(_potion_assignment(inventory.slots[index]))
	_refresh_item_info()
	_update_slot_selection()
	equipment_tab.refresh()


func _bind_equipment() -> void:
	var player := get_parent() as Player
	if player != null:
		equipment_tab.bind_components(player.weapon_controller, player.charm_socket_manager)


func _on_slot_clicked(index: int) -> void:
	selected_slot_index = index
	_refresh_item_info()
	_update_slot_selection()
	if selected_slot_index >= 0:
		if _info_tween != null and _info_tween.is_valid():
			_info_tween.kill()
		info_layout.modulate.a = 0.55
		_info_tween = create_tween()
		_info_tween.tween_property(info_layout, "modulate:a", 1.0, 0.12)


func _update_slot_selection() -> void:
	for index in range(slot_uis.size()):
		slot_uis[index].set_selected(index == selected_slot_index)


func _on_item_dropped(from_index: int, to_index: int) -> void:
	if inventory.move_item(from_index, to_index):
		_on_slot_clicked(to_index)
		slot_uis[to_index].play_drop_feedback()


func _refresh_item_info() -> void:
	var slot: InventorySlot = inventory.get_slot(selected_slot_index)
	if slot == null or slot.is_empty():
		selected_slot_index = -1
		item_icon.texture = null
		item_name.text = ""
		item_type.text = ""
		item_description.text = ""
		item_quantity.text = ""
		equip_potion_button.hide()
		return

	item_icon.texture = slot.item.icon
	item_name.text = slot.item.display_name
	item_type.text = GlobalConstants.ItemType.keys()[slot.item.type]
	item_description.text = slot.item.description
	item_quantity.text = "%d/%d" % [slot.quantity, slot.item.max_stack]

	equip_potion_button.visible = slot.item is Potion and is_instance_valid(potion_component)
	if not equip_potion_button.visible:
		return
	var equipped := potion_component.is_equipped(slot.item as Potion)
	equip_potion_label.text = unequip_text if equipped else equip_text
	equip_potion_button.tooltip_text = "Tháo bình chính" if equipped else "Trang bị bình chính"


func _on_equipped_potion_changed(_potion: Potion) -> void:
	_refresh_potion_assignments()
	_refresh_item_info()


func _refresh_potion_assignments() -> void:
	for index in range(slot_uis.size()):
		slot_uis[index].set_potion_assignment(_potion_assignment(inventory.slots[index]))


func _potion_assignment(slot: InventorySlot) -> String:
	if slot == null or slot.is_empty() or not slot.item is Potion:
		return ""
	if not is_instance_valid(potion_component):
		return ""
	var potion := slot.item as Potion
	if potion_component.is_equipped(potion):
		return "MAIN"
	if potion_component.is_secondary_equipped(potion):
		return "BACKUP"
	return ""


func _on_material_button_pressed() -> void:
	_select_tab(0)


func _on_equipment_button_pressed() -> void:
	_select_tab(1)


func _on_notes_button_pressed() -> void:
	_select_tab(2)


func _select_tab(index: int) -> void:
	var buttons: Array[TextureButton] = [material_button, equipment_button, notes_button]
	var active_textures: Array[Texture2D] = [orange_button, blue_button, white_button]

	if index < 0 or index >= buttons.size():
		return

	_cancel_inventory_drag()
	tabs.current_tab = index
	if index == 1:
		equipment_tab.refresh()

	for i in range(buttons.size()):
		var selected: bool = i == index
		buttons[i].set_pressed_no_signal(selected)
		_set_tab_feedback(buttons[i], selected, _is_open and not _is_closing)


func _update_tab_pivot(button: TextureButton) -> void:
	# Grow outward from the book edge without moving the VBox or its hit-area layout.
	button.pivot_offset = Vector2(0.0, button.size.y * 0.5)


func _set_tab_feedback(button: TextureButton, selected: bool, animate: bool) -> void:
	var previous := _tab_tweens.get(button) as Tween
	if previous != null and previous.is_valid():
		previous.kill()
	_update_tab_pivot(button)
	var base_scale := _tab_base_scales[button]
	var target_scale := base_scale * (selected_tab_scale if selected else Vector2.ONE)
	var target_color := Color.WHITE if selected else Color.GRAY
	button.z_index = 1 if selected else 0
	if not animate:
		button.scale = target_scale
		button.modulate = target_color
		return
	var tween := create_tween().set_parallel(true)
	_tab_tweens[button] = tween
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "modulate", target_color, tab_feedback_duration)
	if selected:
		# Keep vertical growth small so adjacent tabs remain separated during the punch.
		var punch_scale := target_scale * Vector2(1.04, 1.0)
		tween.tween_property(button, "scale", punch_scale, tab_feedback_duration * 0.6)
		tween.chain().tween_property(button, "scale", target_scale, tab_feedback_duration)
	else:
		tween.tween_property(button, "scale", target_scale, tab_feedback_duration)


func _restore_tab_feedback() -> void:
	var buttons: Array[TextureButton] = [material_button, equipment_button, notes_button]
	for i in buttons.size():
		_set_tab_feedback(buttons[i], i == tabs.current_tab, false)


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
	refresh()
	show()
	# Containers reset child scale when laying out; restore after the opening layout pass.
	_restore_tab_feedback.call_deferred()
	book_background.pivot_offset = book_background.size * 0.5
	if fresh_open:
		panel.modulate.a = 0.0
		tab_buttons.modulate.a = 0.0
		book_background.scale = _book_scale * 0.96
	_transition_tween = create_tween().set_parallel()
	_transition_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_transition_tween.tween_property(panel, "modulate:a", 1.0, open_duration)
	_transition_tween.tween_property(tab_buttons, "modulate:a", 1.0, open_duration)
	_transition_tween.tween_property(book_background, "scale", _book_scale, open_duration)


func close_inventory(immediate: bool = false) -> void:
	if not _is_open:
		return
	if _is_closing and not immediate:
		return
	_cancel_inventory_drag()
	_kill_transition()
	if immediate:
		_finish_close()
		return
	_is_closing = true
	_transition_tween = create_tween().set_parallel()
	_transition_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_transition_tween.tween_property(panel, "modulate:a", 0.0, close_duration)
	_transition_tween.tween_property(tab_buttons, "modulate:a", 0.0, close_duration)
	_transition_tween.tween_property(book_background, "scale", _book_scale * 0.96, close_duration)
	_transition_tween.chain().tween_callback(_finish_close)


func _kill_transition() -> void:
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition_tween = null


func _finish_close() -> void:
	_is_open = false
	_is_closing = false
	hide()
	_restore_tab_feedback()
	panel.modulate.a = 1.0
	tab_buttons.modulate.a = 1.0
	book_background.scale = _book_scale
	Input.mouse_mode = _previous_mouse_mode
	get_node("/root/GameManager").exit_inventory()


func _cancel_inventory_drag() -> void:
	var viewport: Viewport = get_viewport()
	if not viewport.gui_is_dragging():
		return
	var data: Variant = viewport.gui_get_drag_data()
	if data is Dictionary and data.get("inventory") == inventory:
		viewport.gui_cancel_drag()


func toggle_inventory() -> void:
	if _is_closing:
		open_inventory()
	elif _is_open:
		close_inventory()
	else:
		open_inventory()


func is_open() -> bool:
	return _is_open


func _exit_tree() -> void:
	if _is_open:
		Input.mouse_mode = _previous_mouse_mode
		get_node("/root/GameManager").exit_inventory()


func _on_equip_potion_button_pressed() -> void:
	if potion_component == null:
		return

	var slot: InventorySlot = inventory.get_slot(selected_slot_index)
	if slot == null or slot.is_empty() or slot.item is not Potion:
		return

	var potion := slot.item as Potion
	if potion_component.is_equipped(potion):
		potion_component.unequip_potion()
	else:
		potion_component.equip_potion(potion)
