extends Control
## HUD observes the shared wallet; it never owns a second copy of the balance.

var _wallet: GoldWallet
var _gain_tween: Tween
var _gain_total: int = 0

@onready var _value: Label = $Panel/Row/Amount
@onready var _gain: Label = $Gain
@onready var _gain_rest_position: Vector2 = _gain.position


func _ready() -> void:
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
	if change <= 0:
		return
	if _gain_tween != null and _gain_tween.is_valid():
		_gain_tween.kill()
	_gain_total += change
	_gain.text = "+%d G" % _gain_total
	_gain.position = _gain_rest_position
	_gain.modulate.a = 1.0
	_gain.show()
	_gain_tween = create_tween().set_parallel(true)
	_gain_tween.tween_property(_gain, "position:y", _gain_rest_position.y - 12.0, 0.8)
	_gain_tween.tween_property(_gain, "modulate:a", 0.0, 0.6).set_delay(0.2)
	_gain_tween.chain().tween_callback(_clear_gain)


func _clear_gain() -> void:
	_gain.hide()
	_gain_total = 0


func _exit_tree() -> void:
	if _wallet != null and _wallet.balance_changed.is_connected(_on_balance_changed):
		_wallet.balance_changed.disconnect(_on_balance_changed)
