extends PanelContainer
## Displays and expires one grouped item pickup notification.

signal expired(entry: Control)

@export_range(0.0, 10.0, 0.1) var hold_seconds: float = 2.0
@export_range(0.0, 5.0, 0.05) var fade_seconds: float = 0.3
@export var label_format: String = "%s  +%d"

var item_id: String
var _item_name: String
var _quantity: int
var _tween: Tween

@onready var _icon: TextureRect = $Row/Icon
@onready var _label: Label = $Row/Label


func show_item(item: BaseItem, quantity: int) -> void:
	item_id = item.item_id
	_item_name = item.display_name
	_icon.texture = item.icon
	add_quantity(quantity)


func add_quantity(quantity: int) -> void:
	_quantity += quantity
	_label.text = label_format % [_item_name, _quantity]
	if _tween != null and _tween.is_valid():
		_tween.kill()
	modulate.a = 1.0
	_tween = create_tween()
	_tween.tween_interval(hold_seconds)
	_tween.tween_property(self, "modulate:a", 0.0, fade_seconds)
	_tween.tween_callback(expired.emit.bind(self))
