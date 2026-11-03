extends Control
## HUD observes the shared wallet; it never owns a second copy of the balance.

var _wallet: GoldWallet
var _feedback_tween: Tween

@onready var _value: Label = $Row/Amount
@onready var _gain: Label = $Gain
@onready var _gain_rest_position: Vector2 = _gain.position


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
