extends Control
## HUD observes the shared wallet; it never owns a second copy of the balance.

const COIN_TEXTURE: Texture2D = preload("res://assets/sprites/items/Coin.png")

var _wallet: GoldWallet
var _feedback_tween: Tween

@onready var _value: Label = $Row/Amount
@onready var _gain: Label = $Gain
@onready var _gain_rest_position: Vector2 = _gain.position
@onready var _coin_icon: TextureRect = $Row/Icon


func _ready() -> void:
	# Merchant menus pause the world. Currency feedback must finish while they are open.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var manager := get_node_or_null("/root/GameManager")
	if manager == null:
		return
	_wallet = manager.get("gold_wallet") as GoldWallet
	if _wallet == null:
		return
	_wallet.balance_changed.connect(_on_balance_changed)
	_value.text = str(_wallet.get_balance())


func _on_balance_changed(balance: int, change: int) -> void:
	_value.text = str(balance)
	if change == 0:
		return
	_reset_feedback()
	_gain.text = "+%d G" % change if change > 0 else "%d G" % change
	_gain.add_theme_color_override(
		"font_color", Color(0.95, 0.9, 0.55, 1.0) if change > 0 else Color(1.0, 0.38, 0.32, 1.0)
	)
	_gain.position = _gain_rest_position
	_gain.modulate.a = 1.0
	_gain.show()
	_feedback_tween = create_tween().set_parallel(true)
	_feedback_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_feedback_tween.set_ignore_time_scale(true)
	_feedback_tween.tween_property(_gain, "position:y", _gain_rest_position.y - 12.0, 0.8)
	_feedback_tween.tween_property(_gain, "modulate:a", 0.0, 0.45).set_delay(0.3)
	_feedback_tween.tween_callback(_clear_gain).set_delay(0.8)


func play_pickup_fly(from_world_position: Vector3) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or not is_inside_tree():
		return
	var canvas_parent := get_parent()
	if canvas_parent == null:
		return

	var coin := TextureRect.new()
	coin.texture = COIN_TEXTURE
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin.z_index = 100
	coin.size = Vector2(24.0, 24.0)
	canvas_parent.add_child(coin)
	var canvas_layer := canvas_parent as CanvasLayer
	var canvas_transform := canvas_layer.transform if canvas_layer != null else Transform2D.IDENTITY
	coin.position = (
		canvas_transform.affine_inverse() * camera.unproject_position(from_world_position)
		- coin.size * 0.5
	)

	var icon_center_on_screen := (
		_coin_icon.get_global_transform_with_canvas() * (_coin_icon.size * 0.5)
	)
	var destination := canvas_transform.affine_inverse() * icon_center_on_screen
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_ignore_time_scale(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(coin, "position", destination - coin.size * 0.5, 0.38)
	tween.parallel().tween_property(coin, "scale", Vector2(0.45, 0.45), 0.38)
	tween.parallel().tween_property(coin, "modulate:a", 0.7, 0.38)
	tween.tween_callback(coin.queue_free)
	_pulse_coin_icon()


func _pulse_coin_icon() -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_ignore_time_scale(true)
	tween.tween_property(_coin_icon, "scale", Vector2(1.18, 1.18), 0.1)
	tween.tween_property(_coin_icon, "scale", Vector2.ONE, 0.14)


func _clear_gain() -> void:
	_gain.hide()
	_gain.position = _gain_rest_position
	_gain.modulate.a = 1.0
	_feedback_tween = null


func _reset_feedback() -> void:
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()
	_feedback_tween = null
	_gain.hide()
	_gain.position = _gain_rest_position
	_gain.modulate.a = 1.0


func _exit_tree() -> void:
	_reset_feedback()
	if _wallet != null and _wallet.balance_changed.is_connected(_on_balance_changed):
		_wallet.balance_changed.disconnect(_on_balance_changed)
