class_name BarFillEffect
extends Node

@export var color_fill: TextureProgressBar
@export var white_fill: TextureProgressBar

@export_group("Timing")

@export_range(0.01, 1.0, 0.01) var lead_duration: float = 0.12
@export_range(0.0, 1.0, 0.01) var follow_delay: float = 0.2
@export_range(0.01, 2.0, 0.01) var follow_duration: float = 0.35
@export_range(0.01, 1.0, 0.01) var fade_duration: float = 0.12

var _initialized: bool = false
var _active: bool = false
var _following: bool = false
var _target: float = 0.0
var _rising: bool = false
var _lead_fill: TextureProgressBar
var _follow_fill: TextureProgressBar
var _lead_tween: Tween
var _follow_tween: Tween
var _delay_tween: Tween
var _fade_tween: Tween


func _ready() -> void:
	color_fill.step = 0.0
	white_fill.step = 0.0
	white_fill.hide()
	white_fill.modulate.a = 0.0


func set_target(amount: float) -> void:                     
	_sync_white_fill()
	var next_target := clampf(amount, color_fill.min_value, color_fill.max_value)
	if not _initialized:
		_initialized = true
		_target = next_target
		color_fill.value = next_target
		white_fill.value = next_target
		return
	if is_equal_approx(next_target, _target):
		return
	var rising := next_target > _target
	if _active and rising != _rising:

		_stop(_delay_tween)
		_stop(_follow_tween)
		_active = false
		_following = false
	_rising = rising
	_target = next_target
	# Khi mất: màu rút trước để lộ trắng ở phần vừa mất, trắng thu lại sau
	# Khi hồi: trắng tăng trước để báo lượng hồi, màu chạy theo và che trắng lại
	_lead_fill = white_fill if _rising else color_fill
	_follow_fill = color_fill if _rising else white_fill
	white_fill.value = maxf(white_fill.value, color_fill.value)
	white_fill.show()
	_stop(_fade_tween)
	_fade_tween = create_tween()
	_fade_tween.tween_property(white_fill, "modulate:a", 1.0, 0.06)

	# Retarget từ vị trí đang chạy, không quay về giá trị của đòn trước.
	_stop(_lead_tween)
	_lead_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_lead_tween.tween_property(_lead_fill, "value", _target, lead_duration)
	_lead_tween.tween_callback(_try_finish)

	if not _active:
		_active = true
		_following = false
		_delay_tween = create_tween()
		_delay_tween.tween_interval(follow_delay)
		_delay_tween.tween_callback(_start_following)
	elif _following:
		_start_following()


# sync các thuộc tính của fill
func _sync_white_fill() -> void:
	white_fill.position = color_fill.position
	white_fill.size = color_fill.size
	white_fill.scale = color_fill.scale
	white_fill.rotation = color_fill.rotation
	white_fill.pivot_offset = color_fill.pivot_offset
	white_fill.texture_progress = color_fill.texture_progress
	white_fill.texture_progress_offset = color_fill.texture_progress_offset
	white_fill.nine_patch_stretch = color_fill.nine_patch_stretch
	white_fill.fill_mode = color_fill.fill_mode
	white_fill.radial_center_offset = color_fill.radial_center_offset
	white_fill.radial_initial_angle = color_fill.radial_initial_angle
	white_fill.radial_fill_degrees = color_fill.radial_fill_degrees
	white_fill.max_value = color_fill.max_value


func _start_following() -> void:
	_following = true
	_stop(_follow_tween)
	_follow_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_follow_tween.tween_property(_follow_fill, "value", _target, follow_duration)
	_follow_tween.tween_callback(_try_finish)


func _try_finish() -> void:
	if not _following:
		return
	if not is_equal_approx(color_fill.value, _target) or not is_equal_approx(white_fill.value, _target):
		return
	_stop(_fade_tween)
	_fade_tween = create_tween()
	_fade_tween.tween_property(white_fill, "modulate:a", 0.0, fade_duration)
	_fade_tween.tween_callback(_finish_cycle)


func _finish_cycle() -> void:
	_active = false
	_following = false
	white_fill.hide()


func _stop(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
