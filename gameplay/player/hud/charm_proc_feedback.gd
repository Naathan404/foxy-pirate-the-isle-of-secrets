class_name CharmProcFeedback
extends Control
## One restartable animation per slot; repeated procs never accumulate scale or labels.

@export_range(1.0, 1.6, 0.01) var punch_scale: float = 1.3

var _icon: TextureRect
var _rest_scale: Vector2 = Vector2.ONE
var _tween: Tween
var _last_proc_msec: int = -1000

@onready var _label: Label = $Label
@onready var _label_origin: Vector2 = _label.position


func bind_icon(icon: TextureRect) -> void:
	_icon = icon
	_rest_scale = icon.scale


func play(message: String, color: Color) -> void:
	if not is_instance_valid(_icon) or not _icon.visible:
		return
	var now := Time.get_ticks_msec()
	if now - _last_proc_msec < 120:
		return
	reset()
	_last_proc_msec = now
	_icon.pivot_offset = _icon.size * 0.5
	_icon.modulate = color.lightened(0.6)
	_label.text = message
	_label.add_theme_color_override("font_color", color)
	_label.position = _label_origin
	_label.modulate = Color.WHITE
	_label.show()
	_tween = create_tween().set_ignore_time_scale(true)
	_tween.set_parallel()
	(
		_tween
		. tween_property(_icon, "scale", _rest_scale * punch_scale, 0.065)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_tween
		. tween_property(_icon, "scale", _rest_scale, 0.22)
		. set_delay(0.065)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	_tween.tween_property(_icon, "modulate", Color.WHITE, 0.28)
	_tween.tween_property(_label, "position", _label_origin + Vector2.UP * 14.0, 0.7)
	_tween.tween_property(_label, "modulate:a", 0.0, 0.35).set_delay(0.35)
	_tween.chain().tween_callback(_label.hide)


func reset() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if is_instance_valid(_icon):
		_icon.scale = _rest_scale
		_icon.modulate = Color.WHITE
	_label.hide()
	_last_proc_msec = -1000
