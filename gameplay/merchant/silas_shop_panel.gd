class_name SilasShopPanel
extends CanvasLayer

## Silas's shop follows its own parchment artwork while sharing the inventory book.
signal shop_closed
signal stock_reroll_requested

enum Tab { BUY, SELL }

const SLOT_SCENE: PackedScene = preload("res://gameplay/merchant/silas_shop_slot.tscn")
const TAB_ACTIVE: Texture2D = preload("res://assets/ui/silas_shop/PNG/32_tab_active_blank.png")
const TAB_INACTIVE: Texture2D = preload("res://assets/ui/silas_shop/PNG/33_tab_inactive_blank.png")
const MAX_STACK_QUANTITY := 99
const MIN_TRADE_QUANTITY := 1

@export_group("Interaction Feedback")
@export_range(1, 8, 1) var grid_columns := 4
@export var grid_step := Vector2(86.0, 98.0)
@export_range(100.0, 1000.0, 1.0) var grid_content_width := 414.0
@export_range(1, 8, 1) var minimum_grid_rows := 2
@export var scrollbar_tint := Color(0.6, 0.37, 0.2, 0.85)
@export var reference_viewport_size := Vector2(1160.0, 700.0)
@export_range(0.5, 1.0, 0.01) var minimum_book_scale := 0.96
@export_range(0.05, 0.5, 0.01) var open_duration := 0.18
@export_range(0.05, 0.5, 0.01) var close_duration := 0.12
@export var selected_tab_scale := Vector2(1.04, 1.02)
@export_range(0.05, 0.3, 0.01) var tab_feedback_duration := 0.12
@export_range(1.0, 1.2, 0.01) var tab_click_punch_scale := 1.04
@export_range(0.1, 1.0, 0.05) var tab_click_punch_duration_ratio := 0.6
@export_range(0.0, 1.0, 0.01) var disabled_action_alpha := 0.55
@export var selected_tab_text_color := Color(1.0, 0.9, 0.7)
@export var idle_tab_text_color := Color(0.28, 0.1, 0.07)
@export var selected_tab_tint := Color.WHITE
@export var idle_tab_tint := Color(0.96, 0.94, 0.9)

var _catalog: MerchantCatalog
var _service: MerchantTransactionService
var _player: Player
var _inventory: Inventory
var _wallet: GoldWallet
var _selected_offer: MerchantOffer
var _selected_inventory_index := -1
var _current_tab := Tab.BUY
var _quantity := MIN_TRADE_QUANTITY
var _previous_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _slot_uis: Array[SilasShopSlot] = []
var _slot_inventory_indices: Array[int] = []
var _transition_tween: Tween
var _tab_tweens: Dictionary[TextureButton, Tween] = {}
var _tab_base_scales: Dictionary[TextureButton, Vector2] = {}
var _book_scale := Vector2.ONE
var _is_closing := false
var _error_message := ""

@onready var panel: Control = $Book
@onready var gold_label: Label = $Book/GoldBadge/Gold
@onready var buy_tab: TextureButton = $Book/Tabs/Buy
@onready var sell_tab: TextureButton = $Book/Tabs/Sell
@onready var item_scroll: ScrollContainer = $Book/GridScroll
@onready var grid: Control = $Book/GridScroll/Grid
@onready var item_icon: TextureRect = $Book/Info/Icon
@onready var item_name: Label = $Book/Info/ItemName
@onready var item_category: Label = $Book/Info/Category
@onready var item_count: Label = $Book/Info/Count
@onready var item_description: Label = $Book/Info/Description
@onready var effect_label: Label = $Book/Info/EffectText
@onready var price_plate: TextureRect = $Book/Info/PricePlate
@onready var trade_label: Label = $Book/Info/PricePlate/Trade
@onready var quantity_controls: Control = $Book/Info/Quantity
@onready var minus_button: TextureButton = $Book/Info/Quantity/Minus
@onready var plus_button: TextureButton = $Book/Info/Quantity/Plus
@onready var quantity_label: Label = $Book/Info/Quantity/Value
@onready var feedback: Label = $Book/Feedback
@onready var action_button: TextureButton = $Book/Info/Action
@onready var action_label: Label = $Book/Info/Action/Text
@onready var close_button: Button = $Book/Close
@onready var reroll_button: Button = $DebugReroll
@onready var toast_queue: TradeToastQueue = $TradeToastQueue


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	item_scroll.get_v_scroll_bar().modulate = scrollbar_tint
	panel.pivot_offset = panel.size * 0.5
	get_viewport().size_changed.connect(_fit_book)
	_fit_book()
	for button: TextureButton in [buy_tab, sell_tab]:
		_tab_base_scales[button] = button.scale
		button.resized.connect(_update_tab_pivot.bind(button))
	buy_tab.pressed.connect(_set_tab.bind(Tab.BUY))
	sell_tab.pressed.connect(_set_tab.bind(Tab.SELL))
	minus_button.pressed.connect(_change_quantity.bind(-1))
	plus_button.pressed.connect(_change_quantity.bind(1))
	action_button.pressed.connect(_on_action_pressed)
	close_button.pressed.connect(close_shop)
	reroll_button.visible = OS.has_feature("debug")
	reroll_button.pressed.connect(_on_debug_reroll_pressed)
	_restore_tab_feedback.call_deferred()
	hide()


func open_for(player: Player, catalog: MerchantCatalog) -> bool:
	if player == null or catalog == null or not catalog.validate().is_empty() or _is_closing:
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
	_selected_offer = null
	_selected_inventory_index = -1
	_quantity = MIN_TRADE_QUANTITY
	_error_message = ""
	show()
	_set_tab(Tab.BUY)
	_play_open_feedback()
	return true


func close_shop() -> void:
	if not visible or _is_closing:
		return
	_is_closing = true
	_kill_transition()
	_transition_tween = create_tween().set_parallel()
	_transition_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_transition_tween.set_ignore_time_scale(true)
	_transition_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_transition_tween.tween_property(panel, "modulate:a", 0.0, close_duration)
	_transition_tween.tween_property(panel, "scale", _book_scale * minimum_book_scale, close_duration)
	_transition_tween.chain().tween_callback(_finish_close)


func update_stock(stock: MerchantCatalog) -> void:
	if not visible or stock == null or not stock.validate().is_empty():
		return
	_catalog = stock
	_service = MerchantTransactionService.new(stock)
	_selected_offer = null
	_quantity = MIN_TRADE_QUANTITY
	_set_tab(Tab.BUY)


func _on_debug_reroll_pressed() -> void:
	stock_reroll_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close_shop()
		get_viewport().set_input_as_handled()


func _set_tab(tab: Tab) -> void:
	if _catalog == null or _inventory == null:
		return
	_current_tab = tab
	_quantity = MIN_TRADE_QUANTITY
	_error_message = ""
	_refresh()
	for index in range([buy_tab, sell_tab].size()):
		var button: TextureButton = [buy_tab, sell_tab][index]
		var selected := index == int(tab)
		button.set_pressed_no_signal(selected)
		_set_tab_feedback(button, selected, visible and not _is_closing)


func _refresh() -> void:
	if _catalog == null or _inventory == null or _wallet == null:
		return
	gold_label.text = str(_wallet.get_balance())
	_rebuild_grid()
	_refresh_selected_info()
	_refresh_feedback()


func _rebuild_grid() -> void:
	for child in grid.get_children():
		child.free()
	_slot_uis.clear()
	_slot_inventory_indices.clear()

	if _current_tab == Tab.BUY:
		var buy_offers := _catalog.get_buy_offers()
		if not buy_offers.has(_selected_offer):
			_selected_offer = buy_offers.front() if not buy_offers.is_empty() else null
		for offer: MerchantOffer in buy_offers:
			var slot_ui := SLOT_SCENE.instantiate() as SilasShopSlot
			grid.add_child(slot_ui)
			_place_slot(slot_ui, _slot_uis.size())
			slot_ui.set_item(offer.get_icon(), offer.trade_amount, offer.buy_price)
			slot_ui.tooltip_text = offer.get_display_name()
			slot_ui.clicked.connect(_select_buy_offer.bind(offer))
			slot_ui.set_selected(offer == _selected_offer)
			_slot_uis.append(slot_ui)
		_resize_grid()
		return

	for index in range(_inventory.slots.size()):
		var slot := _inventory.get_slot(index)
		if slot == null or slot.is_empty():
			continue
		var slot_ui := SLOT_SCENE.instantiate() as SilasShopSlot
		grid.add_child(slot_ui)
		_place_slot(slot_ui, _slot_uis.size())
		var offer := _catalog.get_sell_offer_for_item(slot.item.item_id)
		slot_ui.set_item(
			slot.item.icon, slot.quantity, offer.sell_price if offer != null else 0, offer != null
		)
		slot_ui.clicked.connect(_select_inventory_slot.bind(index))
		slot_ui.set_unavailable(offer == null)
		slot_ui.tooltip_text = (
			slot.item.display_name if offer != null else "Silas is not buying this item."
		)
		slot_ui.set_selected(index == _selected_inventory_index)
		_slot_uis.append(slot_ui)
		_slot_inventory_indices.append(index)
	if not _slot_inventory_indices.has(_selected_inventory_index):
		_selected_inventory_index = (
			_slot_inventory_indices.front() if not _slot_inventory_indices.is_empty() else -1
		)
	_update_slot_selection()
	_resize_grid()


func _place_slot(slot_ui: SilasShopSlot, index: int) -> void:
	var row := floori(float(index) / float(grid_columns))
	slot_ui.position = Vector2(index % grid_columns, row) * grid_step


func _resize_grid() -> void:
	var rows := maxi(minimum_grid_rows, ceili(float(_slot_uis.size()) / grid_columns))
	grid.custom_minimum_size = Vector2(grid_content_width, rows * grid_step.y)


func _select_buy_offer(offer: MerchantOffer) -> void:
	_selected_offer = offer
	_quantity = 1
	_error_message = ""
	_update_slot_selection()
	_refresh_selected_info()
	_refresh_feedback()


func _select_inventory_slot(index: int) -> void:
	_selected_inventory_index = index
	_quantity = 1
	_error_message = ""
	_update_slot_selection()
	_refresh_selected_info()
	_refresh_feedback()


func _update_slot_selection() -> void:
	for index in range(_slot_uis.size()):
		if _current_tab == Tab.BUY:
			var offers := _catalog.get_buy_offers()
			_slot_uis[index].set_selected(
				index < offers.size() and offers[index] == _selected_offer
			)
		else:
			_slot_uis[index].set_selected(
				_slot_inventory_indices[index] == _selected_inventory_index
			)


func _refresh_selected_info() -> void:
	var offer: MerchantOffer = _selected_offer if _current_tab == Tab.BUY else null
	var item: BaseItem
	var amount := 0

	if _current_tab != Tab.BUY:
		var slot := _inventory.get_slot(_selected_inventory_index)
		if slot != null and not slot.is_empty():
			item = slot.item
			amount = _inventory.count_item(item.item_id)
			offer = _catalog.get_sell_offer_for_item(item.item_id)

	if _current_tab == Tab.BUY and offer != null:
		_set_offer_info(offer)
		return
	if item != null:
		_set_inventory_item_info(item, amount, offer)
		return
	_clear_info()


func _set_offer_info(offer: MerchantOffer) -> void:
	_quantity = mini(
		_quantity,
		MIN_TRADE_QUANTITY if offer.kind == MerchantOffer.Kind.WEAPON else MAX_STACK_QUANTITY
	)
	item_icon.texture = offer.get_icon()
	item_name.text = offer.get_display_name()
	item_category.text = (
		"Weapon" if offer.kind == MerchantOffer.Kind.WEAPON else _item_type_name(offer.item)
	)
	item_count.text = "Owned: %d" % _get_owned_amount(offer)
	item_description.text = (
		offer.weapon.description
		if offer.kind == MerchantOffer.Kind.WEAPON
		else offer.item.description
	)
	effect_label.text = _offer_effect(offer)
	trade_label.text = str(offer.buy_price * _quantity)
	price_plate.show()
	_update_quantity_controls(offer.kind != MerchantOffer.Kind.WEAPON, MAX_STACK_QUANTITY)
	action_label.text = (
		"Owned"
		if offer.kind == MerchantOffer.Kind.WEAPON and _get_owned_amount(offer) > 0
		else "Purchase"
	)
	action_button.disabled = action_label.text == "Owned"
	action_button.modulate.a = disabled_action_alpha if action_button.disabled else 1.0
	action_button.show()


func _set_inventory_item_info(item: BaseItem, amount: int, offer: MerchantOffer) -> void:
	item_icon.texture = item.icon
	item_name.text = item.display_name
	item_category.text = _item_type_name(item)
	item_count.text = "In bag: %d" % amount
	item_description.text = item.description
	effect_label.text = _item_effect(item)
	if offer == null:
		price_plate.hide()
		quantity_controls.hide()
		action_button.hide()
		_error_message = "Silas does not buy this item."
		return
	var maximum := mini(MAX_STACK_QUANTITY, floori(float(amount) / float(offer.trade_amount)))
	_quantity = mini(_quantity, maxi(MIN_TRADE_QUANTITY, maximum))
	trade_label.text = str(offer.sell_price * _quantity)
	price_plate.show()
	_update_quantity_controls(true, maximum)
	action_label.text = "Sell"
	action_button.disabled = maximum < 1
	action_button.modulate.a = disabled_action_alpha if action_button.disabled else 1.0
	action_button.show()


func _clear_info() -> void:
	item_icon.texture = null
	item_name.text = "Select an item"
	item_category.text = ""
	item_count.text = ""
	item_description.text = "Choose an offer to see its details."
	effect_label.text = "Select an item"
	trade_label.text = ""
	price_plate.hide()
	quantity_controls.hide()
	action_button.hide()


func _item_type_name(item: BaseItem) -> String:
	match item.type:
		GlobalConstants.ItemType.CONSUMABLE:
			return "Consumable"
		GlobalConstants.ItemType.EQUIPMENT:
			return "Equipment"
		GlobalConstants.ItemType.QUEST:
			return "Quest item"
		_:
			return "Material"


func _item_effect(item: BaseItem) -> String:
	if item is HealingPotion:
		return "Restore %s HP" % String.num((item as HealingPotion).heal_amount, 0)
	if item is StaminaPotion:
		return "Restore %s stamina" % String.num((item as StaminaPotion).restore_amount, 0)
	if item.type == GlobalConstants.ItemType.MATERIAL:
		return "Used for crafting and trading."
	return item.description


func _offer_effect(offer: MerchantOffer) -> String:
	if offer.kind == MerchantOffer.Kind.WEAPON:
		return (
			"Stagger %s  •  Chaos +%s / hit"
			% [
				String.num(offer.weapon.stagger_damage, 0),
				String.num(offer.weapon.chaos_per_hit, 0)
			]
		)
	return _item_effect(offer.item)


func _update_quantity_controls(allowed: bool, maximum: int) -> void:
	quantity_controls.visible = allowed
	quantity_label.text = str(_quantity)
	minus_button.disabled = _quantity <= MIN_TRADE_QUANTITY
	plus_button.disabled = _quantity >= maximum
	minus_button.modulate.a = disabled_action_alpha if minus_button.disabled else 1.0
	plus_button.modulate.a = disabled_action_alpha if plus_button.disabled else 1.0


func _change_quantity(change: int) -> void:
	var maximum := MAX_STACK_QUANTITY
	if _current_tab == Tab.BUY and _selected_offer != null:
		if _selected_offer.kind == MerchantOffer.Kind.WEAPON:
			maximum = MIN_TRADE_QUANTITY
	elif _current_tab == Tab.SELL:
		var slot := _inventory.get_slot(_selected_inventory_index)
		if slot == null or slot.is_empty():
			return
		var offer := _catalog.get_sell_offer_for_item(slot.item.item_id)
		if offer == null:
			return
		maximum = mini(
			MAX_STACK_QUANTITY,
			floori(float(_inventory.count_item(slot.item.item_id)) / float(offer.trade_amount))
		)
	_quantity = clampi(
		_quantity + change, MIN_TRADE_QUANTITY, maxi(MIN_TRADE_QUANTITY, maximum)
	)
	_refresh_selected_info()


func _refresh_feedback() -> void:
	feedback.text = _error_message
	feedback.visible = not _error_message.is_empty()


func _on_action_pressed() -> void:
	if _service == null or _player == null or _inventory == null:
		return
	var result := MerchantTransactionService.Result.INVALID_OFFER
	var traded_offer: MerchantOffer
	var was_purchase := _current_tab == Tab.BUY
	if was_purchase and _selected_offer != null:
		traded_offer = _selected_offer
		result = _service.purchase(
			traded_offer.offer_id, _inventory, _wallet, _player.weapon_controller, _quantity
		)
		if result == MerchantTransactionService.Result.SUCCESS and traded_offer.offer_id == &"bow":
			var progress := get_node_or_null("/root/SilasProgress") as SilasProgressStore
			if progress != null:
				progress.mark_bow_purchased()
	elif _current_tab == Tab.SELL:
		var slot := _inventory.get_slot(_selected_inventory_index)
		if slot != null and not slot.is_empty():
			traded_offer = _catalog.get_sell_offer_for_item(slot.item.item_id)
			if traded_offer != null:
				result = _service.sell(traded_offer.offer_id, _inventory, _wallet, _quantity)

	if result == MerchantTransactionService.Result.SUCCESS and traded_offer != null:
		_error_message = ""
		_queue_success_toast(traded_offer, was_purchase, _quantity)
	else:
		_error_message = _service.get_result_message(result)
	_refresh()


func _queue_success_toast(offer: MerchantOffer, was_purchase: bool, quantity: int) -> void:
	var verb := "Purchased" if was_purchase else "Sold"
	var price_sign := "-" if was_purchase else "+"
	var gold := (offer.buy_price if was_purchase else offer.sell_price) * quantity
	toast_queue.enqueue_success(
		(
			"%s x%d %s  %s%d G"
			% [verb, offer.trade_amount * quantity, offer.get_display_name(), price_sign, gold]
		)
	)
	_quantity = MIN_TRADE_QUANTITY


func _get_owned_amount(offer: MerchantOffer) -> int:
	if offer.kind == MerchantOffer.Kind.WEAPON:
		return 1 if _player.weapon_controller.is_weapon_owned(offer.weapon.weapon_id) else 0
	return _inventory.count_item(offer.item.item_id)


func _connect_observers() -> void:
	if _wallet != null and not _wallet.balance_changed.is_connected(_on_wallet_changed):
		_wallet.balance_changed.connect(_on_wallet_changed)
	if _inventory != null and not _inventory.changed.is_connected(_on_inventory_changed):
		_inventory.changed.connect(_on_inventory_changed)


func _disconnect_observers() -> void:
	if _wallet != null and _wallet.balance_changed.is_connected(_on_wallet_changed):
		_wallet.balance_changed.disconnect(_on_wallet_changed)
	if _inventory != null and _inventory.changed.is_connected(_on_inventory_changed):
		_inventory.changed.disconnect(_on_inventory_changed)


func _on_wallet_changed(balance: int, _change: int) -> void:
	if visible:
		gold_label.text = str(balance)


func _on_inventory_changed() -> void:
	if visible:
		_refresh()


func _play_open_feedback() -> void:
	_kill_transition()
	panel.modulate.a = 0.0
	panel.scale = _book_scale * minimum_book_scale
	_restore_tab_feedback.call_deferred()
	_transition_tween = create_tween().set_parallel()
	_transition_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_transition_tween.set_ignore_time_scale(true)
	_transition_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_transition_tween.tween_property(panel, "modulate:a", 1.0, open_duration)
	_transition_tween.tween_property(panel, "scale", _book_scale, open_duration)


func _finish_close() -> void:
	_is_closing = false
	hide()
	toast_queue.clear()
	_restore_tab_feedback()
	panel.modulate.a = 1.0
	panel.scale = _book_scale
	Input.mouse_mode = _previous_mouse_mode
	_disconnect_observers()
	var manager := get_node_or_null("/root/GameManager")
	if manager != null:
		manager.exit_inventory()
	_player = null
	_inventory = null
	_catalog = null
	_service = null
	_selected_offer = null
	_selected_inventory_index = -1
	_quantity = MIN_TRADE_QUANTITY
	_error_message = ""
	shop_closed.emit()


func _update_tab_pivot(button: TextureButton) -> void:
	button.pivot_offset = button.size * 0.5


func _set_tab_feedback(button: TextureButton, selected: bool, animate: bool) -> void:
	var previous := _tab_tweens.get(button) as Tween
	if previous != null and previous.is_valid():
		previous.kill()
	_update_tab_pivot(button)
	button.texture_normal = TAB_ACTIVE if selected else TAB_INACTIVE
	var label := button.get_node("Text") as Label
	label.add_theme_color_override(
		"font_color", selected_tab_text_color if selected else idle_tab_text_color
	)
	var base_scale := _tab_base_scales[button]
	var target_scale := base_scale * (selected_tab_scale if selected else Vector2.ONE)
	var target_color := selected_tab_tint if selected else idle_tab_tint
	button.z_index = 1 if selected else 0
	if not animate:
		button.scale = target_scale
		button.modulate = target_color
		return
	var tween := create_tween().set_parallel(true)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_ignore_time_scale(true)
	_tab_tweens[button] = tween
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "modulate", target_color, tab_feedback_duration)
	if selected:
		tween.tween_property(
			button,
			"scale",
			target_scale * Vector2(tab_click_punch_scale, 1.0),
			tab_feedback_duration * tab_click_punch_duration_ratio
		)
		tween.chain().tween_property(button, "scale", target_scale, tab_feedback_duration)
	else:
		tween.tween_property(button, "scale", target_scale, tab_feedback_duration)


func _restore_tab_feedback() -> void:
	for index in range([buy_tab, sell_tab].size()):
		_set_tab_feedback([buy_tab, sell_tab][index], index == int(_current_tab), false)


func _fit_book() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var factor := minf(
		1.0,
		minf(
			viewport_size.x / reference_viewport_size.x,
			viewport_size.y / reference_viewport_size.y
		)
	)
	_book_scale = Vector2.ONE * factor
	panel.scale = _book_scale


func _kill_transition() -> void:
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition_tween = null


func _exit_tree() -> void:
	_kill_transition()
	_disconnect_observers()
	if visible:
		Input.mouse_mode = _previous_mouse_mode
		var manager := get_node_or_null("/root/GameManager")
		if manager != null:
			manager.exit_inventory()
