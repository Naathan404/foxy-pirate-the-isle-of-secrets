class_name ItemPickup
extends Area3D

@export var item: BaseItem
@export_range(1, 999, 1) var quantity: int = 1

@export_group("Idle Animation")
@export var idle_animation_enabled: bool = true
@export_range(0.0, 0.3, 0.01) var pulse_amount: float = 0.08
@export_range(0.0, 1.0, 0.01) var float_height: float = 0.2
@export_range(0.0, 1.0, 0.01) var ground_clearance: float = 0.08
@export_range(0.0, 1.0, 0.01) var bob_height: float = 0.35
@export_range(0.2, 5.0, 0.1) var cycle_duration: float = 1.2
@export_range(0.2, 5.0, 0.1) var scale_cycle_duration: float = 0.6

@export_group("Drop Animation")
@export_range(0.1, 3.0, 0.05) var drop_height: float = 0.9
@export_range(0.05, 1.0, 0.01) var rise_duration: float = 0.18
@export_range(0.05, 1.0, 0.01) var fall_duration: float = 0.28

var _idle_tween: Tween
var _drop_tween: Tween
var _rest_scale: Vector3
var _rest_position: Vector3
var _can_be_picked_up: bool = true
var _collecting: bool = false

@onready var sprite: Sprite3D = $Sprite3D
@onready var _scatter: PickupScatter = $Scatter
@onready var _attraction: PlayerAttraction = $Attraction


func _ready() -> void:
	if item != null:
		sprite.texture = item.icon
	_rest_scale = sprite.scale
	_rest_position = sprite.position
	# Sprite có tâm ở giữa ảnh: cần nâng thêm nửa chiều cao để đáy không lún.
	if sprite.texture != null:
		var frame_height: float = sprite.texture.get_height() / float(maxi(1, sprite.vframes))
		var half_height: float = frame_height * sprite.pixel_size * absf(_rest_scale.y) * 0.5
		_rest_position.y += half_height * maxf(1.15, 1.0 + pulse_amount)
	_rest_position.y += ground_clearance
	if idle_animation_enabled:
		_rest_position.y += float_height
	_scatter.landed.connect(_on_scatter_landed)
	_attraction.configure(_can_attract)
	_attraction.attraction_started.connect(_on_attraction_started)
	_attraction.attraction_cancelled.connect(_on_attraction_cancelled)
	_attraction.arrived.connect(_collect)
	_attraction.completed.connect(queue_free)
	_start_idle_animation()
	_attraction.set_enabled(true)


func _start_idle_animation() -> void:
	sprite.scale = _rest_scale
	sprite.position = _rest_position
	if not idle_animation_enabled:
		return

	# tween floating item & scale
	var half_cycle: float = maxf(0.1, cycle_duration / 2.0)
	var half_scale_cycle: float = maxf(0.1, scale_cycle_duration / 2.0)
	_idle_tween = create_tween().set_loops()
	_idle_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.tween_property(
		sprite, "scale", _rest_scale * (1.0 + pulse_amount), half_scale_cycle
	)
	_idle_tween.parallel().tween_property(
		sprite, "position:y", _rest_position.y + bob_height, half_cycle
	)
	_idle_tween.tween_property(sprite, "scale", _rest_scale, half_scale_cycle)
	_idle_tween.parallel().tween_property(sprite, "position:y", _rest_position.y, half_cycle)


## Called after placement; the shared scatter component moves both visual and pickup area.
func play_drop_animation(direction: Vector3 = Vector3.ZERO) -> void:
	_attraction.reset()
	if _idle_tween != null and _idle_tween.is_valid():
		_idle_tween.kill()
	if _drop_tween != null and _drop_tween.is_valid():
		_drop_tween.kill()
	_can_be_picked_up = false
	sprite.position = _rest_position
	sprite.scale = _rest_scale
	_scatter.launch(drop_height, rise_duration + fall_duration, direction)


func _on_scatter_landed() -> void:
	if _drop_tween != null and _drop_tween.is_valid():
		_drop_tween.kill()
	_drop_tween = create_tween()
	# Ép nhẹ khi chạm đất, rồi trả lại hình dáng trước khi lơ lửng.
	_drop_tween.tween_property(sprite, "scale", _rest_scale * Vector3(1.16, 0.78, 1.0), 0.06)
	_drop_tween.tween_property(sprite, "scale", _rest_scale, 0.12)
	_drop_tween.tween_callback(_finish_drop_animation)


func _finish_drop_animation() -> void:
	_drop_tween = null
	_start_idle_animation()
	_can_be_picked_up = true
	_attraction.set_enabled(true)


func _on_body_entered(body: Node3D) -> void:
	_attraction.try_attract(body)


func _can_attract(target: Node3D) -> bool:
	if not _can_be_picked_up or _collecting or is_queued_for_deletion():
		return false
	if item == null or quantity <= 0 or not target is Player:
		return false
	var player := target as Player
	if player.dead or player.is_gameplay_input_blocked():
		return false
	var inventory := player.get_node_or_null("Inventory") as Inventory
	return inventory != null and inventory.get_available_space(item) > 0


func _on_attraction_started(_target: Node3D) -> void:
	if _idle_tween != null and _idle_tween.is_valid():
		_idle_tween.kill()
	if _drop_tween != null and _drop_tween.is_valid():
		_drop_tween.kill()
	sprite.position = _rest_position
	sprite.scale = _rest_scale


func _on_attraction_cancelled() -> void:
	_collecting = false
	_start_idle_animation()


func _collect(target: Node3D) -> void:
	if not _can_attract(target):
		_attraction.retry()
		return
	var inventory := target.get_node_or_null("Inventory") as Inventory
	# Inventory signals may re-enter pickup code; reserve the transaction first.
	_collecting = true
	var requested_quantity := quantity
	quantity = inventory.add_item(item, quantity)
	var accepted_quantity := requested_quantity - quantity
	inventory.notify_item_picked_up(item, accepted_quantity)
	if quantity > 0:
		_collecting = false
		_attraction.retry()
		return
	_can_be_picked_up = false
	_attraction.complete()
