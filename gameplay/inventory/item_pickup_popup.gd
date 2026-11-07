extends Node3D
## Plays item icons above the player after a successful world pickup.

@export var inventory: Inventory
@export var animation_name: StringName = &"pickup"
@export_range(0.01, 5.0, 0.01, "suffix:m") var icon_world_size: float = 1.2

var _pending_icons: Array[Texture2D] = []

@onready var _icon: Sprite3D = $Icon
@onready var _animation: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	_icon.hide()
	if inventory != null:
		inventory.item_picked_up.connect(_on_item_picked_up)
	_animation.animation_finished.connect(_on_animation_finished)


func _on_item_picked_up(item: BaseItem, _quantity: int) -> void:
	if item == null or item.icon == null:
		return
	_pending_icons.append(item.icon)
	if not _animation.is_playing():
		_play_next()


func _play_next() -> void:
	if _pending_icons.is_empty():
		_icon.hide()
		return
	_icon.texture = _pending_icons.pop_front()
	var texture_size := _icon.texture.get_size()
	var longest_side := maxf(texture_size.x, texture_size.y)
	if longest_side > 0.0:
		_icon.pixel_size = icon_world_size / longest_side
	_icon.show()
	_animation.play(animation_name)


func _on_animation_finished(finished_name: StringName) -> void:
	if finished_name == animation_name:
		_play_next()
