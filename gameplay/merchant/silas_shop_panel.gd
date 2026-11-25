class_name SilasShopPanel
extends CanvasLayer
## Silas's black-market stall, built on the pause Inventory's visual system.
##
## Buy lists the session stock catalog handed in by SilasNpc; Sell lists the player's carried
## goods, one entry per item. Every trade goes through MerchantTransactionService, so this panel
## only reads Inventory, GoldWallet and WeaponController to explain prices and limits.

signal shop_closed
signal stock_reroll_requested

enum Tab { BUY, SELL }

const SLOT_SCENE: PackedScene = preload("res://gameplay/merchant/silas_shop_slot.tscn")
## Matches the per-trade limit enforced by MerchantTransactionService.
const MAX_TRADE_QUANTITY := 99
const MIN_TRADE_QUANTITY := 1
const PREVIOUS_TAB_ACTION := &"ui_page_up"
const NEXT_TAB_ACTION := &"ui_page_down"
const CANCEL_ACTION := &"ui_cancel"
const INK_PROGRESS_PARAM := &"progress"
const INK_HIDDEN := 0.0
const INK_SHOWN := 1.0
const CENTER_RATIO := 0.5
const MSEC_PER_SECOND := 1000.0
## The purse row fits the coin plus about seven digits at full size; larger balances shrink.
const PURSE_TEXT_WIDTH_PIXELS := 164.0
const GOLD_FONT_SIZE := 32
const GOLD_MIN_FONT_SIZE := 16
const SUCCESS_MARK := "✓ "
const REFUSAL_MARK := "✕ "
const SECTION_TITLES := {Tab.BUY: "Under the counter", Tab.SELL: "Your goods"}
const FOOTNOTES := {
	Tab.BUY: "Stock stays the same for this play session.",
	Tab.SELL: 'Goods marked "No deal" are not for Silas.',
}
const EMPTY_TEXTS := {
	Tab.BUY: "Silas has nothing on offer right now.",
	Tab.SELL: "Your bag is empty. Silas has nothing to haggle over.",
}

@export_range(1, 8, 1) var grid_columns: int = 4
@export_multiline var buy_whisper: String = '"No names, no questions,\nno refunds."'
@export_multiline var sell_whisper: String = '"Let\'s see what fell\noff the boat..."'

@export_group("Feedback Colors")
@export var success_color: Color = Color(0.66, 0.85, 0.58)
@export var refusal_color: Color = Color(0.95, 0.56, 0.5)
@export var hint_color: Color = Color(0.77, 0.61, 0.53)
@export var unaffordable_total_color: Color = Color(0.95, 0.47, 0.44)
@export var total_color: Color = Color(0.98, 0.93, 0.86)

@export_group("Interaction Feedback")
@export_range(0.05, 0.6, 0.01, "suffix:s") var open_duration: float = 0.3
@export_range(0.05, 0.5, 0.01, "suffix:s") var close_duration: float = 0.2
@export_range(0.5, 1.0, 0.01) var closed_frame_scale: float = 0.94
@export_range(0.1, 1.5, 0.01, "suffix:s") var ink_open_seconds: float = 0.6
@export_range(0.05, 1.0, 0.01, "suffix:s") var ink_close_seconds: float = 0.3
@export_range(0.0, 0.4, 0.01, "suffix:s") var frame_open_delay: float = 0.12
@export_range(0.0, 120.0, 1.0, "suffix:px") var page_slide_pixels: float = 36.0
@export_range(0.05, 0.6, 0.01, "suffix:s") var page_switch_seconds: float = 0.22
@export_range(1.0, 1.3, 0.01) var back_button_lift: float = 1.08
## Ignores a second press this soon after a trade so a double click cannot repeat it.
@export_range(0.0, 1.0, 0.01, "suffix:s") var trade_repeat_guard_seconds: float = 0.18
@export_range(0.05, 1.0, 0.01, "suffix:s") var gold_count_seconds: float = 0.35

@export_group("Lantern")
@export_range(0.0, 1.0, 0.01) var lantern_glow_min_alpha: float = 0.55
@export_range(0.0, 1.0, 0.01) var lantern_glow_max_alpha: float = 0.9
@export_range(0.1, 10.0, 0.1, "suffix:Hz") var lantern_flicker_hz: float = 1.7

var _catalog: MerchantCatalog
var _service: MerchantTransactionService
var _player: Player
var _inventory: Inventory
var _wallet: GoldWallet
var _current_tab: Tab = Tab.BUY
var _selected_offer_id: StringName = &""
var _selected_item_id: String = ""
var _quantity: int = MIN_TRADE_QUANTITY
var _sell_entries: Array[SellEntry] = []
var _slot_uis: Array[SilasShopSlot] = []
var _feedback_text: String = ""
var _feedback_color: Color = Color.WHITE
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _is_closing: bool = false
var _next_trade_msec: int = 0
var _shown_gold: int = 0
var _lantern_time: float = 0.0
var _transition_tween: Tween
var _page_tween: Tween
var _gold_tween: Tween

@onready var gold_label: Label = %GoldLabel
## Public tab references stay plain buttons; the Inventory tab look is an implementation detail.
@onready var buy_tab: BaseButton = %BuyTab
@onready var sell_tab: BaseButton = %SellTab
@onready var item_scroll: ScrollContainer = %GridScroll
@onready var grid: GridContainer = %Grid
@onready var action_button: Button = %ActionButton
@onready var reroll_button: Button = %DebugReroll
@onready var toast_queue: TradeToastQueue = %TradeToastQueue
@onready var _background: TextureRect = %Background
@onready var _frame: Control = %Frame
@onready var _page: Control = %Page
@onready var _motes: CPUParticles2D = %Motes
@onready var _lantern_glow: CanvasItem = %LanternGlow
@onready var _whisper: Label = %Whisper
@onready var _purse_coin: Control = %PurseCoin
@onready var _section_title: Label = %SectionTitle
@onready var _footnote: Label = %Footnote
@onready var _counter_label: Label = %CounterLabel
@onready var _empty_label: Label = %EmptyLabel
@onready var _big_icon: TextureRect = %BigIcon
@onready var _item_name: Label = %ItemName
@onready var _type_banner: Label = %TypeBanner
@onready var _owned_banner: Label = %OwnedBanner
@onready var _description: Label = %Description
@onready var _description_scroll: ScrollContainer = %DescriptionScroll
@onready var _effect_label: Label = %EffectLabel
@onready var _trade_row: Control = %TradeRow
@onready var _quantity_box: Control = %QuantityBox
@onready var _minus_button: Button = %MinusButton
@onready var _plus_button: Button = %PlusButton
@onready var _quantity_label: Label = %QuantityLabel
@onready var _total_label: Label = %TotalLabel
@onready var _unit_label: Label = %UnitLabel
@onready var _feedback: Label = %Feedback
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	set_process(false)
	grid.columns = grid_columns
	buy_tab.pressed.connect(_set_tab.bind(Tab.BUY))
	sell_tab.pressed.connect(_set_tab.bind(Tab.SELL))
	_minus_button.pressed.connect(_change_quantity.bind(-1))
	_plus_button.pressed.connect(_change_quantity.bind(1))
	action_button.pressed.connect(_on_action_pressed)
	_back_button.pressed.connect(close_shop)
	_back_button.tooltip_text = "Leave (%s)" % InventoryMenuFormat.action_key(CANCEL_ACTION)
	reroll_button.visible = OS.has_feature("debug")
	reroll_button.pressed.connect(_on_debug_reroll_pressed)
	for button: Button in [_minus_button, _plus_button, action_button]:
		InventoryHoverFeedback.attach(button)
	InventoryHoverFeedback.attach(_back_button, null, back_button_lift)
	_frame.resized.connect(_update_frame_pivot)
	_update_frame_pivot()


func _process(delta: float) -> void:
	# A slow, uneven flicker: two sines at unrelated rates read as a flame, not a pulse.
	_lantern_time += delta
	var phase := _lantern_time * lantern_flicker_hz * TAU
	var flicker := 0.5 + 0.35 * sin(phase) + 0.15 * sin(phase * 2.7 + 1.3)
	_lantern_glow.modulate.a = lerpf(lantern_glow_min_alpha, lantern_glow_max_alpha, flicker)


func _input(event: InputEvent) -> void:
	if not visible or _is_closing:
		return
	if event.is_action_pressed(CANCEL_ACTION):
		close_shop()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(PREVIOUS_TAB_ACTION) or event.is_action_pressed(NEXT_TAB_ACTION):
		_set_tab(Tab.SELL if _current_tab == Tab.BUY else Tab.BUY)
		_focus_default()
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	_kill_tween(_transition_tween)
	_kill_tween(_page_tween)
	_kill_tween(_gold_tween)
	_disconnect_observers()
	if visible:
		Input.mouse_mode = _previous_mouse_mode
		var manager := get_node_or_null("/root/GameManager")
		if manager != null:
			manager.exit_inventory()


func open_for(player: Player, catalog: MerchantCatalog) -> bool:
	if player == null or catalog == null or not catalog.validate().is_empty() or _is_closing:
		return false
	if visible:
		return false
	var manager := get_node_or_null("/root/GameManager")
	if manager == null or not manager.enter_inventory():
		return false
	var inventory := player.get_node_or_null("Inventory") as Inventory
	var wallet := manager.get("gold_wallet") as GoldWallet
	if inventory == null or wallet == null:
		manager.exit_inventory()
		return false

	_player = player
	_inventory = inventory
	_catalog = catalog
	_service = MerchantTransactionService.new(_catalog)
	_wallet = wallet
	_connect_observers()
	_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_selected_offer_id = &""
	_selected_item_id = ""
	_quantity = MIN_TRADE_QUANTITY
	_next_trade_msec = 0
	_set_feedback("")
	_show_gold(_wallet.get_balance(), false)
	toast_queue.clear()
	show()
	set_process(true)
	_current_tab = Tab.BUY
	_refresh_tabs(false)
	_refresh()
	_play_open_feedback()
	_focus_default()
	return true


func close_shop() -> void:
	if not visible or _is_closing:
		return
	_is_closing = true
	_kill_tween(_transition_tween)
	_motes.emitting = false
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


## Replaces the open Buy stock (debug reroll). The selection survives if the offer remains.
func update_stock(stock: MerchantCatalog) -> void:
	if not visible or stock == null or not stock.validate().is_empty():
		return
	_catalog = stock
	_service = MerchantTransactionService.new(stock)
	_quantity = MIN_TRADE_QUANTITY
	_set_feedback("")
	_set_tab(Tab.BUY)


func _on_debug_reroll_pressed() -> void:
	if OS.has_feature("debug"):
		stock_reroll_requested.emit()


func _set_tab(tab: Tab) -> void:
	if _catalog == null or _inventory == null:
		return
	var changed := tab != _current_tab
	_current_tab = tab
	_quantity = MIN_TRADE_QUANTITY
	_set_feedback("")
	_refresh_tabs(changed and visible and not _is_closing)
	_refresh()
	if changed and visible and not _is_closing:
		_slide_page_in(1 if tab == Tab.SELL else -1)


func _refresh_tabs(animate: bool) -> void:
	(buy_tab as InventoryMenuTabButton).set_active(_current_tab == Tab.BUY, animate)
	(sell_tab as InventoryMenuTabButton).set_active(_current_tab == Tab.SELL, animate)
	_whisper.text = buy_whisper if _current_tab == Tab.BUY else sell_whisper
	_section_title.text = SECTION_TITLES[_current_tab]
	_footnote.text = FOOTNOTES[_current_tab]
	if animate:
		InventoryMenuFx.burst(buy_tab if _current_tab == Tab.BUY else sell_tab)


func _refresh() -> void:
	if _catalog == null or _inventory == null or _wallet == null:
		return
	# Gold is set on open and animated by balance_changed; refreshing must not cut that short.
	_counter_label.text = "%d/%d" % [_used_bag_slots(), _inventory.slots.size()]
	_rebuild_grid()
	_refresh_details()


func _rebuild_grid() -> void:
	var focus_owner := get_viewport().gui_get_focus_owner()
	var had_grid_focus := focus_owner != null and grid.is_ancestor_of(focus_owner)
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	_slot_uis.clear()

	if _current_tab == Tab.BUY:
		var offers := _catalog.get_buy_offers()
		if _find_buy_offer(_selected_offer_id) == null:
			_selected_offer_id = offers[0].offer_id if not offers.is_empty() else &""
		for offer: MerchantOffer in offers:
			var slot := _add_slot()
			slot.present(offer.get_icon(), offer.trade_amount, offer.buy_price, _buy_state(offer))
			slot.tooltip_text = _buy_tooltip(offer)
			slot.pressed.connect(_select_buy_offer.bind(offer.offer_id))
	else:
		_collect_sell_entries()
		if _find_sell_entry(_selected_item_id) == null:
			_selected_item_id = (
				_sell_entries[0].item.item_id if not _sell_entries.is_empty() else ""
			)
		for entry: SellEntry in _sell_entries:
			var slot := _add_slot()
			var price := entry.offer.sell_price if entry.offer != null else 0
			var state := (
				SilasShopSlot.PriceState.NORMAL
				if entry.offer != null
				else SilasShopSlot.PriceState.REFUSED
			)
			slot.present(entry.item.icon, entry.count, price, state)
			slot.tooltip_text = (
				"%s  ·  %d carried" % [entry.item.display_name, entry.count]
				if entry.offer != null
				else "%s  ·  Silas won't buy this." % entry.item.display_name
			)
			slot.pressed.connect(_select_sell_item.bind(entry.item.item_id))
	_empty_label.text = EMPTY_TEXTS[_current_tab]
	_empty_label.visible = _slot_uis.is_empty()
	_update_slot_selection()
	if had_grid_focus:
		_focus_default()


func _add_slot() -> SilasShopSlot:
	var slot := SLOT_SCENE.instantiate() as SilasShopSlot
	grid.add_child(slot)
	_slot_uis.append(slot)
	return slot


## One entry per carried item, sellable goods first, so a sale never shifts another index.
func _collect_sell_entries() -> void:
	_sell_entries.clear()
	var refused: Array[SellEntry] = []
	var seen: Dictionary[String, bool] = {}
	for slot: InventorySlot in _inventory.slots:
		if slot == null or slot.is_empty() or seen.has(slot.item.item_id):
			continue
		seen[slot.item.item_id] = true
		var entry := SellEntry.new()
		entry.item = slot.item
		entry.count = _inventory.count_item(StringName(slot.item.item_id))
		entry.offer = _catalog.get_sell_offer_for_item(StringName(slot.item.item_id))
		if entry.offer != null:
			_sell_entries.append(entry)
		else:
			refused.append(entry)
	_sell_entries.append_array(refused)


func _select_buy_offer(offer_id: StringName) -> void:
	if offer_id == _selected_offer_id:
		return
	_selected_offer_id = offer_id
	_on_selection_changed()


func _select_sell_item(item_id: String) -> void:
	if item_id == _selected_item_id:
		return
	_selected_item_id = item_id
	_on_selection_changed()


func _on_selection_changed() -> void:
	_quantity = MIN_TRADE_QUANTITY
	_set_feedback("")
	_update_slot_selection()
	_refresh_details()
	InventoryMenuFx.pop(_big_icon, InventoryMenuFx.ICON_POP_FROM_SCALE)


func _update_slot_selection() -> void:
	for index in range(_slot_uis.size()):
		var selected := false
		if _current_tab == Tab.BUY:
			var offers := _catalog.get_buy_offers()
			selected = index < offers.size() and offers[index].offer_id == _selected_offer_id
		else:
			selected = (
				index < _sell_entries.size()
				and _sell_entries[index].item.item_id == _selected_item_id
			)
		_slot_uis[index].set_selected(selected)


func _refresh_details() -> void:
	if _current_tab == Tab.BUY:
		var offer := _find_buy_offer(_selected_offer_id)
		if offer != null:
			_show_buy_details(offer)
			return
	else:
		var entry := _find_sell_entry(_selected_item_id)
		if entry != null:
			_show_sell_details(entry)
			return
	_show_empty_details()


func _show_buy_details(offer: MerchantOffer) -> void:
	var is_weapon := offer.kind == MerchantOffer.Kind.WEAPON
	var unique_purchase := offer.is_unique_purchase()
	_big_icon.texture = offer.get_icon()
	_set_name(offer.get_display_name())
	_type_banner.text = "Weapon" if is_weapon else _item_category(offer.item)
	var owned := _owned_amount(offer)
	if unique_purchase:
		_owned_banner.text = "Owned" if owned > 0 else "Not owned"
	else:
		_owned_banner.text = "Have %d" % owned
	_set_description(offer.weapon.description if is_weapon else _item_description(offer.item))
	_set_effect(_offer_effect(offer))

	var maximum := MIN_TRADE_QUANTITY if unique_purchase else _max_buy_quantity(offer)
	_quantity = clampi(_quantity, MIN_TRADE_QUANTITY, maxi(MIN_TRADE_QUANTITY, maximum))
	_trade_row.show()
	_quantity_box.visible = not unique_purchase
	_update_quantity_buttons(maximum)
	var total := offer.buy_price * _quantity
	_total_label.text = InventoryMenuFormat.grouped(total)
	_unit_label.text = _unit_text(offer.buy_price, offer.trade_amount)
	_total_label.add_theme_color_override(
		"font_color", unaffordable_total_color if not _wallet.can_afford(total) else total_color
	)
	action_button.show()
	if unique_purchase and owned > 0:
		# Owning it is a state, not a refusal: keep any purchase message visible.
		action_button.text = "Owned"
		action_button.disabled = true
		_show_hint("", "Already yours. Equip it from the Inventory.")
		return
	var reason := _buy_block_reason(offer)
	action_button.text = "Buy"
	action_button.disabled = not reason.is_empty()
	_show_hint(reason, _receive_text(offer))


func _show_sell_details(entry: SellEntry) -> void:
	_big_icon.texture = entry.item.icon
	_set_name(entry.item.display_name)
	_type_banner.text = _item_category(entry.item)
	_owned_banner.text = "Have %d" % entry.count
	_set_description(_item_description(entry.item))
	_set_effect(_item_effect(entry.item))
	if entry.offer == null:
		_trade_row.hide()
		action_button.show()
		action_button.text = "No deal"
		action_button.disabled = true
		_show_hint("Silas won't touch this.", "")
		return
	var bundles := floori(float(entry.count) / float(entry.offer.trade_amount))
	var maximum := mini(MAX_TRADE_QUANTITY, bundles)
	_quantity = clampi(_quantity, MIN_TRADE_QUANTITY, maxi(MIN_TRADE_QUANTITY, maximum))
	_trade_row.show()
	_quantity_box.show()
	_update_quantity_buttons(maximum)
	_total_label.text = "+" + InventoryMenuFormat.grouped(entry.offer.sell_price * _quantity)
	_total_label.add_theme_color_override("font_color", total_color)
	_unit_label.text = _unit_text(entry.offer.sell_price, entry.offer.trade_amount)
	action_button.show()
	action_button.text = "Sell"
	var reason := _sell_block_reason(entry, bundles)
	action_button.disabled = not reason.is_empty()
	_show_hint(
		reason, "Hand over %d %s." % [entry.offer.trade_amount * _quantity, entry.item.display_name]
	)


func _show_empty_details() -> void:
	_big_icon.texture = null
	_set_name("Nothing selected")
	_type_banner.text = ""
	_owned_banner.text = ""
	_set_description(
		"Pick a ware to see its price." if _current_tab == Tab.BUY else "Pick something to sell."
	)
	_set_effect("")
	_trade_row.hide()
	action_button.hide()
	_show_hint("", "")


func _set_name(text: String) -> void:
	_item_name.text = text
	_item_name.tooltip_text = text


## The effect line shares the description's scroll area and takes no room when empty.
func _set_effect(text: String) -> void:
	_effect_label.text = text
	_effect_label.visible = not text.is_empty()


func _set_description(text: String) -> void:
	var clean := text.strip_edges()
	_description.text = clean if not clean.is_empty() else "No description."
	_description_scroll.scroll_vertical = 0


## What blocks the action now beats the last trade's result, which beats the idle hint.
func _show_hint(reason: String, hint: String) -> void:
	if not reason.is_empty():
		_feedback.text = REFUSAL_MARK + reason
		_feedback.add_theme_color_override("font_color", refusal_color)
	elif not _feedback_text.is_empty():
		_feedback.text = _feedback_text
		_feedback.add_theme_color_override("font_color", _feedback_color)
	else:
		_feedback.text = hint
		_feedback.add_theme_color_override("font_color", hint_color)
	_feedback.tooltip_text = _feedback.text


func _set_feedback(text: String, color: Color = Color.WHITE) -> void:
	_feedback_text = text
	_feedback_color = color


func _update_quantity_buttons(maximum: int) -> void:
	_quantity_label.text = str(_quantity)
	_minus_button.disabled = _quantity <= MIN_TRADE_QUANTITY
	_plus_button.disabled = _quantity >= maximum
	_plus_button.tooltip_text = (
		"That's as many as you can trade right now." if _plus_button.disabled else "Trade one more"
	)


func _change_quantity(change: int) -> void:
	_quantity = clampi(_quantity + change, MIN_TRADE_QUANTITY, MAX_TRADE_QUANTITY)
	_set_feedback("")
	_refresh_details()


## Largest quantity the wallet and the bag can take, capped by the service limit; at least 1
## so the panel can still explain why one bundle is out of reach.
func _max_buy_quantity(offer: MerchantOffer) -> int:
	if offer.buy_price <= 0 or offer.item == null:
		return MIN_TRADE_QUANTITY
	var affordable := floori(float(_wallet.get_balance()) / float(offer.buy_price))
	var room := floori(
		float(_inventory.get_available_space(offer.item)) / float(offer.trade_amount)
	)
	return clampi(mini(affordable, room), MIN_TRADE_QUANTITY, MAX_TRADE_QUANTITY)


func _buy_block_reason(offer: MerchantOffer) -> String:
	if (
		not offer.is_unique_purchase()
		and not _inventory.can_add_item(offer.item, offer.trade_amount * _quantity)
	):
		return _no_room_reason(offer.item)
	var price := offer.buy_price * _quantity
	if not _wallet.can_afford(price):
		return "Need %s more gold." % InventoryMenuFormat.grouped(price - _wallet.get_balance())
	return ""


func _no_room_reason(item: BaseItem) -> String:
	if item is Potion:
		var kind := (item as Potion).potion_kind
		var limit := _inventory.get_potion_capacity(kind)
		if _inventory.count_potions(kind) >= limit:
			return "Your potion pouch is full (%d/%d)." % [limit, limit]
	return "Your bag has no room for that."


func _sell_block_reason(entry: SellEntry, bundles: int) -> String:
	if bundles < MIN_TRADE_QUANTITY:
		return "Silas buys these %d at a time." % entry.offer.trade_amount
	var price := entry.offer.sell_price * _quantity
	if _wallet.get_balance() > GoldWallet.MAX_GOLD - price:
		return "Your gold pouch is full."
	return ""


func _on_action_pressed() -> void:
	if _service == null or _player == null or _inventory == null or _is_closing:
		return
	if Time.get_ticks_msec() < _next_trade_msec:
		return
	_next_trade_msec = Time.get_ticks_msec() + int(trade_repeat_guard_seconds * MSEC_PER_SECOND)
	var quantity := _quantity
	if _current_tab == Tab.BUY:
		var offer := _find_buy_offer(_selected_offer_id)
		if offer == null:
			return
		var result := _service.purchase(
			offer.offer_id,
			_inventory,
			_wallet,
			_player.weapon_controller,
			quantity,
			_player.charm_registry
		)
		if result == MerchantTransactionService.Result.SUCCESS and offer.offer_id == &"bow":
			var progress := get_node_or_null("/root/SilasProgress") as SilasProgressStore
			if progress != null:
				progress.mark_bow_purchased()
		_finish_trade(result, offer, true, quantity)
		return
	var entry := _find_sell_entry(_selected_item_id)
	if entry == null or entry.offer == null:
		return
	var sold := _service.sell(entry.offer.offer_id, _inventory, _wallet, quantity)
	_finish_trade(sold, entry.offer, false, quantity)


func _finish_trade(
	result: MerchantTransactionService.Result,
	offer: MerchantOffer,
	was_purchase: bool,
	quantity: int
) -> void:
	_quantity = MIN_TRADE_QUANTITY
	if result != MerchantTransactionService.Result.SUCCESS:
		_set_feedback(REFUSAL_MARK + _service.get_result_message(result), refusal_color)
		_refresh()
		InventoryMenuFx.shake(action_button)
		return
	var amount := offer.trade_amount * quantity
	var gold := (offer.buy_price if was_purchase else offer.sell_price) * quantity
	_set_feedback(
		(
			SUCCESS_MARK
			+ ("Bought" if was_purchase else "Sold")
			+ " %d %s." % [amount, offer.get_display_name()]
		),
		success_color
	)
	(
		toast_queue
		. enqueue_success(
			(
				"%s x%d %s  %s%s G"
				% [
					"Purchased" if was_purchase else "Sold",
					amount,
					offer.get_display_name(),
					"-" if was_purchase else "+",
					InventoryMenuFormat.grouped(gold),
				]
			)
		)
	)
	_refresh()
	InventoryMenuFx.burst(_big_icon)
	InventoryMenuFx.pop(_purse_coin, InventoryMenuFx.BADGE_POP_FROM_SCALE)


func _find_buy_offer(offer_id: StringName) -> MerchantOffer:
	if _catalog == null or offer_id.is_empty():
		return null
	for offer: MerchantOffer in _catalog.get_buy_offers():
		if offer.offer_id == offer_id:
			return offer
	return null


func _find_sell_entry(item_id: String) -> SellEntry:
	for entry: SellEntry in _sell_entries:
		if entry.item.item_id == item_id:
			return entry
	return null


func _buy_state(offer: MerchantOffer) -> SilasShopSlot.PriceState:
	if offer.is_unique_purchase() and _owned_amount(offer) > 0:
		return SilasShopSlot.PriceState.OWNED
	if not _wallet.can_afford(offer.buy_price):
		return SilasShopSlot.PriceState.UNAFFORDABLE
	return SilasShopSlot.PriceState.NORMAL


func _buy_tooltip(offer: MerchantOffer) -> String:
	var text := offer.get_display_name()
	if offer.trade_amount > 1:
		text += "  ·  bundle of %d" % offer.trade_amount
	match _buy_state(offer):
		SilasShopSlot.PriceState.OWNED:
			text += "  ·  already owned"
		SilasShopSlot.PriceState.UNAFFORDABLE:
			text += "  ·  not enough gold"
	return text


func _receive_text(offer: MerchantOffer) -> String:
	if offer.kind == MerchantOffer.Kind.WEAPON:
		return "Goes to your weapons. Equip it from the Inventory."
	if offer.item.charm != null:
		return "Equip it from the Charms tab."
	return "You receive %d %s." % [offer.trade_amount * _quantity, offer.get_display_name()]


func _unit_text(price: int, trade_amount: int) -> String:
	if trade_amount > 1:
		return "%s G per %d" % [InventoryMenuFormat.grouped(price), trade_amount]
	return "%s G each" % InventoryMenuFormat.grouped(price)


func _owned_amount(offer: MerchantOffer) -> int:
	if offer.kind == MerchantOffer.Kind.WEAPON:
		var weapons := _player.weapon_controller if _player != null else null
		return 1 if weapons != null and weapons.is_weapon_owned(offer.weapon.weapon_id) else 0
	if offer.item.charm != null:
		return int(_player.charm_registry.is_owned(offer.item.charm.charm_id))
	return _inventory.count_item(StringName(offer.item.item_id))


func _used_bag_slots() -> int:
	var used := 0
	for slot: InventorySlot in _inventory.slots:
		if slot != null and not slot.is_empty():
			used += 1
	return used


## Arrows have no ItemType of their own; any attack that spends the item makes it ammunition.
func _item_category(item: BaseItem) -> String:
	if item == null:
		return ""
	if item.charm != null:
		return "Charm"
	if _is_ammunition(item):
		return "Ammunition"
	match item.type:
		GlobalConstants.ItemType.CONSUMABLE:
			return "Consumable"
		GlobalConstants.ItemType.EQUIPMENT:
			return "Equipment"
		GlobalConstants.ItemType.QUEST:
			return "Quest Item"
	return "Material"


func _is_ammunition(item: BaseItem) -> bool:
	var weapons := _player.weapon_controller if _player != null else null
	if weapons == null:
		return false
	for entry: WeaponCollectionEntry in weapons.collection:
		if entry == null or entry.definition == null:
			continue
		for attack: AttackData in [
			entry.definition.normal_attack, entry.definition.secondary_attack
		]:
			if attack != null and String(attack.ammo_id) == item.item_id:
				return true
	return false


## A charm item's own text is a generic "Unlocks the X Charm"; what the charm does lives on
## its CharmData, which is what a buyer needs to see.
func _item_description(item: BaseItem) -> String:
	if item.charm != null and not item.charm.description.strip_edges().is_empty():
		return item.charm.description
	return item.description


func _charm_effect(charm: CharmData) -> String:
	if charm.is_passive():
		return "✦ Passive charm: works while equipped"
	var effect := "✦ Active charm  ·  %s SP" % InventoryMenuFormat.number(charm.resource_cost)
	if charm.cooldown_seconds > 0.0:
		effect += "  ·  %s s cooldown" % InventoryMenuFormat.number(charm.cooldown_seconds)
	return effect


func _item_effect(item: BaseItem) -> String:
	if item.charm != null:
		return _charm_effect(item.charm)
	if item is DualEssencePotion:
		var dual := item as DualEssencePotion
		return (
			"✦ Restores %s HP and %s stamina"
			% [
				InventoryMenuFormat.number(dual.heal_amount),
				InventoryMenuFormat.number(dual.stamina_amount),
			]
		)
	if item is HealingPotion:
		return "✦ Restores %s HP" % InventoryMenuFormat.number((item as HealingPotion).heal_amount)
	if item is StaminaPotion:
		return (
			"✦ Restores %s stamina"
			% InventoryMenuFormat.number((item as StaminaPotion).restore_amount)
		)
	if _is_ammunition(item):
		return "✦ Spent by weapon attacks"
	if item.type == GlobalConstants.ItemType.MATERIAL:
		return "✦ Crafting and forging material"
	return ""


func _offer_effect(offer: MerchantOffer) -> String:
	if offer.kind == MerchantOffer.Kind.WEAPON:
		return (
			"✦ Stagger %s  ·  Chaos +%s per hit"
			% [
				InventoryMenuFormat.number(offer.weapon.stagger_damage),
				InventoryMenuFormat.number(offer.weapon.chaos_per_hit),
			]
		)
	return _item_effect(offer.item)


func _show_gold(balance: int, animate: bool) -> void:
	_kill_tween(_gold_tween)
	gold_label.tooltip_text = "%s gold" % InventoryMenuFormat.grouped(balance)
	if not animate or not visible:
		_shown_gold = balance
		_set_gold_text(balance)
		return
	_gold_tween = _make_tween()
	_gold_tween.tween_method(_set_shown_gold, _shown_gold, balance, gold_count_seconds)


func _set_shown_gold(value: int) -> void:
	_shown_gold = value
	_set_gold_text(value)


func _set_gold_text(value: int) -> void:
	gold_label.text = InventoryMenuFormat.grouped(value)
	InventoryMenuFormat.fit_font_size(
		gold_label, PURSE_TEXT_WIDTH_PIXELS, GOLD_FONT_SIZE, GOLD_MIN_FONT_SIZE
	)


func _connect_observers() -> void:
	if _wallet != null and not _wallet.balance_changed.is_connected(_on_wallet_changed):
		_wallet.balance_changed.connect(_on_wallet_changed)
	if _inventory != null and not _inventory.changed.is_connected(_on_inventory_changed):
		_inventory.changed.connect(_on_inventory_changed)


func _disconnect_observers() -> void:
	if is_instance_valid(_wallet) and _wallet.balance_changed.is_connected(_on_wallet_changed):
		_wallet.balance_changed.disconnect(_on_wallet_changed)
	if is_instance_valid(_inventory) and _inventory.changed.is_connected(_on_inventory_changed):
		_inventory.changed.disconnect(_on_inventory_changed)


func _on_wallet_changed(balance: int, _change: int) -> void:
	if not visible:
		return
	_show_gold(balance, true)
	# Affordability marks on the grid and the action depend on the balance.
	_rebuild_grid()
	_refresh_details()


func _on_inventory_changed() -> void:
	if visible:
		_refresh()


func _focus_default() -> void:
	if not visible:
		return
	var index := -1
	for slot_index in range(_slot_uis.size()):
		if _slot_uis[slot_index].is_selected():
			index = slot_index
			break
	var target: Control = _slot_uis[index] if index >= 0 else _back_button
	target.grab_focus()


func _play_open_feedback() -> void:
	_kill_tween(_transition_tween)
	_set_ink_progress(INK_HIDDEN)
	_frame.modulate.a = 0.0
	_frame.scale = Vector2.ONE * closed_frame_scale
	_motes.emitting = true
	_motes.restart()
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
	InventoryMenuFx.stagger_in([buy_tab, sell_tab])
	InventoryMenuFx.stagger_in(_slot_uis)
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
	InventoryMenuFx.stagger_in(_slot_uis)


func _finish_close() -> void:
	_is_closing = false
	hide()
	set_process(false)
	toast_queue.clear()
	_kill_tween(_page_tween)
	_kill_tween(_gold_tween)
	_page.position = Vector2.ZERO
	_page.modulate.a = 1.0
	_frame.modulate.a = 1.0
	_frame.scale = Vector2.ONE
	_set_ink_progress(INK_SHOWN)
	Input.mouse_mode = _previous_mouse_mode
	_disconnect_observers()
	var manager := get_node_or_null("/root/GameManager")
	if manager != null:
		manager.exit_inventory()
	_player = null
	_inventory = null
	_catalog = null
	_service = null
	_wallet = null
	_sell_entries.clear()
	_selected_offer_id = &""
	_selected_item_id = ""
	_quantity = MIN_TRADE_QUANTITY
	_set_feedback("")
	shop_closed.emit()


## Shop tweens keep running while the tree is paused and ignore hit-stop time scale.
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


## A carried item as shown on the Sell tab: its total count and Silas's offer, if any.
class SellEntry:
	extends RefCounted

	var item: BaseItem
	var count: int = 0
	var offer: MerchantOffer
