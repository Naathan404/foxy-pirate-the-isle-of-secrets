class_name SilasShopSlot
extends Button
## One ware in Silas's grid: framed icon, bundle or stack count and a price tag below.
## State never relies on color alone: owned weapons read "Owned", refused goods read "No deal"
## and prices the player cannot pay carry a cross before the amount.

enum PriceState { NORMAL, UNAFFORDABLE, OWNED, REFUSED }

const UNAFFORDABLE_MARK := "✕ "
const OWNED_TEXT := "Owned"
const REFUSED_TEXT := "No deal"
const COUNT_PREFIX := "x"

@export var price_color: Color = Color(0.96, 0.89, 0.77)
@export var unaffordable_color: Color = Color(0.95, 0.47, 0.44)
@export var muted_color: Color = Color(0.77, 0.61, 0.53)
@export_range(0.0, 1.0, 0.01) var refused_icon_alpha: float = 0.38
@export_range(0.0, 1.0, 0.01) var hover_selection_alpha: float = 0.45
@export_range(1.0, 1.2, 0.01) var hover_scale: float = 1.06

var _selected: bool = false
var _hovered: bool = false

@onready var _visual: Control = %Visual
@onready var _icon: TextureRect = %Icon
@onready var _count: Label = %Count
@onready var _selection: TextureRect = %Selection
@onready var _coin: TextureRect = %Coin
@onready var _price: Label = %Price


func _ready() -> void:
	InventoryHoverFeedback.attach(self, _visual, hover_scale)
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	focus_entered.connect(_set_hovered.bind(true))
	focus_exited.connect(_set_hovered.bind(false))
	_apply()


## `count` is the bundle size on the Buy tab and the amount carried on the Sell tab.
func present(item_icon: Texture2D, count: int, price: int, state: PriceState) -> void:
	_icon.texture = item_icon
	_icon.modulate.a = refused_icon_alpha if state == PriceState.REFUSED else 1.0
	_count.text = COUNT_PREFIX + str(count)
	_count.visible = count > 1
	var shows_price := state == PriceState.NORMAL or state == PriceState.UNAFFORDABLE
	_coin.visible = shows_price
	match state:
		PriceState.OWNED:
			_price.text = OWNED_TEXT
		PriceState.REFUSED:
			_price.text = REFUSED_TEXT
		PriceState.UNAFFORDABLE:
			_price.text = UNAFFORDABLE_MARK + str(price)
		_:
			_price.text = str(price)
	var color := price_color
	if state == PriceState.UNAFFORDABLE:
		color = unaffordable_color
	elif state != PriceState.NORMAL:
		color = muted_color
	_price.add_theme_color_override("font_color", color)


func set_selected(selected: bool) -> void:
	_selected = selected
	_apply()


func is_selected() -> bool:
	return _selected


func _set_hovered(hovered: bool) -> void:
	_hovered = hovered
	_apply()


func _apply() -> void:
	if not is_node_ready():
		return
	_selection.visible = _selected or _hovered
	_selection.modulate.a = 1.0 if _selected else hover_selection_alpha
