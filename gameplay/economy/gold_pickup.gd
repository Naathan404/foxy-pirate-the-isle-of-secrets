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

@onready var _sprite: Sprite3D = $Sprite3D
@onready var _value_label: Label3D = $Value
@onready var _scatter: PickupScatter = $Scatter
@onready var _collider: CollisionShape3D = $CollisionShape3D
@onready var _rest_position: Vector3 = _sprite.position
@onready var _rest_scale: Vector3 = _sprite.scale
@onready var _rest_modulate: Color = _sprite.modulate


func _ready() -> void:
	set_physics_process(false)
	_scatter.landed.connect(_land)
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
	set_physics_process(false)
	_scatter.cancel()
	if _animation != null and _animation.is_valid():
		_animation.kill()
	_animation = null
	_sprite.position = _rest_position
	_sprite.scale = _rest_scale
	_sprite.modulate = _rest_modulate
	_value_label.hide()
	set_deferred("monitoring", false)
	_collider.set_deferred("disabled", true)
	hide()
	process_mode = Node.PROCESS_MODE_DISABLED


func activate(at: Vector3, direction: Vector3) -> void:
	park()
	amount = 1
	_value_label.text = "1 G"
	global_position = at
	process_mode = Node.PROCESS_MODE_INHERIT
	show()
	set_deferred("monitoring", true)
	_collider.set_deferred("disabled", false)
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
	set_physics_process(true)
	_animation = create_tween().set_loops()
	_animation.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_animation.tween_property(_sprite, "position:y", _rest_position.y + 0.12, 0.5)
	_animation.tween_property(_sprite, "position:y", _rest_position.y, 0.5)


func _physics_process(_delta: float) -> void:
	if not _available or _collected:
		return
	for body: Node3D in get_overlapping_bodies():
		if body is Player and not body.dead and not body.is_gameplay_input_blocked():
			_collect(body as Player)
			if _collected:
				return


func _collect(player: Player) -> void:
	var manager := get_node_or_null("/root/GameManager")
	if manager == null:
		return
	var wallet := manager.get("gold_wallet") as GoldWallet
	if wallet == null:
		return
	# Reserve before emitting the balance signal to prevent duplicate collection.
	_collected = true
	if not wallet.add_gold(amount):
		_collected = false
		return
	set_physics_process(false)
	set_deferred("monitoring", false)
	_value_label.hide()
	if _animation != null and _animation.is_valid():
		_animation.kill()
	_animation = create_tween().set_parallel(true)
	_animation.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_animation.tween_property(
		_sprite, "global_position", player.global_position + Vector3.UP * 0.8, 0.16
	)
	_animation.tween_property(_sprite, "scale", _sprite.scale * 0.25, 0.16)
	_animation.tween_property(_sprite, "modulate:a", 0.0, 0.16)
	_animation.chain().tween_callback(_finish_collection)


func _finish_collection() -> void:
	if pooled:
		recycle_requested.emit(self)
	else:
		queue_free()
