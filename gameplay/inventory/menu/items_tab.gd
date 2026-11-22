class_name InventoryItemsTab
extends Control
## Inventory page: category filters, the real bag grid, item details and the two potion loadout
## slots. Inventory owns slots and stacks; PotionComponent owns the Main/Secondary assignment.

enum Filter { ALL, CONSUMABLE, AMMUNITION, MATERIAL, QUEST }

const SLOT_SCENE: PackedScene = preload("res://gameplay/inventory/inventory_slot_ui.tscn")
const PLACEHOLDER_SCENE: PackedScene = preload("res://gameplay/inventory/menu/catalog_slot.tscn")
const GRID_COLUMNS := 5
const MIN_VISIBLE_ROWS := 4
const MAIN_TAG := "MAIN"
const SECONDARY_TAG := "2ND"
const EMPTY_LOADOUT_NAME := "empty"
const POTION_KIND_NAMES := {
	Potion.Kind.HEALTH: "health",
	Potion.Kind.STAMINA: "stamina",
	Potion.Kind.DUAL_ESSENCE: "dual essence",
}
const FILTER_NAMES := {
	Filter.ALL: "items",
	Filter.CONSUMABLE: "consumables",
	Filter.AMMUNITION: "ammunition",
	Filter.MATERIAL: "materials",
	Filter.QUEST: "quest items",
}

@export_range(1.0, 1.3, 0.01) var loadout_slot_lift: float = 1.08
@export var potion_action: StringName = &"potion"
@export var swap_action: StringName = &"swap_potion"
@export_range(0.01, 0.5, 0.01, "suffix:s") var info_fade_seconds: float = 0.12
@export_range(0.0, 1.0, 0.01) var info_fade_from_alpha: float = 0.55
## Assigned potions with no bottles left stay visible like the HUD, but dimmed.
@export_range(0.0, 1.0, 0.01) var depleted_loadout_alpha: float = 0.45

var inventory: Inventory
var potion_component: PotionComponent
var weapons: WeaponController
var slot_uis: Array[InventorySlotUI] = []
var selected_slot_index: int = -1

var _filter: Filter = Filter.ALL
var _ammo_ids: Dictionary[String, bool] = {}
var _placeholders: Array[InventoryCatalogSlot] = []
var _info_tween: Tween
var _dirty: bool = true

@onready var _grid: GridContainer = %Grid
@onready var _empty_label: Label = %EmptyLabel
@onready var _counter_label: Label = %CounterLabel
@onready var _detail: Control = %Detail
@onready var _big_icon: TextureRect = %BigIcon
@onready var _item_name: Label = %ItemName
@onready var _type_banner: Label = %TypeBanner
@onready var _stack_banner: Label = %StackBanner
@onready var _description: Label = %Description
@onready var _description_scroll: ScrollContainer = %DescriptionScroll
@onready var _carry_info: Label = %CarryInfo
@onready var _main_button: Button = %MainButton
@onready var _secondary_button: Button = %SecondaryButton
@onready var _action_hint: Label = %ActionHint
@onready var _main_loadout: Button = %MainLoadout
@onready var _main_loadout_icon: TextureRect = %MainLoadoutIcon
@onready var _main_loadout_count: Label = %MainLoadoutCount
@onready var _secondary_loadout: Button = %SecondaryLoadout
@onready var _secondary_loadout_icon: TextureRect = %SecondaryLoadoutIcon
@onready var _secondary_loadout_count: Label = %SecondaryLoadoutCount
@onready var _main_caption: Label = %MainCaption
@onready var _secondary_caption: Label = %SecondaryCaption
@onready var _filter_chips: Dictionary[Filter, InventoryFilterChip] = {
	Filter.ALL: %FilterAll,
	Filter.CONSUMABLE: %FilterConsumable,
	Filter.AMMUNITION: %FilterAmmunition,
	Filter.MATERIAL: %FilterMaterial,
	Filter.QUEST: %FilterQuest,
}


func _ready() -> void:
	for filter: Filter in _filter_chips:
		_filter_chips[filter].pressed.connect(set_filter.bind(filter))
	_main_button.pressed.connect(_on_main_button_pressed)
	_secondary_button.pressed.connect(_on_secondary_button_pressed)
	_main_loadout.pressed.connect(_select_loadout_potion.bind(true))
	_secondary_loadout.pressed.connect(_select_loadout_potion.bind(false))
	visibility_changed.connect(_on_visibility_changed)
	for button: Button in [_main_button, _secondary_button]:
		InventoryHoverFeedback.attach(button)
	for button: Button in [_main_loadout, _secondary_loadout]:
		InventoryHoverFeedback.attach(button, null, loadout_slot_lift)
	_main_caption.text = "Main  ·  %s" % InventoryMenuFormat.action_key(potion_action)
	_secondary_caption.text = "Secondary  ·  %s" % InventoryMenuFormat.action_key(swap_action)
	_update_filter_chips()


## Binds the live data owners once. Slot UIs map 1:1 to real inventory indices.
func setup(bag: Inventory, potions: PotionComponent, weapon_controller: WeaponController) -> void:
	if is_instance_valid(inventory):
		return
	inventory = bag
	potion_component = potions
	weapons = weapon_controller
	if not is_instance_valid(inventory):
		push_error("InventoryItemsTab: inventory is not assigned")
		return

	for index in range(inventory.slots.size()):
		var slot_ui := SLOT_SCENE.instantiate() as InventorySlotUI
		slot_ui.inventory = inventory
		slot_ui.slot_index = index
		_grid.add_child(slot_ui)
		slot_ui.clicked.connect(_on_slot_clicked.bind(index))
		slot_ui.item_dropped.connect(_on_item_dropped)
		slot_uis.append(slot_ui)

	inventory.changed.connect(_request_refresh)
	if is_instance_valid(potion_component):
		potion_component.equipped_potion_changed.connect(_on_potion_assignment_changed)
		potion_component.secondary_potion_changed.connect(_on_potion_assignment_changed)
	if is_instance_valid(weapons):
		weapons.collection_changed.connect(_on_weapon_collection_changed)
	_collect_ammo_ids()
	_request_refresh()


func refresh() -> void:
	_dirty = false
	if not is_instance_valid(inventory):
		_show_unavailable()
		return

	var visible_count: int = 0
	for index in range(slot_uis.size()):
		var slot: InventorySlot = inventory.slots[index]
		var shown := _filter == Filter.ALL or (not slot.is_empty() and _matches(slot.item))
		slot_uis[index].visible = shown
		slot_uis[index].refresh(slot)
		_apply_assignment_tag(slot_uis[index], slot)
		if shown:
			visible_count += 1
	_update_placeholders(visible_count)
	_empty_label.visible = visible_count == 0
	_empty_label.text = "No %s in your bag yet." % FILTER_NAMES[_filter]

	if not _is_selectable(selected_slot_index):
		selected_slot_index = -1
	_update_slot_selection()
	var used: int = inventory.slots.size() - inventory.get_empty_slot_count()
	_counter_label.text = "%d/%d" % [used, inventory.slots.size()]
	_refresh_details()
	_refresh_loadout()


func set_filter(filter: Filter) -> void:
	cancel_drag()
	var changed := filter != _filter
	_filter = filter
	_update_filter_chips()
	refresh()
	if changed:
		InventoryMenuFx.stagger_in(_grid.get_children())


## Entrance animation played by the menu when this page appears.
func play_intro() -> void:
	InventoryMenuFx.stagger_in(_grid.get_children())
	InventoryMenuFx.pop(_big_icon, InventoryMenuFx.ICON_POP_FROM_SCALE)
	InventoryMenuFx.stagger_in([_main_loadout, _secondary_loadout])


## Moves keyboard focus into the page when the menu opens or this tab is chosen.
func focus_default() -> void:
	var target: Control = _filter_chips[_filter]
	if _is_selectable(selected_slot_index):
		target = slot_uis[selected_slot_index]
	target.grab_focus.call_deferred()


## Called whenever the menu hides this page or closes, so an in-flight drag cannot land later.
func cancel_drag() -> void:
	var viewport := get_viewport()
	if viewport == null or not viewport.gui_is_dragging():
		return
	var data: Variant = viewport.gui_get_drag_data()
	if data is Dictionary and data.get("inventory") == inventory:
		viewport.gui_cancel_drag()


func _request_refresh() -> void:
	if is_visible_in_tree():
		refresh()
	else:
		_dirty = true


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		cancel_drag()
	elif _dirty:
		refresh()


func _on_potion_assignment_changed(_potion: Potion) -> void:
	_request_refresh()


func _on_weapon_collection_changed() -> void:
	_collect_ammo_ids()
	_request_refresh()


## Ammunition has no ItemType of its own; an item counts as ammo when a known weapon attack
## consumes it through AttackData.ammo_id.
func _collect_ammo_ids() -> void:
	_ammo_ids.clear()
	if not is_instance_valid(weapons):
		return
	var definitions: Array[WeaponData] = []
	for entry: WeaponCollectionEntry in weapons.collection:
		if entry != null and entry.definition != null:
			definitions.append(entry.definition)
	for weapon: WeaponInstance in weapons.get_owned_weapons():
		if weapon.definition != null:
			definitions.append(weapon.definition)
	for definition: WeaponData in definitions:
		for attack: AttackData in [definition.normal_attack, definition.secondary_attack]:
			if attack != null and not attack.ammo_id.is_empty():
				_ammo_ids[String(attack.ammo_id)] = true


func _category(item: BaseItem) -> int:
	if _ammo_ids.has(item.item_id):
		return Filter.AMMUNITION
	match item.type:
		GlobalConstants.ItemType.CONSUMABLE:
			return Filter.CONSUMABLE
		GlobalConstants.ItemType.MATERIAL:
			return Filter.MATERIAL
		GlobalConstants.ItemType.QUEST:
			return Filter.QUEST
	# Equipment items have no dedicated filter and only appear under All.
	return -1


func _category_name(item: BaseItem) -> String:
	match _category(item):
		Filter.AMMUNITION:
			return "Ammunition"
		Filter.CONSUMABLE:
			return "Consumable"
		Filter.MATERIAL:
			return "Material"
		Filter.QUEST:
			return "Quest Item"
	return "Equipment"


func _matches(item: BaseItem) -> bool:
	return item != null and _category(item) == _filter


func _is_selectable(index: int) -> bool:
	if index < 0 or index >= slot_uis.size() or not slot_uis[index].visible:
		return false
	var slot := inventory.get_slot(index)
	return slot != null and not slot.is_empty()


func _update_filter_chips() -> void:
	for filter: Filter in _filter_chips:
		_filter_chips[filter].set_active(filter == _filter)


func _update_placeholders(visible_count: int) -> void:
	var rows: int = maxi(MIN_VISIBLE_ROWS, ceili(float(visible_count) / GRID_COLUMNS))
	var needed: int = rows * GRID_COLUMNS - visible_count
	while _placeholders.size() < needed:
		var placeholder := PLACEHOLDER_SCENE.instantiate() as InventoryCatalogSlot
		_grid.add_child(placeholder)
		placeholder.present_placeholder()
		_placeholders.append(placeholder)
	for index in range(_placeholders.size()):
		_placeholders[index].visible = index < needed


func _apply_assignment_tag(slot_ui: InventorySlotUI, slot: InventorySlot) -> void:
	if not is_instance_valid(potion_component) or slot.is_empty() or slot.item is not Potion:
		slot_ui.set_potion_assignment("")
		return
	var potion := slot.item as Potion
	if potion_component.is_equipped(potion):
		slot_ui.set_potion_assignment(MAIN_TAG, true)
	elif potion_component.is_secondary_equipped(potion):
		slot_ui.set_potion_assignment(SECONDARY_TAG, false)
	else:
		slot_ui.set_potion_assignment("")


func _on_slot_clicked(index: int) -> void:
	if not _is_selectable(index):
		return
	var changed := index != selected_slot_index
	selected_slot_index = index
	_update_slot_selection()
	_refresh_details()
	if changed:
		_play_info_fade()


func _on_item_dropped(from_index: int, to_index: int) -> void:
	# Indices come from the slot UIs themselves, so filtered views still address real slots.
	if inventory.move_item(from_index, to_index):
		selected_slot_index = to_index
		refresh()
		slot_uis[to_index].play_drop_feedback()


func _update_slot_selection() -> void:
	for index in range(slot_uis.size()):
		slot_uis[index].set_selected(index == selected_slot_index)


func _play_info_fade() -> void:
	if _info_tween != null and _info_tween.is_valid():
		_info_tween.kill()
	_detail.modulate.a = info_fade_from_alpha
	_info_tween = create_tween()
	_info_tween.tween_property(_detail, "modulate:a", 1.0, info_fade_seconds)
	InventoryMenuFx.pop(_big_icon, InventoryMenuFx.ICON_POP_FROM_SCALE)


func _refresh_details() -> void:
	_action_hint.text = ""
	_action_hint.tooltip_text = ""
	_description_scroll.scroll_vertical = 0
	var slot := inventory.get_slot(selected_slot_index)
	if slot == null or slot.is_empty():
		_big_icon.texture = null
		_item_name.text = "No item selected"
		_item_name.tooltip_text = ""
		_type_banner.text = ""
		_stack_banner.text = ""
		_description.text = "Select an item in your bag to read its details."
		_carry_info.text = ""
		_main_button.hide()
		_secondary_button.hide()
		return

	var item := slot.item
	_big_icon.texture = item.icon
	_item_name.text = item.display_name if not item.display_name.is_empty() else item.item_id
	_item_name.tooltip_text = _item_name.text
	_type_banner.text = _category_name(item)
	_stack_banner.text = "x%d/%d" % [slot.quantity, item.max_stack]
	_stack_banner.tooltip_text = "This stack holds %d of %d." % [slot.quantity, item.max_stack]
	_description.text = (
		item.description.strip_edges()
		if not item.description.strip_edges().is_empty()
		else "No description yet."
	)
	if item is Potion:
		_show_potion_details(item as Potion)
	else:
		_carry_info.text = "Total carried: %d" % inventory.count_item(item.item_id)
		_main_button.hide()
		_secondary_button.hide()
		_action_hint.text = "Only potions can go in the Potion Loadout."


func _show_potion_details(potion: Potion) -> void:
	var kind_name: String = POTION_KIND_NAMES.get(potion.potion_kind, "")
	# Small and large bottles share one carrying limit per kind.
	_carry_info.text = (
		"Carrying %d/%d %s potions (small + large)"
		% [
			inventory.count_potions(potion.potion_kind),
			inventory.get_potion_capacity(potion.potion_kind),
			kind_name,
		]
	)
	_main_button.show()
	_secondary_button.show()
	if not is_instance_valid(potion_component):
		_main_button.disabled = true
		_secondary_button.disabled = true
		_action_hint.text = "Potion loadout is unavailable."
		return

	var is_main := potion_component.is_equipped(potion)
	var is_secondary := potion_component.is_secondary_equipped(potion)
	var main := potion_component.equipped_potion
	var secondary := potion_component.secondary_potion
	_main_button.disabled = false
	_secondary_button.disabled = false
	_main_button.text = "Remove Main" if is_main else "Set Main"
	_secondary_button.text = "Remove 2nd" if is_secondary else "Set 2nd"
	if is_main:
		_main_button.tooltip_text = (
			"Clear Main. %s moves up to Main." % _potion_name(secondary)
			if secondary != null
			else "Clear the Main slot."
		)
		_secondary_button.tooltip_text = "Swap Main and Secondary."
	elif is_secondary:
		_main_button.tooltip_text = "Swap Main and Secondary."
		_secondary_button.tooltip_text = "Clear the Secondary slot."
	else:
		_main_button.tooltip_text = (
			"Use as Main (F). %s moves to Secondary." % _potion_name(main)
			if main != null
			else "Use as Main (F)."
		)
		_secondary_button.tooltip_text = (
			"Replace %s in Secondary." % _potion_name(secondary)
			if secondary != null
			else "Use as Secondary."
		)
	_action_hint.text = _loadout_summary()


func _on_main_button_pressed() -> void:
	var potion := _selected_potion()
	if potion == null or not is_instance_valid(potion_component):
		return
	var before := _loadout_state()
	var applied := (
		potion_component.unequip_potion()
		if potion_component.is_equipped(potion)
		else potion_component.equip_potion(potion)
	)
	_show_action_result(applied, _main_button, before)


func _on_secondary_button_pressed() -> void:
	var potion := _selected_potion()
	if potion == null or not is_instance_valid(potion_component):
		return
	var before := _loadout_state()
	var applied := (
		potion_component.unequip_secondary_potion()
		if potion_component.is_secondary_equipped(potion)
		else potion_component.equip_secondary_potion(potion)
	)
	_show_action_result(applied, _secondary_button, before)


func _show_action_result(applied: bool, source: Button, before: Array[Potion]) -> void:
	refresh()
	if not applied:
		_action_hint.text = "This potion cannot be assigned right now."
		InventoryMenuFx.shake(source)
		return
	_action_hint.text = _loadout_summary()
	var after := _loadout_state()
	_celebrate_loadout(_main_loadout, _main_loadout_icon, before[0] != after[0])
	_celebrate_loadout(_secondary_loadout, _secondary_loadout_icon, before[1] != after[1])


func _loadout_state() -> Array[Potion]:
	return [potion_component.equipped_potion, potion_component.secondary_potion]


## Draws the eye to a loadout slot whose assignment just changed.
func _celebrate_loadout(button: Button, icon: TextureRect, changed: bool) -> void:
	if not changed:
		return
	InventoryMenuFx.pop(icon, InventoryMenuFx.BADGE_POP_FROM_SCALE)
	if icon.texture != null:
		InventoryMenuFx.burst(button)


func _loadout_summary() -> String:
	return (
		"Main: %s  |  2nd: %s"
		% [
			_potion_name(potion_component.equipped_potion),
			_potion_name(potion_component.secondary_potion),
		]
	)


func _selected_potion() -> Potion:
	var slot := inventory.get_slot(selected_slot_index)
	if slot == null or slot.is_empty():
		return null
	return slot.item as Potion


func _potion_name(potion: Potion) -> String:
	return potion.display_name if potion != null else EMPTY_LOADOUT_NAME


func _refresh_loadout() -> void:
	var main: Potion = null
	var secondary: Potion = null
	if is_instance_valid(potion_component):
		main = potion_component.equipped_potion
		secondary = potion_component.secondary_potion
	_present_loadout_slot(_main_loadout, _main_loadout_icon, _main_loadout_count, main, "Main")
	_present_loadout_slot(
		_secondary_loadout, _secondary_loadout_icon, _secondary_loadout_count, secondary, "2nd"
	)


func _present_loadout_slot(
	button: Button, icon: TextureRect, count_label: Label, potion: Potion, slot_name: String
) -> void:
	if potion == null:
		icon.texture = null
		count_label.hide()
		button.tooltip_text = (
			"%s slot is empty. Select a potion and press Set %s." % [slot_name, slot_name]
		)
		return
	var count: int = inventory.count_item(potion.item_id)
	icon.texture = potion.icon
	icon.modulate.a = 1.0 if count > 0 else depleted_loadout_alpha
	count_label.text = str(count)
	count_label.show()
	button.tooltip_text = "%s: %s (%d left)" % [slot_name, potion.display_name, count]


func _select_loadout_potion(main: bool) -> void:
	if not is_instance_valid(potion_component):
		return
	var potion := potion_component.equipped_potion if main else potion_component.secondary_potion
	if potion == null:
		return
	for index in range(inventory.slots.size()):
		var slot := inventory.slots[index]
		if slot.is_empty() or slot.item.item_id != potion.item_id:
			continue
		if not slot_uis[index].visible:
			set_filter(Filter.ALL)
		_on_slot_clicked(index)
		return
	_action_hint.text = "No %s left in your bag." % potion.display_name


func _show_unavailable() -> void:
	_counter_label.text = ""
	_empty_label.visible = true
	_empty_label.text = "Inventory is unavailable."
	_refresh_details_unbound()


func _refresh_details_unbound() -> void:
	_big_icon.texture = null
	_item_name.text = "No item selected"
	_type_banner.text = ""
	_stack_banner.text = ""
	_description.text = ""
	_carry_info.text = ""
	_main_button.hide()
	_secondary_button.hide()
