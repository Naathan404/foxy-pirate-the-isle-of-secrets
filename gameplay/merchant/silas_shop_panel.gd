class_name SilasShopPanel
extends CanvasLayer

signal shop_closed

const SLOT_TEXTURE: Texture2D = preload("res://assets/ui/player_hud/inventory/inventory_slot.png")

var _catalog: MerchantCatalog
var _service: MerchantTransactionService
var _player: Player
var _wallet: GoldWallet
var _selected_offer: MerchantOffer
var _is_buying := true
var _previous_mouse_mode := Input.MOUSE_MODE_VISIBLE

@onready var gold_label: Label = $Panel/Margin/Layout/Gold
@onready var buy_tab: Button = $Panel/Margin/Layout/Tabs/Buy
@onready var sell_tab: Button = $Panel/Margin/Layout/Tabs/Sell
@onready var entries: VBoxContainer = $Panel/Margin/Layout/Content/Entries/Rows
@onready var item_icon: TextureRect = $Panel/Margin/Layout/Content/Info/IconFrame/Icon
@onready var item_name: Label = $Panel/Margin/Layout/Content/Info/Name
@onready var item_count: Label = $Panel/Margin/Layout/Content/Info/Count
@onready var item_description: Label = $Panel/Margin/Layout/Content/Info/Description
@onready var action_button: Button = $Panel/Margin/Layout/Content/Info/Action
@onready var feedback: Label = $Panel/Margin/Layout/Feedback


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	buy_tab.pressed.connect(_set_mode.bind(true))
	sell_tab.pressed.connect(_set_mode.bind(false))
	action_button.pressed.connect(_on_action_pressed)
	$Panel/Margin/Layout/Close.pressed.connect(close_shop)
	hide()


func open_for(player: Player, catalog: MerchantCatalog) -> bool:
	if player == null or catalog == null or not catalog.validate().is_empty():
		return false
	var manager := get_node_or_null("/root/GameManager")
	if manager == null or not manager.enter_inventory():
		return false
	_player = player
	_catalog = catalog
	_service = MerchantTransactionService.new(_catalog)
	_wallet = manager.get("gold_wallet") as GoldWallet
	if _wallet == null:
		manager.exit_inventory()
		return false
	if not _wallet.balance_changed.is_connected(_on_wallet_changed):
		_wallet.balance_changed.connect(_on_wallet_changed)
	_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_is_buying = true
	_selected_offer = null
	feedback.text = ""
	show()
	_refresh()
	return true


func close_shop() -> void:
	if not visible:
		return
	hide()
	Input.mouse_mode = _previous_mouse_mode
	var manager := get_node_or_null("/root/GameManager")
	if manager != null:
		manager.exit_inventory()
	_player = null
	_catalog = null
	_service = null
	_selected_offer = null
	shop_closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close_shop()
		get_viewport().set_input_as_handled()


func _set_mode(buying: bool) -> void:
	if _is_buying == buying:
		return
	_is_buying = buying
	_selected_offer = null
	feedback.text = ""
	_refresh()


func _refresh() -> void:
	if _catalog == null or _player == null:
		return
	gold_label.text = "Gold: %d" % _wallet.get_balance()
	buy_tab.disabled = _is_buying
	sell_tab.disabled = not _is_buying
	var available := _catalog.get_buy_offers() if _is_buying else _catalog.get_sell_offers()
	if not available.has(_selected_offer):
		_selected_offer = available.front() if not available.is_empty() else null
	for child in entries.get_children():
		child.queue_free()
	for offer: MerchantOffer in available:
		entries.add_child(_make_offer_button(offer))
	_refresh_selected_info()


func _make_offer_button(offer: MerchantOffer) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(300, 58)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.icon = offer.get_icon()
	button.expand_icon = true
	button.text = "%s  x%d\n%s: %d G" % [
		offer.get_display_name(),
		_get_owned_amount(offer),
		"Buy" if _is_buying else "Sell",
		offer.buy_price if _is_buying else offer.sell_price,
	]
	var style := StyleBoxTexture.new()
	style.texture = SLOT_TEXTURE
	style.set_expand_margin_all(8.0)
	button.add_theme_stylebox_override("normal", style)
	button.pressed.connect(_select_offer.bind(offer))
	return button


func _select_offer(offer: MerchantOffer) -> void:
	_selected_offer = offer
	feedback.text = ""
	_refresh_selected_info()


func _refresh_selected_info() -> void:
	if _selected_offer == null:
		item_icon.texture = null
		item_name.text = ""
		item_count.text = ""
		item_description.text = ""
		action_button.disabled = true
		return
	item_icon.texture = _selected_offer.get_icon()
	item_name.text = _selected_offer.get_display_name()
	item_count.text = "Owned: %d" % _get_owned_amount(_selected_offer)
	if _selected_offer.kind == MerchantOffer.Kind.WEAPON:
		item_description.text = _selected_offer.weapon.description
	else:
		item_description.text = _selected_offer.item.description
	var price := _selected_offer.buy_price if _is_buying else _selected_offer.sell_price
	action_button.text = "%s x1 (%d G)" % ["Buy" if _is_buying else "Sell", price]
	action_button.disabled = false


func _on_action_pressed() -> void:
	if _selected_offer == null or _service == null or _player == null:
		return
	var inventory := _player.get_node_or_null("Inventory") as Inventory
	var result: MerchantTransactionService.Result
	if _is_buying:
		result = _service.purchase(
			_selected_offer.offer_id, inventory, _wallet, _player.weapon_controller
		)
		if result == MerchantTransactionService.Result.SUCCESS and _selected_offer.offer_id == &"bow":
			var progress := get_node_or_null("/root/SilasProgress") as SilasProgressStore
			if progress != null:
				progress.mark_bow_purchased()
	else:
		result = _service.sell(_selected_offer.offer_id, inventory, _wallet)
	feedback.text = _service.get_result_message(result)
	_refresh()


func _get_owned_amount(offer: MerchantOffer) -> int:
	if _player == null:
		return 0
	if offer.kind == MerchantOffer.Kind.WEAPON:
		return 1 if _player.weapon_controller.is_weapon_owned(offer.weapon.weapon_id) else 0
	var inventory := _player.get_node_or_null("Inventory") as Inventory
	return inventory.count_item(offer.item.item_id) if inventory != null else 0


func _on_wallet_changed(balance: int, _change: int) -> void:
	if visible:
		gold_label.text = "Gold: %d" % balance


func _exit_tree() -> void:
	if _wallet != null and _wallet.balance_changed.is_connected(_on_wallet_changed):
		_wallet.balance_changed.disconnect(_on_wallet_changed)
