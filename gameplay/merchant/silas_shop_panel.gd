class_name SilasShopPanel
extends CanvasLayer

## A merchant view shaped like InventoryUI. It renders only previews/read-only
## inventory slots so trading cannot accidentally rearrange or equip items.
signal shop_closed

const SLOT_SCENE: PackedScene = preload("res://gameplay/inventory/inventory_slot_ui.tscn")

enum Tab { BUY, SELL, BAG }

var _catalog: MerchantCatalog
var _service: MerchantTransactionService
var _player: Player
var _inventory: Inventory
var _wallet: GoldWallet
var _selected_offer: MerchantOffer
var _selected_inventory_index := -1
var _current_tab := Tab.BUY
var _previous_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _slot_uis: Array[InventorySlotUI] = []
var _transition_tween: Tween

@onready var panel: PanelContainer = $PanelContainer
@onready var book_background: TextureRect = $PanelContainer/Background
@onready var gold_label: Label = $PanelContainer/MarginContainer/Layout/Header/Gold
@onready var buy_tab: Button = $PanelContainer/MarginContainer/Layout/Tabs/Buy
@onready var sell_tab: Button = $PanelContainer/MarginContainer/Layout/Tabs/Sell
@onready var bag_tab: Button = $PanelContainer/MarginContainer/Layout/Tabs/Bag
@onready var grid: GridContainer = $PanelContainer/MarginContainer/Layout/Content/ItemScroll/GridContainer
@onready var item_icon: TextureRect = $PanelContainer/MarginContainer/Layout/Content/ItemInfo/MarginContainer/VBox/IconCenter/IconFrame/Icon
@onready var item_name: Label = $PanelContainer/MarginContainer/Layout/Content/ItemInfo/MarginContainer/VBox/ItemName
@onready var item_count: Label = $PanelContainer/MarginContainer/Layout/Content/ItemInfo/MarginContainer/VBox/Count
@onready var item_description: Label = $PanelContainer/MarginContainer/Layout/Content/ItemInfo/MarginContainer/VBox/Description
@onready var trade_label: Label = $PanelContainer/MarginContainer/Layout/Content/ItemInfo/MarginContainer/VBox/Trade
@onready var action_button: Button = $PanelContainer/MarginContainer/Layout/Content/ItemInfo/MarginContainer/VBox/Action
@onready var feedback: Label = $PanelContainer/MarginContainer/Layout/Feedback
@onready var close_button: Button = $PanelContainer/MarginContainer/Layout/Close


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	buy_tab.pressed.connect(_set_tab.bind(Tab.BUY))
	sell_tab.pressed.connect(_set_tab.bind(Tab.SELL))
	bag_tab.pressed.connect(_set_tab.bind(Tab.BAG))
	action_button.pressed.connect(_on_action_pressed)
	close_button.pressed.connect(close_shop)
	hide()


func open_for(player: Player, catalog: MerchantCatalog) -> bool:
	if player == null or catalog == null or not catalog.validate().is_empty():
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
	feedback.text = ""
	show()
	_play_open_feedback()
	_set_tab(Tab.BUY)
	return true


func close_shop() -> void:
	if not visible:
		return
	_kill_transition()
	hide()
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
	shop_closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close_shop()
		get_viewport().set_input_as_handled()


func _set_tab(tab: Tab) -> void:
	if _catalog == null or _inventory == null:
		return
	_current_tab = tab
	buy_tab.disabled = tab == Tab.BUY
	sell_tab.disabled = tab == Tab.SELL
	bag_tab.disabled = tab == Tab.BAG
	feedback.text = ""
	_refresh()


func _refresh() -> void:
	if _catalog == null or _inventory == null or _wallet == null:
		return
	gold_label.text = "GOLD: %d" % _wallet.get_balance()
	_rebuild_grid()
	_refresh_selected_info()


func _rebuild_grid() -> void:
	for child in grid.get_children():
		child.free()
	_slot_uis.clear()

	if _current_tab == Tab.BUY:
		var buy_offers := _catalog.get_buy_offers()
		if not buy_offers.has(_selected_offer):
			_selected_offer = buy_offers.front() if not buy_offers.is_empty() else null
		for offer: MerchantOffer in buy_offers:
			var slot_ui := SLOT_SCENE.instantiate() as InventorySlotUI
			grid.add_child(slot_ui)
			slot_ui.set_preview(offer.get_icon(), offer.trade_amount)
			slot_ui.tooltip_text = offer.get_display_name()
			slot_ui.clicked.connect(_select_buy_offer.bind(offer))
			slot_ui.set_selected(offer == _selected_offer)
			_slot_uis.append(slot_ui)
		return

	for index in range(_inventory.slots.size()):
		var slot_ui := SLOT_SCENE.instantiate() as InventorySlotUI
		slot_ui.inventory = _inventory
		slot_ui.slot_index = index
		slot_ui.set_drag_enabled(false)
		grid.add_child(slot_ui)
		var slot := _inventory.get_slot(index)
		slot_ui.refresh(slot)
		slot_ui.clicked.connect(_select_inventory_slot.bind(index))
		if _current_tab == Tab.SELL and slot != null and not slot.is_empty():
			var offer := _catalog.get_sell_offer_for_item(slot.item.item_id)
			if offer == null:
				slot_ui.modulate = Color(0.48, 0.48, 0.48, 1.0)
				slot_ui.tooltip_text = "Silas is not buying this item."
		slot_ui.set_selected(index == _selected_inventory_index)
		_slot_uis.append(slot_ui)


func _select_buy_offer(offer: MerchantOffer) -> void:
	_selected_offer = offer
	feedback.text = ""
	_update_slot_selection()
	_refresh_selected_info()


func _select_inventory_slot(index: int) -> void:
	_selected_inventory_index = index
	feedback.text = ""
	_update_slot_selection()
	_refresh_selected_info()


func _update_slot_selection() -> void:
	for index in range(_slot_uis.size()):
		if _current_tab == Tab.BUY:
			var offers := _catalog.get_buy_offers()
			_slot_uis[index].set_selected(index < offers.size() and offers[index] == _selected_offer)
		else:
			_slot_uis[index].set_selected(index == _selected_inventory_index)


func _refresh_selected_info() -> void:
	var offer: MerchantOffer = _selected_offer if _current_tab == Tab.BUY else null
	var item: BaseItem
	var amount := 0

	if _current_tab != Tab.BUY:
		var slot := _inventory.get_slot(_selected_inventory_index)
		if slot != null and not slot.is_empty():
			item = slot.item
			amount = _inventory.count_item(item.item_id)
			if _current_tab == Tab.SELL:
				offer = _catalog.get_sell_offer_for_item(item.item_id)

	if _current_tab == Tab.BUY and offer != null:
		_set_offer_info(offer)
		return
	if item != null:
		_set_inventory_item_info(item, amount, offer)
		return
	_clear_info()


func _set_offer_info(offer: MerchantOffer) -> void:
	item_icon.texture = offer.get_icon()
	item_name.text = offer.get_display_name()
	item_count.text = "OWNED: %d" % _get_owned_amount(offer)
	item_description.text = offer.weapon.description if offer.kind == MerchantOffer.Kind.WEAPON else offer.item.description
	trade_label.text = "BUY %d  •  %d GOLD" % [offer.trade_amount, offer.buy_price]
	action_button.text = "BUY x%d" % offer.trade_amount
	action_button.disabled = false
	action_button.show()


func _set_inventory_item_info(item: BaseItem, amount: int, offer: MerchantOffer) -> void:
	item_icon.texture = item.icon
	item_name.text = item.display_name
	item_count.text = "IN BAG: %d / %d" % [amount, item.max_stack]
	item_description.text = item.description
	if _current_tab == Tab.BAG:
		trade_label.text = "READ ONLY"
		action_button.hide()
		return
	if offer == null:
		trade_label.text = "SILAS DOES NOT BUY THIS ITEM"
		action_button.text = "NOT FOR SALE"
		action_button.disabled = true
		action_button.show()
		return
	trade_label.text = "SELL %d  •  %d GOLD" % [offer.trade_amount, offer.sell_price]
	action_button.text = "SELL x%d" % offer.trade_amount
	action_button.disabled = amount < offer.trade_amount
	action_button.show()


func _clear_info() -> void:
	item_icon.texture = null
	item_name.text = ""
	item_count.text = ""
	item_description.text = "Select an item to inspect it."
	trade_label.text = ""
	action_button.hide()


func _on_action_pressed() -> void:
	if _service == null or _player == null or _inventory == null:
		return
	var result := MerchantTransactionService.Result.INVALID_OFFER
	if _current_tab == Tab.BUY and _selected_offer != null:
		result = _service.purchase(
			_selected_offer.offer_id, _inventory, _wallet, _player.weapon_controller
		)
		if result == MerchantTransactionService.Result.SUCCESS and _selected_offer.offer_id == &"bow":
			var progress := get_node_or_null("/root/SilasProgress") as SilasProgressStore
			if progress != null:
				progress.mark_bow_purchased()
	elif _current_tab == Tab.SELL:
		var slot := _inventory.get_slot(_selected_inventory_index)
		if slot != null and not slot.is_empty():
			var offer := _catalog.get_sell_offer_for_item(slot.item.item_id)
			if offer != null:
				result = _service.sell(offer.offer_id, _inventory, _wallet)
	feedback.text = _service.get_result_message(result)
	_refresh()


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
		gold_label.text = "GOLD: %d" % balance


func _on_inventory_changed() -> void:
	if visible:
		_refresh()


func _play_open_feedback() -> void:
	_kill_transition()
	panel.modulate.a = 0.0
	book_background.pivot_offset = book_background.size * 0.5
	book_background.scale = Vector2(1.04, 1.04)
	_transition_tween = create_tween().set_parallel()
	_transition_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_transition_tween.tween_property(panel, "modulate:a", 1.0, 0.16)
	_transition_tween.tween_property(book_background, "scale", Vector2.ONE, 0.16)


func _kill_transition() -> void:
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition_tween = null


func _exit_tree() -> void:
	_kill_transition()
	_disconnect_observers()
