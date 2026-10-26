class_name ItemPickup
extends Area3D

@export var item: BaseItem
@export_range(1, 999, 1) var quantity: int = 1

@export_group("Idle Animation")
@export var idle_animation_enabled: bool = true
@export_range(0.0, 0.3, 0.01) var pulse_amount: float = 0.08
@export_range(0.0, 1.0, 0.01) var float_height: float = 0.2
@export_range(0.0, 1.0, 0.01) var bob_height: float = 0.35
@export_range(0.2, 5.0, 0.1) var cycle_duration: float = 1.6
@export_range(0.2, 5.0, 0.1) var scale_cycle_duration: float = 0.8

var _idle_tween: Tween

@onready var sprite: Sprite3D = $Sprite3D


func _ready() -> void:
	if not idle_animation_enabled:
		return

	# tween floating item & scale
	var rest_scale: Vector3 = sprite.scale
	var rest_y: float = sprite.position.y + float_height
	sprite.position.y = rest_y
	var half_cycle: float = maxf(0.1, cycle_duration / 2.0)
	var half_scale_cycle: float = maxf(0.1, scale_cycle_duration / 2.0)
	_idle_tween = create_tween().set_loops()
	_idle_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.tween_property(sprite, "scale", rest_scale * (1.0 + pulse_amount), half_scale_cycle)
	_idle_tween.parallel().tween_property(sprite, "position:y", rest_y + bob_height, half_cycle)
	_idle_tween.tween_property(sprite, "scale", rest_scale, half_scale_cycle)
	_idle_tween.parallel().tween_property(sprite, "position:y", rest_y, half_cycle)


func _on_body_entered(body: Node3D) -> void:
	if body is not Player:
		return
	
	if item == null or quantity <= 0:
		return

	var inventory = body.get_node_or_null("Inventory") as Inventory

	if inventory == null:
		return
	
	quantity = inventory.add_item(item, quantity)

	print("Trong túi: ", inventory.count_item(item.item_id), " | Còn dưới đất: ", quantity)

	if quantity == 0:
		queue_free()
