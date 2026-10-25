class_name HudStatArc
extends Node
## Hiển thị một chỉ số bằng cung nền, bóng và fill; dùng chung cho HP, SP và CP.

@export var capacity: ArcTooltipBar
@export var fill: TextureProgressBar
@export var shadow: TextureProgressBar
@export var fill_effect: BarFillEffect
@export var stat_name: String = "HP"

@export_group("Arc Layout")
@export_range(0.0, 360.0) var initial_angle: float = 200.0
@export_range(1.0, 360.0) var maximum_arc: float = 225.0
@export_range(1.0, 10000.0) var points_at_full_arc: float = 20.0

@export_group("Optional Indicators")
@export var value_label: Label
@export var readiness_icon: TextureRect
@export var unavailable_tint: Color = Color(0.55, 0.55, 0.55)

var _was_full: bool = false
var _icon_rotation: float = 0.0
var _readiness_tween: Tween
var _icon_scale: Vector2 = Vector2.ONE
var _punch_tween: Tween


func _ready() -> void:
	if is_instance_valid(readiness_icon):
		_icon_rotation = readiness_icon.rotation
		_icon_scale = readiness_icon.scale


func set_stat(current: float, maximum: float) -> void:
	var degrees := maximum_arc * clampf(maximum / maxf(points_at_full_arc, 1.0), 0.0, 1.0)
	for bar: TextureProgressBar in [capacity, fill, shadow]:
		bar.radial_initial_angle = initial_angle
		bar.radial_fill_degrees = degrees
		bar.max_value = maxf(maximum, 1.0)
	capacity.value = maxf(maximum, 0.0)
	shadow.value = maxf(maximum, 0.0)
	fill_effect.set_target(current)
	var text := "%s: %d / %d" % [stat_name, floori(current), floori(maximum)]
	capacity.set_stat_tooltip(text)
	if is_instance_valid(value_label):
		value_label.text = text
	if is_instance_valid(readiness_icon):
		var full := maximum > 0.0 and current >= maximum
		readiness_icon.modulate = Color.WHITE if full else unavailable_tint

		if full and not _was_full:
			_shake_readiness_shake()
		elif not full:
			_stop_readiness_shake()

		_was_full = full


# Cho phép mở riêng scene HUD mà không cần component gameplay.
func sync_preview() -> void:
	set_stat(fill.value, fill.max_value)


func _shake_readiness_shake() -> void:
	_stop_readiness_shake()

	readiness_icon.pivot_offset = readiness_icon.size * 0.5

	_punch_tween = create_tween()

	# Phóng lên 20%, rồi thu về scale gốc
	(
		_punch_tween
		. tween_property(readiness_icon, "scale", _icon_scale * 1.2, 0.1)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)

	(
		_punch_tween
		. tween_property(readiness_icon, "scale", _icon_scale, 0.18)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_OUT)
	)

	_readiness_tween = create_tween()
	_readiness_tween.set_trans(Tween.TRANS_SINE)

	for angle: float in [-8.0, 8.0, -5.0, 5.0, 0.0]:
		_readiness_tween.tween_property(
			readiness_icon, "rotation", _icon_rotation + deg_to_rad(angle), 0.1
		)


func _stop_readiness_shake() -> void:
	if _readiness_tween != null and _readiness_tween.is_valid():
		_readiness_tween.kill()
	if _punch_tween != null and _punch_tween.is_valid():
		_punch_tween.kill()

	readiness_icon.rotation = _icon_rotation
	readiness_icon.scale = _icon_scale
