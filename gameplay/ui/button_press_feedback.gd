class_name ButtonPressFeedback
extends Node

## Add this as a child of a Button or TextureButton. The parent keeps its own script.
@export var visual_target: Control
@export_range(1.0, 1.2, 0.01) var hover_scale := 1.04
@export_range(0.7, 1.0, 0.01) var held_scale := 0.92
@export_range(1.0, 1.2, 0.01) var click_scale := 1.08
@export_range(0.02, 0.3, 0.01) var transition_duration := 0.1
@export var hover_tint := Color(1.0, 0.96, 0.85)
@export var held_tint := Color(0.82, 0.76, 0.65)
@export var click_tint := Color(1.0, 0.9, 0.65)
@export var center_pivot := true
@export var click_sound: AudioStream

var _button: BaseButton
var _visual: Control
var _rest_scale: Vector2
var _rest_modulate: Color
var _hovered := false
var _held := false
var _tween: Tween
var _audio_player: AudioStreamPlayer


func _ready() -> void:
	_button = get_parent() as BaseButton
	if _button == null:
		push_error("ButtonPressFeedback must be a child of a Button or TextureButton")
		return
	_visual = visual_target if visual_target != null else _button
	_rest_scale = _visual.scale
	_rest_modulate = _visual.modulate
	if center_pivot:
		_visual.resized.connect(_update_pivot)
		_update_pivot.call_deferred()
	_button.mouse_entered.connect(_on_mouse_entered)
	_button.mouse_exited.connect(_on_mouse_exited)
	_button.focus_entered.connect(_refresh_visual)
	_button.focus_exited.connect(_refresh_visual)
	_button.button_down.connect(_on_button_down)
	_button.button_up.connect(_on_button_up)
	_button.pressed.connect(_on_pressed)
	_button.visibility_changed.connect(_on_visibility_changed)
	if click_sound != null:
		_audio_player = AudioStreamPlayer.new()
		_audio_player.stream = click_sound
		add_child(_audio_player)


func _update_pivot() -> void:
	if is_instance_valid(_visual):
		_visual.pivot_offset = _visual.size * 0.5


func _on_mouse_entered() -> void:
	_hovered = true
	_refresh_visual()


func _on_mouse_exited() -> void:
	_hovered = false
	_refresh_visual()


func _on_button_down() -> void:
	_held = true
	_refresh_visual()


func _on_button_up() -> void:
	_held = false
	_refresh_visual()


func _on_pressed() -> void:
	if _button.disabled:
		return
	_held = false
	if _audio_player != null:
		_audio_player.play()
	_play_click_feedback.call_deferred()


func _play_click_feedback() -> void:
	if not is_instance_valid(_button) or not _button.is_visible_in_tree():
		return
	_stop_tween()
	_visual.scale = _rest_scale * click_scale
	_visual.modulate = _rest_modulate * click_tint
	_refresh_visual()


func _on_visibility_changed() -> void:
	if _button.is_visible_in_tree():
		return
	_hovered = false
	_held = false
	_stop_tween()
	_visual.scale = _rest_scale
	_visual.modulate = _rest_modulate


func _refresh_visual() -> void:
	if not is_instance_valid(_button) or not _button.is_visible_in_tree():
		return
	var active := not _button.disabled
	var highlighted := active and (_hovered or _button.has_focus())
	var factor := hover_scale if highlighted else 1.0
	var tint := hover_tint if highlighted else Color.WHITE
	if active and _held:
		factor = held_scale
		tint = held_tint
	_stop_tween()
	_tween = create_tween().set_parallel()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_ignore_time_scale(true)
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_visual, "scale", _rest_scale * factor, transition_duration)
	_tween.tween_property(_visual, "modulate", _rest_modulate * tint, transition_duration)


func _stop_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
