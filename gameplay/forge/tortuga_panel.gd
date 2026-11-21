class_name TortugaPanel
extends CanvasLayer
## Master Tortuga's forge counter, built on the pause Inventory's visual system.
##
## Craft lists unlocked blueprints and Forge lists owned weapons. TortugaService owns every
## payment, grant and roll; this panel reads Inventory, GoldWallet and WeaponController only to
## explain costs. A paid Forge roll opens a modal choice that a normal close cannot dismiss.

signal panel_closed

enum Tab { CRAFT, FORGE }

const COST_SCENE: PackedScene = preload("res://gameplay/forge/tortuga_cost_chip.tscn")
const SLOT_SCENE: PackedScene = preload("res://gameplay/inventory/menu/catalog_slot.tscn")
const GOLD_ICON: Texture2D = preload("res://assets/ui/silas_shop/PNG/26_small_currency_coin.png")
const CRAFTED_BADGE: Texture2D = preload("res://assets/ui/HUD_Fox/Shop/Craft_Icon.png")
const FORGE_OPTION_COUNT := 2
const MIN_VISIBLE_ROWS := 2
const PREVIOUS_TAB_ACTION := &"ui_page_up"
const NEXT_TAB_ACTION := &"ui_page_down"
const CANCEL_ACTION := &"ui_cancel"
const INK_PROGRESS_PARAM := &"progress"
const INK_HIDDEN := 0.0
const INK_SHOWN := 1.0
const CENTER_RATIO := 0.5
const NO_COST_TEXT := "No cost. This one is on the house."
## The purse row fits the coin plus about seven digits at full size; larger balances shrink.
const PURSE_TEXT_WIDTH_PIXELS := 164.0
const GOLD_FONT_SIZE := 32
const GOLD_MIN_FONT_SIZE := 16
const SUCCESS_MARK := "✓ "
const REFUSAL_MARK := "✕ "
const SECTION_TITLES := {Tab.CRAFT: "Blueprints", Tab.FORGE: "Your arsenal"}
const COST_TITLES := {Tab.CRAFT: "Craft cost", Tab.FORGE: "Forge cost per roll"}
const COUNTER_TOOLTIPS := {
	Tab.CRAFT: "Unlocked blueprints / recipes at this forge",
	Tab.FORGE: "Weapons you own",
}
const FOOTNOTES := {
	Tab.CRAFT: "Crafted weapons go to your arsenal unequipped.",
	Tab.FORGE: "One forge per weapon. A new one replaces the old.",
}
const EMPTY_TEXTS := {
	Tab.CRAFT: "No blueprints yet. Find them out in the world.",
	Tab.FORGE: "You own no weapons to forge.",
}

@export var catalog: TortugaCatalog
@export_range(1, 8, 1) var grid_columns: int = 4
@export_multiline var craft_quote: String = '"Bring me plans and parts.\nI\'ll bring the fire."'
@export_multiline var forge_quote: String = '"Every edge can burn hotter.\nPay, then pick one."'

@export_group("Feedback Colors")
@export var success_color: Color = Color(0.66, 0.85, 0.58)
@export var refusal_color: Color = Color(0.95, 0.56, 0.5)
@export var hint_color: Color = Color(0.77, 0.61, 0.53)

@export_group("Panel Animation")
@export_range(0.05, 0.6, 0.01, "suffix:s") var open_duration: float = 0.3
@export_range(0.05, 0.5, 0.01, "suffix:s") var close_duration: float = 0.2
@export_range(0.5, 1.0, 0.01) var closed_frame_scale: float = 0.94
@export_range(0.1, 1.5, 0.01, "suffix:s") var ink_open_seconds: float = 0.6
@export_range(0.05, 1.0, 0.01, "suffix:s") var ink_close_seconds: float = 0.3
@export_range(0.0, 0.4, 0.01, "suffix:s") var frame_open_delay: float = 0.12
@export_range(0.0, 120.0, 1.0, "suffix:px") var page_slide_pixels: float = 36.0
@export_range(0.05, 0.6, 0.01, "suffix:s") var page_switch_seconds: float = 0.22
@export_range(1.0, 1.3, 0.01) var back_button_lift: float = 1.08

@export_group("Forge Fire")
## The coal glow behind Tortuga breathes slowly; a hammer strike flashes the screen.
@export_range(0.0, 1.0, 0.01) var heat_min_alpha: float = 0.45
@export_range(0.0, 1.0, 0.01) var heat_max_alpha: float = 0.85
@export_range(0.05, 3.0, 0.05, "suffix:Hz") var heat_breath_hz: float = 0.45
@export_range(0.0, 1.0, 0.01) var strike_flash_alpha: float = 0.35
@export_range(0.05, 1.0, 0.01, "suffix:s") var strike_flash_seconds: float = 0.32

@export_group("Debug Supplies")
@export_range(1, 99, 1) var debug_ingredient_amount: int = 10
@export_range(1, 9999, 1) var debug_gold_amount: int = 500

var _player: Player
var _inventory: Inventory
var _wallet: GoldWallet
var _weapons: WeaponController
var _service: TortugaService
var _tab: Tab = Tab.CRAFT
var _selected_id: StringName = &""
var _entries: Array[WeaponData] = []
var _slots: Array[InventoryCatalogSlot] = []
var _pending_options: Array[WeaponForge] = []
var _feedback_text: String = ""
var _feedback_color: Color = Color.WHITE
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _is_closing: bool = false
var _heat_time: float = 0.0
var _transition_tween: Tween
var _page_tween: Tween
var _flash_tween: Tween

## Public tab references stay plain buttons; the Inventory tab look is an implementation detail.
@onready var craft_tab: BaseButton = %CraftTab
@onready var forge_tab: BaseButton = %ForgeTab
@onready var grid: GridContainer = %Grid
@onready var action: Button = %ActionButton
@onready var forge_popup: TortugaForgePopup = %ForgePopup
@onready var _background: TextureRect = %Background
@onready var _frame: Control = %Frame
@onready var _page: Control = %Page
@onready var _embers: CPUParticles2D = %Embers
@onready var _forge_heat: CanvasItem = %ForgeHeat
@onready var _strike_flash: ColorRect = %StrikeFlash
@onready var _quote: Label = %Quote
@onready var _gold_label: Label = %GoldLabel
@onready var _section_title: Label = %SectionTitle
@onready var _counter: Control = %Counter
@onready var _counter_icon: TextureRect = %CounterIcon
@onready var _counter_label: Label = %CounterLabel
@onready var _empty_label: Label = %EmptyLabel
@onready var _cost_title: Label = %CostTitle
@onready var _cost_grid: GridContainer = %CostGrid
@onready var _footnote: Label = %Footnote
@onready var _big_icon: TextureRect = %BigIcon
@onready var _weapon_name: Label = %WeaponName
@onready var _status_line: Label = %StatusLine
@onready var _details: TortugaWeaponDetails = %WeaponDetails
@onready var _action_hint: Label = %ActionHint
@onready var _back_button: Button = %BackButton
@onready var _debug_supplies: Button = %DebugSupplies


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	set_process(false)
	grid.columns = grid_columns
	craft_tab.pressed.connect(_set_tab.bind(Tab.CRAFT))
	forge_tab.pressed.connect(_set_tab.bind(Tab.FORGE))
	action.pressed.connect(_on_action)
	forge_popup.option_chosen.connect(_choose_option)
	_back_button.pressed.connect(close_panel)
	_back_button.tooltip_text = "Leave (%s)" % InventoryMenuFormat.action_key(CANCEL_ACTION)
	_debug_supplies.visible = OS.has_feature("debug")
	_debug_supplies.pressed.connect(_on_debug_supplies)
	InventoryHoverFeedback.attach(action)
	InventoryHoverFeedback.attach(_back_button, null, back_button_lift)
	_frame.resized.connect(_update_frame_pivot)
	_update_frame_pivot()


func _process(delta: float) -> void:
	_heat_time += delta
	var breath := 0.5 + 0.5 * sin(_heat_time * heat_breath_hz * TAU)
	_forge_heat.modulate.a = lerpf(heat_min_alpha, heat_max_alpha, breath)


func _input(event: InputEvent) -> void:
	if not visible or _is_closing:
		return
	if event.is_action_pressed(CANCEL_ACTION):
		close_panel()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(PREVIOUS_TAB_ACTION) or event.is_action_pressed(NEXT_TAB_ACTION):
		if not _pending_options.is_empty():
			forge_popup.show_notice("Choose one result first.")
		else:
			_set_tab(Tab.FORGE if _tab == Tab.CRAFT else Tab.CRAFT)
			_focus_default()
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	# The owning NPC force-closes on teardown; this covers a panel freed on its own.
	if visible:
		close_panel(true)
	_kill_tween(_transition_tween)
	_kill_tween(_page_tween)
	_kill_tween(_flash_tween)


func open_for(player: Player) -> bool:
	if player == null or catalog == null or not catalog.is_valid() or visible or _is_closing:
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
	_set_feedback("")
	forge_popup.close()
	_frame.show()
	show()
	set_process(true)
	_tab = Tab.CRAFT
	_refresh_tabs(false)
	_refresh()
	_play_open_feedback()
	_focus_default()
	return true


## A normal close waits for a pending Forge choice. `force` is for teardown: it closes at once
## and returns that roll's payment, since the player can no longer pick a result.
func close_panel(force := false) -> void:
	if not visible:
		return
	if not _pending_options.is_empty():
		if not force:
			forge_popup.show_notice("Choose one result before leaving. It has been paid for.")
			return
		if _service != null:
			_service.refund_forge_roll()
		_pending_options.clear()
	if force:
		_finish_close()
		return
	if _is_closing:
		return
	_is_closing = true
	_kill_tween(_transition_tween)
	_embers.emitting = false
	_transition_tween = _make_tween()
	_transition_tween.set_parallel()
	_transition_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_transition_tween.tween_property(_frame, "modulate:a", 0.0, close_duration)
	_transition_tween.tween_property(
		_frame, "scale", Vector2.ONE * closed_frame_scale, close_duration
	)
	_transition_tween.tween_method(
		_set_ink_progress, _ink_progress(), INK_HIDDEN, ink_close_seconds
	)
	_transition_tween.chain().tween_callback(_finish_close)


func _set_tab(next_tab: Tab) -> void:
	if not _pending_options.is_empty() or _weapons == null:
		return
	var changed := next_tab != _tab
	_tab = next_tab
	_selected_id = &""
	_set_feedback("")
	_refresh_tabs(changed and visible and not _is_closing)
	_refresh()
	if changed and visible and not _is_closing:
		_slide_page_in(1 if _tab == Tab.FORGE else -1)


func _refresh_tabs(animate: bool) -> void:
	(craft_tab as InventoryMenuTabButton).set_active(_tab == Tab.CRAFT, animate)
	(forge_tab as InventoryMenuTabButton).set_active(_tab == Tab.FORGE, animate)
	_quote.text = craft_quote if _tab == Tab.CRAFT else forge_quote
	_section_title.text = SECTION_TITLES[_tab]
	_cost_title.text = COST_TITLES[_tab]
	_footnote.text = FOOTNOTES[_tab]
	var active_tab := (craft_tab if _tab == Tab.CRAFT else forge_tab) as InventoryMenuTabButton
	_counter_icon.texture = active_tab.idle_icon
	_counter.tooltip_text = COUNTER_TOOLTIPS[_tab]
	if animate:
		InventoryMenuFx.burst(craft_tab if _tab == Tab.CRAFT else forge_tab)


func _refresh() -> void:
	if _weapons == null or _inventory == null or _wallet == null:
		return
	_gold_label.text = InventoryMenuFormat.grouped(_wallet.get_balance())
	InventoryMenuFormat.fit_font_size(
		_gold_label, PURSE_TEXT_WIDTH_PIXELS, GOLD_FONT_SIZE, GOLD_MIN_FONT_SIZE
	)
	_gold_label.tooltip_text = "%s gold" % InventoryMenuFormat.grouped(_wallet.get_balance())
	_collect_entries()
	_refresh_grid()
	_refresh_details()


func _collect_entries() -> void:
	_entries.clear()
	if _tab == Tab.CRAFT:
		for recipe: TortugaRecipe in catalog.recipes:
			if (
				recipe != null
				and recipe.weapon != null
				and _weapons.is_blueprint_unlocked(recipe.weapon.weapon_id)
			):
				_entries.append(recipe.weapon)
		_counter_label.text = "%d/%d" % [_entries.size(), catalog.recipes.size()]
	else:
		for weapon: WeaponInstance in _weapons.get_owned_weapons():
			if weapon != null and weapon.definition != null:
				_entries.append(weapon.definition)
		_counter_label.text = str(_entries.size())
	var still_listed := false
	for data: WeaponData in _entries:
		still_listed = still_listed or data.weapon_id == _selected_id
	if not still_listed:
		_selected_id = _entries[0].weapon_id if not _entries.is_empty() else &""


func _refresh_grid() -> void:
	var rows := maxi(MIN_VISIBLE_ROWS, ceili(float(_entries.size()) / grid_columns))
	var cell_count := rows * grid_columns
	while _slots.size() < cell_count:
		var slot := SLOT_SCENE.instantiate() as InventoryCatalogSlot
		grid.add_child(slot)
		slot.pressed.connect(_select_index.bind(_slots.size()))
		_slots.append(slot)
	for index in range(_slots.size()):
		var slot := _slots[index]
		slot.visible = index < cell_count
		if index >= _entries.size():
			slot.present_placeholder()
			continue
		var data := _entries[index]
		var owned := _weapons.is_weapon_owned(data.weapon_id)
		var equipped := _is_equipped(data.weapon_id)
		var badge: Texture2D = null
		if equipped:
			badge = InventoryWeaponsTab.EQUIPPED_BADGE
		elif _tab == Tab.CRAFT and owned:
			badge = CRAFTED_BADGE
		slot.present(data.icon, true, false, badge)
		slot.set_selected(data.weapon_id == _selected_id)
		slot.tooltip_text = data.display_name + _state_suffix(data.weapon_id)
	_empty_label.text = EMPTY_TEXTS[_tab]
	_empty_label.visible = _entries.is_empty()


func _state_suffix(weapon_id: StringName) -> String:
	if _is_equipped(weapon_id):
		return "  ·  equipped"
	if _tab == Tab.CRAFT:
		return "  ·  crafted" if _weapons.is_weapon_owned(weapon_id) else "  ·  blueprint"
	var owned := _owned_instance(weapon_id)
	return "  ·  " + (owned.forge.display_name if owned.forge != null else "no forge")


func _select_index(index: int) -> void:
	if index >= _entries.size() or not _pending_options.is_empty():
		return
	var weapon_id := _entries[index].weapon_id
	if weapon_id == _selected_id:
		return
	_selected_id = weapon_id
	_set_feedback("")
	for slot_index in range(_slots.size()):
		_slots[slot_index].set_selected(
			slot_index < _entries.size() and _entries[slot_index].weapon_id == _selected_id
		)
	_refresh_details()
	InventoryMenuFx.pop(_big_icon, InventoryMenuFx.ICON_POP_FROM_SCALE)


func _refresh_details() -> void:
	_clear_cost_grid()
	var data := _selected_data()
	if data == null:
		_big_icon.texture = null
		_weapon_name.text = "Nothing selected"
		_status_line.text = ""
		_details.set_weapon(null, null)
		action.text = "Craft" if _tab == Tab.CRAFT else "Forge"
		action.disabled = true
		_show_hint("", EMPTY_TEXTS[_tab])
		return
	var owned := _owned_instance(data.weapon_id)
	_big_icon.texture = data.icon
	_weapon_name.text = data.display_name
	_weapon_name.tooltip_text = data.display_name
	_status_line.text = _status_text(data, owned)
	_details.set_weapon(data, owned)
	if _tab == Tab.CRAFT:
		var recipe := catalog.get_recipe(data.weapon_id)
		_fill_cost_grid(recipe.gold_cost, recipe.ingredients)
		if owned != null:
			action.text = "Crafted"
			action.disabled = true
			_show_hint("", "Already in your arsenal. Equip it from the Inventory.")
			return
		action.text = "Craft"
		var missing := _missing_text(recipe.gold_cost, recipe.ingredients)
		action.disabled = not missing.is_empty()
		_show_hint(missing, "Paid now. The weapon arrives unequipped.")
		return
	_fill_cost_grid(catalog.forge_gold_cost, catalog.forge_ingredients)
	action.text = "Forge"
	var shortfall := _missing_text(catalog.forge_gold_cost, catalog.forge_ingredients)
	action.disabled = not shortfall.is_empty()
	_show_hint(shortfall, "Pay once, then keep one of two results.")


func _status_text(data: WeaponData, owned: WeaponInstance) -> String:
	var parts: PackedStringArray = [
		WeaponData.WeaponCategory.keys()[data.category].capitalize() + " weapon"
	]
	if _tab == Tab.CRAFT:
		parts.append("Crafted" if owned != null else "Blueprint")
	elif owned != null:
		parts.append("Forge: " + (owned.forge.display_name if owned.forge != null else "none"))
	if _is_equipped(data.weapon_id):
		parts.append("Equipped")
	return "  ·  ".join(parts)


## Lists what is still missing, e.g. "Missing 25 gold, 3 Crab Claw"; empty when affordable.
func _missing_text(gold_cost: int, ingredients: Array[TortugaIngredient]) -> String:
	var parts: PackedStringArray = []
	var gold_short := gold_cost - _wallet.get_balance()
	if gold_short > 0:
		parts.append("%s gold" % InventoryMenuFormat.grouped(gold_short))
	for ingredient: TortugaIngredient in ingredients:
		var have := _inventory.count_item(StringName(ingredient.item.item_id))
		if have < ingredient.amount:
			parts.append("%d %s" % [ingredient.amount - have, ingredient.item.display_name])
	return "" if parts.is_empty() else "Missing " + ", ".join(parts)


func _fill_cost_grid(gold_cost: int, ingredients: Array[TortugaIngredient]) -> void:
	if gold_cost <= 0 and ingredients.is_empty():
		var free := Label.new()
		free.text = NO_COST_TEXT
		free.theme_type_variation = &"BodyLabel"
		_cost_grid.add_child(free)
		return
	if gold_cost > 0:
		_add_cost_chip(GOLD_ICON, "Gold", _wallet.get_balance(), gold_cost)
	for ingredient: TortugaIngredient in ingredients:
		_add_cost_chip(
			ingredient.item.icon,
			ingredient.item.display_name,
			_inventory.count_item(StringName(ingredient.item.item_id)),
			ingredient.amount
		)


func _add_cost_chip(texture: Texture2D, title: String, current: int, required: int) -> void:
	var chip := COST_SCENE.instantiate() as TortugaCostChip
	_cost_grid.add_child(chip)
	chip.set_cost(texture, title, current, required)


func _clear_cost_grid() -> void:
	for child in _cost_grid.get_children():
		_cost_grid.remove_child(child)
		child.queue_free()


func _on_action() -> void:
	if _selected_id.is_empty() or _service == null or _is_closing:
		return
	if not _pending_options.is_empty():
		return
	if _tab == Tab.CRAFT:
		var crafted_name := _selected_data().display_name
		var error := _service.craft(_selected_id)
		if error.is_empty():
			_set_feedback(
				SUCCESS_MARK + "%s crafted. Equip it from the Inventory." % crafted_name,
				success_color
			)
			_refresh()
			_play_strike(_big_icon)
		else:
			_set_feedback(REFUSAL_MARK + error, refusal_color)
			_refresh()
			InventoryMenuFx.shake(action)
		return
	var weapon := _owned_instance(_selected_id)
	var payment := _payment_text()
	_pending_options = _service.roll_forges(_selected_id)
	if _pending_options.size() == FORGE_OPTION_COUNT and weapon != null:
		_frame.hide()
		forge_popup.show_choices(weapon, _pending_options, payment)
		_play_strike()
		return
	_pending_options.clear()
	_set_feedback(REFUSAL_MARK + "Not enough gold or materials.", refusal_color)
	_refresh_details()
	InventoryMenuFx.shake(action)


func _choose_option(index: int) -> void:
	if index < 0 or index >= _pending_options.size() or _service == null:
		return
	var chosen := _pending_options[index]
	if not _service.apply_forge(_selected_id, chosen):
		forge_popup.show_notice("Could not apply that forge. Choose again.")
		forge_popup.allow_retry()
		return
	_pending_options.clear()
	forge_popup.close()
	_frame.show()
	_set_feedback(
		SUCCESS_MARK + "%s now carries %s." % [_selected_data().display_name, chosen.display_name],
		success_color
	)
	_refresh()
	_play_strike(_big_icon)
	_focus_default()


func _payment_text() -> String:
	var parts: PackedStringArray = [
		"%s gold" % InventoryMenuFormat.grouped(catalog.forge_gold_cost)
	]
	for ingredient: TortugaIngredient in catalog.forge_ingredients:
		parts.append("%d %s" % [ingredient.amount, ingredient.item.display_name])
	return ", ".join(parts)


func _on_balance_changed(_balance: int, _change: int) -> void:
	_refresh()


func _on_debug_supplies() -> void:
	if not OS.has_feature("debug") or _inventory == null or _wallet == null:
		return
	var items: Dictionary[String, BaseItem] = {}
	for recipe: TortugaRecipe in catalog.recipes:
		for ingredient: TortugaIngredient in recipe.ingredients:
			items[ingredient.item.item_id] = ingredient.item
	for ingredient: TortugaIngredient in catalog.forge_ingredients:
		items[ingredient.item.item_id] = ingredient.item
	for item: BaseItem in items.values():
		_inventory.add_item(item, debug_ingredient_amount)
	_wallet.add_gold(debug_gold_amount)
	_set_feedback("Debug supplies added.", hint_color)
	_refresh()


## What blocks the action now beats the last trade's result, which beats the idle hint.
func _show_hint(reason: String, hint: String) -> void:
	if not reason.is_empty():
		_action_hint.text = REFUSAL_MARK + reason
		_action_hint.add_theme_color_override("font_color", refusal_color)
	elif not _feedback_text.is_empty():
		_action_hint.text = _feedback_text
		_action_hint.add_theme_color_override("font_color", _feedback_color)
	else:
		_action_hint.text = hint
		_action_hint.add_theme_color_override("font_color", hint_color)
	_action_hint.tooltip_text = _action_hint.text


func _set_feedback(text: String, color: Color = Color.WHITE) -> void:
	_feedback_text = text
	_feedback_color = color


func _selected_data() -> WeaponData:
	for data: WeaponData in _entries:
		if data.weapon_id == _selected_id:
			return data
	return null


func _owned_instance(weapon_id: StringName) -> WeaponInstance:
	for weapon: WeaponInstance in _weapons.get_owned_weapons():
		if (
			weapon != null
			and weapon.definition != null
			and weapon.definition.weapon_id == weapon_id
		):
			return weapon
	return null


func _is_equipped(weapon_id: StringName) -> bool:
	var equipped := _weapons.equipped if _weapons != null else null
	return (
		equipped != null
		and equipped.definition != null
		and equipped.definition.weapon_id == weapon_id
	)


func _focus_default() -> void:
	if not visible:
		return
	var index := -1
	for entry_index in range(_entries.size()):
		if _entries[entry_index].weapon_id == _selected_id:
			index = entry_index
			break
	var target: Control = _slots[index] if index >= 0 and index < _slots.size() else _back_button
	target.grab_focus.call_deferred()


func _play_open_feedback() -> void:
	_kill_tween(_transition_tween)
	_set_ink_progress(INK_HIDDEN)
	_frame.modulate.a = 0.0
	_frame.scale = Vector2.ONE * closed_frame_scale
	_embers.emitting = true
	_embers.restart()
	_transition_tween = _make_tween()
	_transition_tween.set_parallel()
	var ink := _transition_tween.tween_method(
		_set_ink_progress, INK_HIDDEN, INK_SHOWN, ink_open_seconds
	)
	ink.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var fade := _transition_tween.tween_property(_frame, "modulate:a", 1.0, open_duration)
	fade.set_delay(frame_open_delay)
	var grow := _transition_tween.tween_property(_frame, "scale", Vector2.ONE, open_duration)
	grow.set_delay(frame_open_delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	InventoryMenuFx.stagger_in([craft_tab, forge_tab])
	InventoryMenuFx.stagger_in(_slots)
	InventoryMenuFx.pop(_big_icon, InventoryMenuFx.ICON_POP_FROM_SCALE, frame_open_delay)


func _slide_page_in(direction: int) -> void:
	_kill_tween(_page_tween)
	_page.position.x = page_slide_pixels * direction
	_page.modulate.a = 0.0
	_page_tween = _make_tween()
	_page_tween.set_parallel()
	_page_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_page_tween.tween_property(_page, "position:x", 0.0, page_switch_seconds)
	_page_tween.tween_property(_page, "modulate:a", 1.0, page_switch_seconds)
	InventoryMenuFx.stagger_in(_slots)


## Hammer strike: a short orange flash, plus sparks on `sparks_on` when it is on screen.
func _play_strike(sparks_on: Control = null) -> void:
	_kill_tween(_flash_tween)
	_strike_flash.modulate.a = strike_flash_alpha
	_flash_tween = _make_tween()
	_flash_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flash_tween.tween_property(_strike_flash, "modulate:a", 0.0, strike_flash_seconds)
	if sparks_on != null and sparks_on.is_visible_in_tree():
		InventoryMenuFx.burst(sparks_on)
		InventoryMenuFx.pop(sparks_on, InventoryMenuFx.BADGE_POP_FROM_SCALE)


func _finish_close() -> void:
	_is_closing = false
	_kill_tween(_transition_tween)
	_kill_tween(_page_tween)
	_kill_tween(_flash_tween)
	forge_popup.close()
	_frame.show()
	_frame.modulate.a = 1.0
	_frame.scale = Vector2.ONE
	_page.position = Vector2.ZERO
	_page.modulate.a = 1.0
	_strike_flash.modulate.a = 0.0
	_set_ink_progress(INK_SHOWN)
	hide()
	set_process(false)
	_embers.emitting = false
	if is_instance_valid(_inventory) and _inventory.changed.is_connected(_refresh):
		_inventory.changed.disconnect(_refresh)
	if is_instance_valid(_wallet) and _wallet.balance_changed.is_connected(_on_balance_changed):
		_wallet.balance_changed.disconnect(_on_balance_changed)
	if is_instance_valid(_weapons) and _weapons.collection_changed.is_connected(_refresh):
		_weapons.collection_changed.disconnect(_refresh)
	_pending_options.clear()
	_entries.clear()
	_service = null
	_player = null
	_inventory = null
	_wallet = null
	_weapons = null
	_set_feedback("")
	Input.mouse_mode = _previous_mouse_mode
	var manager := get_node_or_null("/root/GameManager")
	if manager != null:
		manager.exit_inventory()
	panel_closed.emit()


## Panel tweens keep running while the tree is paused and ignore hit-stop time scale.
func _make_tween() -> Tween:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_ignore_time_scale(true)
	return tween


func _kill_tween(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()


func _update_frame_pivot() -> void:
	_frame.pivot_offset = _frame.size * CENTER_RATIO


func _set_ink_progress(progress: float) -> void:
	(_background.material as ShaderMaterial).set_shader_parameter(INK_PROGRESS_PARAM, progress)


func _ink_progress() -> float:
	var material := _background.material as ShaderMaterial
	return float(material.get_shader_parameter(INK_PROGRESS_PARAM))
