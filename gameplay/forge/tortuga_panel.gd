class_name TortugaPanel
extends CanvasLayer

signal panel_closed

enum Tab { CRAFT, FORGE }

const SLOT_SCENE: PackedScene = preload("res://gameplay/forge/tortuga_slot.tscn")
const COST_SCENE: PackedScene = preload("res://gameplay/forge/tortuga_cost_chip.tscn")
const GOLD_ICON: Texture2D = preload(
	"res://assets/ui/silas_shop/PNG/21_gold_coin_skull_crossbones.png"
)
const TAB_ACTIVE: Texture2D = preload("res://assets/ui/silas_shop/PNG/32_tab_active_blank.png")
const TAB_IDLE: Texture2D = preload("res://assets/ui/silas_shop/PNG/33_tab_inactive_blank.png")
const COLUMNS := 4
const STEP := Vector2(94, 105)

@export var catalog: TortugaCatalog

var _player: Player
var _inventory: Inventory
var _wallet: GoldWallet
var _weapons: WeaponController
var _service: TortugaService
var _tab := Tab.CRAFT
var _selected_id: StringName = &""
var _pending_options: Array[WeaponForge] = []
var _previous_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _base_book_scale := Vector2.ONE

@onready var book: Control = $Book
@onready var grid: Control = $Book/GridScroll/Grid
@onready var empty_label: Label = $Book/Empty
@onready var craft_tab: TextureButton = $Book/Tabs/Craft
@onready var forge_tab: TextureButton = $Book/Tabs/Forge
@onready var icon: TextureRect = $Book/IconFrame/Icon
@onready var item_name: Label = $Book/ItemName
@onready var status: Label = $Book/Status
@onready var details: Control = $Book/DetailsScroll/WeaponDetails
@onready var cost_grid: Control = $Book/CostGrid
@onready var forge_popup: Control = $ForgePopup
@onready var action: TextureButton = $Book/Action
@onready var action_text: Label = $Book/Action/Text
@onready var feedback: Label = $Book/Feedback


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	book.pivot_offset = book.size * 0.5
	get_viewport().size_changed.connect(_fit_book)
	craft_tab.pressed.connect(_set_tab.bind(Tab.CRAFT))
	forge_tab.pressed.connect(_set_tab.bind(Tab.FORGE))
	action.pressed.connect(_on_action)
	forge_popup.connect(&"option_chosen", _choose_option)
	$Book/Close.pressed.connect(close_panel)
	$Book/DebugSupplies.visible = OS.has_feature("debug")
	$Book/DebugSupplies.pressed.connect(_on_debug_supplies)
	_fit_book()
	hide()


func open_for(player: Player) -> bool:
	if player == null or catalog == null or not catalog.is_valid():
		return false
	var manager := get_node_or_null("/root/GameManager")
	if manager == null or not manager.enter_inventory():
		return false
	var bag := player.get_node_or_null("Inventory") as Inventory
	var gold := manager.get("gold_wallet") as GoldWallet
	if bag == null or gold == null or player.weapon_controller == null:
		manager.exit_inventory()
		return false
	_player = player
	_inventory = bag
	_wallet = gold
	_weapons = player.weapon_controller
	_service = TortugaService.new(catalog, bag, gold, _weapons)
	_inventory.changed.connect(_refresh)
	_wallet.balance_changed.connect(_on_balance_changed)
	_weapons.collection_changed.connect(_refresh)
	_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_selected_id = &""
	_pending_options.clear()
	feedback.text = ""
	book.show()
	show()
	_set_tab(Tab.CRAFT)
	book.modulate.a = 0.0
	book.scale = _base_book_scale * 0.96
	var tween := create_tween().set_parallel().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(book, "modulate:a", 1.0, 0.16)
	tween.tween_property(book, "scale", _base_book_scale, 0.16)
	return true


func close_panel(force := false) -> void:
	if not visible:
		return
	if not force and not _pending_options.is_empty():
		forge_popup.get_node("Window/Subtitle").text = "Choose one result before leaving."
		return
	forge_popup.hide()
	book.show()
	book.process_mode = Node.PROCESS_MODE_INHERIT
	hide()
	if _inventory != null:
		_inventory.changed.disconnect(_refresh)
	if _wallet != null:
		_wallet.balance_changed.disconnect(_on_balance_changed)
	if _weapons != null:
		_weapons.collection_changed.disconnect(_refresh)
	_pending_options.clear()
	_service = null
	_player = null
	_inventory = null
	_wallet = null
	_weapons = null
	Input.mouse_mode = _previous_mouse_mode
	var manager := get_node_or_null("/root/GameManager")
	if manager != null:
		manager.exit_inventory()
	panel_closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close_panel()
		get_viewport().set_input_as_handled()


func _set_tab(next_tab: Tab) -> void:
	if not _pending_options.is_empty():
		return
	_tab = next_tab
	_selected_id = &""
	feedback.text = ""
	craft_tab.texture_normal = TAB_ACTIVE if _tab == Tab.CRAFT else TAB_IDLE
	forge_tab.texture_normal = TAB_ACTIVE if _tab == Tab.FORGE else TAB_IDLE
	craft_tab.get_node("Text").add_theme_color_override(
		"font_color", Color(1, 0.9, 0.7) if _tab == Tab.CRAFT else Color(0.29, 0.14, 0.1)
	)
	forge_tab.get_node("Text").add_theme_color_override(
		"font_color", Color(1, 0.9, 0.7) if _tab == Tab.FORGE else Color(0.29, 0.14, 0.1)
	)
	_refresh()


func _refresh() -> void:
	if _weapons == null or _inventory == null or _wallet == null:
		return
	_rebuild_grid()
	_refresh_details()


func _rebuild_grid() -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	var entries: Array[WeaponData] = []
	if _tab == Tab.CRAFT:
		for recipe in catalog.recipes:
			if (
				recipe != null
				and recipe.weapon != null
				and _weapons.is_blueprint_unlocked(recipe.weapon.weapon_id)
			):
				entries.append(recipe.weapon)
	else:
		for weapon in _weapons.get_owned_weapons():
			if weapon != null and weapon.definition != null:
				entries.append(weapon.definition)
	empty_label.visible = entries.is_empty()
	empty_label.text = (
		"No blueprints unlocked yet." if _tab == Tab.CRAFT else "No weapons owned yet."
	)
	grid.custom_minimum_size.y = maxf(350.0, ceilf(float(entries.size()) / COLUMNS) * STEP.y)
	for index in entries.size():
		var data := entries[index]
		var slot := SLOT_SCENE.instantiate() as Control
		grid.add_child(slot)
		slot.position = Vector2(index % COLUMNS, floori(float(index) / COLUMNS)) * STEP
		slot.get_node("Button/Icon").texture = data.icon
		slot.get_node("Button/Darken").visible = (
			_tab == Tab.CRAFT and _weapons.is_weapon_owned(data.weapon_id)
		)
		slot.get_node("Button/Highlight").visible = data.weapon_id == _selected_id
		slot.get_node("Name").text = data.display_name
		slot.get_node("Button").pressed.connect(_select_weapon.bind(data.weapon_id))
		slot.tooltip_text = data.display_name
	if _selected_id.is_empty() and not entries.is_empty():
		_selected_id = entries[0].weapon_id
		grid.get_child(0).get_node("Button/Highlight").visible = true


func _select_weapon(weapon_id: StringName) -> void:
	if not _pending_options.is_empty():
		return
	_selected_id = weapon_id
	feedback.text = ""
	_refresh()


func _selected_weapon() -> WeaponInstance:
	for weapon in _weapons.get_owned_weapons():
		if (
			weapon != null
			and weapon.definition != null
			and weapon.definition.weapon_id == _selected_id
		):
			return weapon
	return null


func _refresh_details() -> void:
	var data: WeaponData
	var recipe: TortugaRecipe
	var owned: WeaponInstance
	if _tab == Tab.CRAFT:
		recipe = catalog.get_recipe(_selected_id)
		data = recipe.weapon if recipe != null else null
	else:
		owned = _selected_weapon()
		data = owned.definition if owned != null else null
	icon.texture = data.icon if data != null else null
	item_name.text = data.display_name if data != null else "Select a weapon"
	if data == null:
		status.text = ""
		details.call(&"set_weapon", null, null)
		_clear_cost_grid()
		action.disabled = true
		return
	if _tab == Tab.CRAFT:
		var crafted := _weapons.is_weapon_owned(_selected_id)
		owned = _selected_weapon() if crafted else null
		status.text = "Crafted - Blueprint owned" if crafted else "Blueprint unlocked"
		details.call(&"set_weapon", data, owned)
		_fill_cost_grid(recipe.gold_cost, recipe.ingredients)
		action_text.text = "Crafted" if crafted else "Craft weapon"
		action.disabled = crafted or not _service.can_pay(recipe.gold_cost, recipe.ingredients)
	else:
		status.text = (
			"Current forge: " + (owned.forge.display_name if owned.forge != null else "None")
		)
		details.call(&"set_weapon", data, owned)
		_fill_cost_grid(catalog.forge_gold_cost, catalog.forge_ingredients)
		action_text.text = "Forge weapon"
		action.disabled = not _service.can_pay(catalog.forge_gold_cost, catalog.forge_ingredients)


func _fill_cost_grid(gold_cost: int, ingredients: Array[TortugaIngredient]) -> void:
	_clear_cost_grid()
	_add_cost_chip(GOLD_ICON, "Gold", _wallet.get_balance(), gold_cost, 0)
	for index in ingredients.size():
		var ingredient := ingredients[index]
		_add_cost_chip(
			ingredient.item.icon,
			ingredient.item.display_name,
			_inventory.count_item(StringName(ingredient.item.item_id)),
			ingredient.amount,
			index + 1
		)


func _add_cost_chip(
	texture: Texture2D, title: String, current: int, required: int, index: int
) -> void:
	var chip := COST_SCENE.instantiate() as Control
	cost_grid.add_child(chip)
	chip.position = Vector2(index % 2 * 154, floori(float(index) / 2.0) * 44)
	chip.call(&"set_cost", texture, title, current, required)


func _clear_cost_grid() -> void:
	for child in cost_grid.get_children():
		cost_grid.remove_child(child)
		child.queue_free()


func _on_action() -> void:
	if _selected_id.is_empty() or _service == null:
		return
	if _tab == Tab.CRAFT:
		var error := _service.craft(_selected_id)
		feedback.text = error if not error.is_empty() else "Weapon crafted!"
		if error.is_empty():
			_selected_id = &""
		_refresh()
		return
	_pending_options = _service.roll_forges(_selected_id)
	feedback.text = (
		"Choose one of the two new forges."
		if _pending_options.size() == 2
		else "Not enough gold or materials."
	)
	if _pending_options.size() == 2:
		book.process_mode = Node.PROCESS_MODE_DISABLED
		forge_popup.call(&"show_choices", _selected_weapon(), _pending_options)
		book.hide()
	else:
		_refresh_details()


func _choose_option(index: int) -> void:
	if index < 0 or index >= _pending_options.size() or _service == null:
		return
	var chosen := _pending_options[index]
	if _service.apply_forge(_selected_id, chosen):
		feedback.text = "Applied %s." % chosen.display_name
		_pending_options.clear()
		forge_popup.hide()
		book.show()
		book.process_mode = Node.PROCESS_MODE_INHERIT
		_refresh()
	else:
		forge_popup.get_node("Window/Subtitle").text = "Could not apply. Choose one result to continue."


func _on_balance_changed(_balance: int, _change: int) -> void:
	_refresh()


func _on_debug_supplies() -> void:
	if not OS.has_feature("debug") or _inventory == null or _wallet == null:
		return
	var items: Dictionary[String, BaseItem] = {}
	for recipe in catalog.recipes:
		for ingredient in recipe.ingredients:
			items[ingredient.item.item_id] = ingredient.item
	for ingredient in catalog.forge_ingredients:
		items[ingredient.item.item_id] = ingredient.item
	for item in items.values():
		_inventory.add_item(item, 10)
	_wallet.add_gold(500)
	feedback.text = "Debug supplies added."
	_refresh()


func _fit_book() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var factor := minf(viewport_size.x / 1130.0, viewport_size.y / 690.0)
	_base_book_scale = Vector2.ONE * minf(1.0, factor)
	book.scale = _base_book_scale
