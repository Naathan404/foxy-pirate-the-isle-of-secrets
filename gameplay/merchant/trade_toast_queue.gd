class_name TradeToastQueue
extends Control

## A pause-safe FIFO queue used for successful merchant transactions.
@export_range(0.2, 5.0, 0.1) var hold_duration := 1.0
@export_group("Animation")
@export_range(0.0, 40.0, 1.0) var enter_offset := 10.0
@export_range(0.0, 40.0, 1.0) var exit_offset := 8.0
@export_range(0.01, 1.0, 0.01) var enter_duration := 0.14
@export_range(0.01, 1.0, 0.01) var exit_duration := 0.24

var _pending: Array[String] = []
var _showing := false
var _tween: Tween
var _rest_position := Vector2.ZERO

@onready var panel: PanelContainer = $Panel
@onready var message: Label = $Panel/MarginContainer/Row/Message


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rest_position = panel.position
	panel.hide()


func enqueue_success(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	_pending.append(text)
	if not _showing:
		_show_next()


func pending_count() -> int:
	return _pending.size() + (1 if _showing else 0)


func clear() -> void:
	_pending.clear()
	_showing = false
	_kill_tween()
	panel.hide()
	panel.position = _rest_position
	panel.modulate.a = 1.0


func _show_next() -> void:
	if _pending.is_empty():
		_showing = false
		return
	_showing = true
	message.text = _pending.pop_front()
	panel.position = _rest_position + Vector2(0.0, -enter_offset)
	panel.modulate.a = 0.0
	panel.show()
	_kill_tween()
	_tween = create_tween().set_parallel(true)
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_ignore_time_scale(true)
	_tween.tween_property(panel, "position:y", _rest_position.y, enter_duration)
	_tween.tween_property(panel, "modulate:a", 1.0, enter_duration)
	_tween.tween_property(
		panel, "position:y", _rest_position.y - exit_offset, exit_duration
	).set_delay(hold_duration)
	_tween.tween_property(panel, "modulate:a", 0.0, exit_duration).set_delay(hold_duration)
	_tween.tween_callback(_finish_current).set_delay(hold_duration + exit_duration)


func _finish_current() -> void:
	panel.hide()
	panel.position = _rest_position
	panel.modulate.a = 1.0
	_tween = null
	_show_next()


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _exit_tree() -> void:
	_kill_tween()
