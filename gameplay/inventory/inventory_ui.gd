class_name InventoryUI
extends CanvasLayer

# túi dữ liệu
@export var inventory: Inventory
@export var toggle_action: StringName = &"inventory"

const SLOT_SCENE: PackedScene = preload(
	"res://gameplay/inventory/inventory_slot_ui.tscn"
)

@onready var grid: GridContainer = $PanelContainer/MarginContainer/Tabs/Material/Content/ItemScroll/GridContainer
@onready var tabs: TabContainer = $PanelContainer/MarginContainer/Tabs
@onready var material_button: TextureButton = $TabButtons/MaterialButton
@onready var equipment_button: TextureButton = $TabButtons/EquipmentButton
@onready var notes_button: TextureButton = $TabButtons/NotesButton
@onready var info_layout: VBoxContainer = $PanelContainer/MarginContainer/Tabs/Material/Content/ItemInfo/MarginContainer/VBoxContainer
@onready var item_icon: TextureRect = info_layout.get_node("IconCenter/IconFrame/ItemIcon")
@onready var item_name: Label = info_layout.get_node("ItemName")
@onready var item_type: Label = info_layout.get_node("ItemType")
@onready var item_description: Label = info_layout.get_node("Description")
@onready var item_quantity: Label = info_layout.get_node("Quantity")

var blue_button = preload("res://assets/ui/player_hud/inventory/blue_button.png")
var disable_blue_button = preload("res://assets/ui/player_hud/inventory/disable_blue_button.png")
var white_button = preload("res://assets/ui/player_hud/inventory/white_button.png")
var disable_white_button = preload("res://assets/ui/player_hud/inventory/disable_white_button.png")
var orange_button = preload("res://assets/ui/player_hud/inventory/orange_button.png")
var disable_orange_button = preload("res://assets/ui/player_hud/inventory/disable_orange_button.png")

# các ô hiển thị trên giao diện tương ứng với inventory
var slot_uis: Array[InventorySlotUI] = []
var selected_slot_index: int = -1

var _is_open: bool = false
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	hide()
	if inventory == null:
		push_error("Chưa gán inventory cho ui")
		return

	for index in range(inventory.slots.size()):
		var slot_ui = SLOT_SCENE.instantiate() as InventorySlotUI
		grid.add_child(slot_ui)
		slot_ui.clicked.connect(_on_slot_clicked.bind(index))
		slot_uis.append(slot_ui)
		slot_ui.refresh(inventory.slots[index])

	inventory.changed.connect(refresh)
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
	_refresh_item_info()


func _on_slot_clicked(index: int) -> void:
	selected_slot_index = index
	_refresh_item_info()


func _refresh_item_info() -> void:
	var slot: InventorySlot = inventory.get_slot(selected_slot_index)
	if slot == null or slot.is_empty():
		selected_slot_index = -1
		item_icon.texture = null
		item_name.text = ""
		item_type.text = ""
		item_description.text = ""
		item_quantity.text = ""
		return

	item_icon.texture = slot.item.icon
	item_name.text = slot.item.display_name
	# BaseItem chưa có thuộc tính phân loại; tạm dùng nhãn chung.
	item_type.text = ""
	item_description.text = slot.item.description
	item_quantity.text = "%d" % slot.quantity


func _on_material_button_pressed() -> void:
	_select_tab(0)


func _on_equipment_button_pressed() -> void:
	_select_tab(1)



func _on_notes_button_pressed() -> void:
	_select_tab(2)


func _select_tab(index: int) -> void:
	var buttons: Array[TextureButton] = [
		material_button, equipment_button, notes_button
	]
	var active_textures: Array[Texture2D] = [
		orange_button, blue_button, white_button
	]
	var inactive_textures: Array[Texture2D] = [
		disable_orange_button, disable_blue_button, disable_white_button
	]

	if index < 0 or index >= buttons.size():
		return

	tabs.current_tab = index

	for i in range(buttons.size()):
		var selected: bool = i == index
		buttons[i].set_pressed_no_signal(selected)
		buttons[i].texture_normal = (
			active_textures[i] if selected else inactive_textures[i]
		)
		buttons[i].modulate = Color.WHITE if selected else Color.GRAY


func open_inventory() -> void:
	if _is_open or not is_instance_valid(inventory):
		return
	var player := get_parent() as Player
	if player != null and player.dead:
		return
	_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_is_open = true
	refresh()
	show()


func close_inventory() -> void:
	if not _is_open:
		return
	_is_open = false
	hide()
	Input.mouse_mode = _previous_mouse_mode


func toggle_inventory() -> void:
	if _is_open:
		close_inventory()
	else:
		open_inventory()


func is_open() -> bool:
	return _is_open


func _exit_tree() -> void:
	if _is_open:
		Input.mouse_mode = _previous_mouse_mode
