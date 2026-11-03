class_name GoldPickup
extends Area3D
## Pool-ready coin; activation restores all visuals and collection state before reuse.

signal recycle_requested(pickup: GoldPickup)

@export_range(1, 100000, 1) var amount: int = 1
@export_range(0.1, 2.0, 0.05) var drop_height: float = 0.8
@export var show_value_label: bool = false

var pooled: bool = false

var _available: bool = false
var _collected: bool = false
var _animation: Tween
var _drop_started: bool = false
var _wallet: GoldWallet

@onready var _sprite: Sprite3D = $Sprite3D
@onready var _value_label: Label3D = $Value
@onready var _scatter: PickupScatter = $Scatter
@onready var _attraction: PlayerAttraction = $Attraction
@onready var _rest_position: Vector3 = _sprite.position
@onready var _rest_scale: Vector3 = _sprite.scale
@onready var _rest_modulate: Color = _sprite.modulate


func _ready() -> void:
	_scatter.landed.connect(_land)
	_attraction.configure(_can_attract)
	_attraction.attraction_started.connect(_on_attraction_started)
	_attraction.attraction_cancelled.connect(_on_attraction_cancelled)
	_attraction.arrived.connect(_collect)
	_attraction.completed.connect(_finish_collection)
	var manager := get_node_or_null("/root/GameManager")
	if manager != null:
		_wallet = manager.get("gold_wallet") as GoldWallet
	if pooled:
		park()
		return
	_value_label.text = "%d G" % amount
	_value_label.hide()
	if amount <= 0:
		queue_free()
		return
	# Deferred so callers can place the pickup before its ground ray and bounce.
	_play_drop.call_deferred()


func park() -> void:
	_available = false
	_collected = false
	_drop_started = false
	_attraction.reset()
	_scatter.cancel()
	if _animation != null and _animation.is_valid():
		_animation.kill()
	_animation = null
	_sprite.position = _rest_position
	_sprite.scale = _rest_scale
	_sprite.modulate = _rest_modulate
	_value_label.hide()
	hide()
	process_mode = Node.PROCESS_MODE_DISABLED


func activate(at: Vector3, direction: Vector3) -> void:
	park()
	amount = 1
	_value_label.text = "1 G"
	global_position = at
	process_mode = Node.PROCESS_MODE_INHERIT
	show()
	play_drop_animation(direction)


func _play_drop() -> void:
	if not _drop_started:
		play_drop_animation()


func play_drop_animation(direction: Vector3 = Vector3.ZERO) -> void:
	if _drop_started:
		return
	_drop_started = true
	_sprite.position = _rest_position
	_scatter.launch(drop_height, 0.46, direction)


func _land() -> void:
	_available = true
	_value_label.visible = show_value_label
	_start_idle_animation()
	_attraction.set_enabled(true)


func _start_idle_animation() -> void:
	_animation = create_tween().set_loops()
	_animation.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_animation.tween_property(_sprite, "position:y", _rest_position.y + 0.12, 0.5)
	_animation.tween_property(_sprite, "position:y", _rest_position.y, 0.5)


func _can_attract(target: Node3D) -> bool:
	if not _available or _collected or not target is Player:
		return false
	var player := target as Player
	if player.dead or player.is_gameplay_input_blocked() or _wallet == null:
		return false
	return amount > 0 and amount <= GoldWallet.MAX_GOLD - _wallet.get_balance()


func _on_attraction_started(_target: Node3D) -> void:
	_value_label.hide()
	if _animation != null and _animation.is_valid():
		_animation.kill()
	_sprite.position = _rest_position
	_sprite.scale = _rest_scale


func _on_attraction_cancelled() -> void:
	if _available and not _collected:
		_value_label.visible = show_value_label
		_start_idle_animation()


func _collect(target: Node3D) -> void:
	if not _can_attract(target):
		_attraction.retry()
		return
	# Reserve before emitting the balance signal to prevent duplicate collection.
	_collected = true
	if not _wallet.add_gold(amount):
		_collected = false
		_attraction.retry()
		return
	_available = false
	_attraction.complete()


func _finish_collection() -> void:
	if pooled:
		recycle_requested.emit(self)
	else:
		queue_free()
