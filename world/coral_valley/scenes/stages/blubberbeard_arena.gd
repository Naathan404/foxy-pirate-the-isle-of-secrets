extends Node
## Atmosphere for the sea arena. Combat and rewards remain owned by the boss.

@export var boss: BossBase

var _overlay: ColorRect
var _message: Label
var _tween: Tween


func _ready() -> void:
	if not is_instance_valid(boss) or boss.is_queued_for_deletion() or boss.dead:
		return
	_create_warning_ui()
	boss.fight_started.connect(_on_fight_started)
	boss.phase_changed.connect(_on_phase_changed)
	boss.fight_finished.connect(_on_fight_finished)
	_show_warning("DANGER AHEAD  •  BLUBBERBEARD'S WATERS", Color(0.1, 0.65, 0.7), 3.5)
	_rumble(4.0)


func _on_fight_started() -> void:
	_show_warning("CAPTAIN BLUBBERBEARD APPROACHES!", Color(1.0, 0.3, 0.08), 2.8)
	_rumble(8.0)


func _on_phase_changed(_index: int) -> void:
	_show_warning("DANGER  •  THE CAPTAIN IS ENRAGED!", Color(1.0, 0.12, 0.06), 2.5)


func _on_fight_finished() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_overlay.color.a = 0.0
	_message.modulate.a = 0.0


func _rumble(strength: float) -> void:
	get_node("/root/ScreenShakeController").request(strength, 0.25)


func _show_warning(text: String, color: Color, duration: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_message.text = text
	_message.modulate = Color(1, 1, 1, 1)
	_overlay.color = Color(color.r, color.g, color.b, 0.16)
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_overlay, "color:a", 0.0, 0.8)
	_tween.tween_property(_message, "modulate:a", 0.0, 0.7).set_delay(duration - 0.7)


func _create_warning_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ArenaWarningUI"
	layer.layer = 8
	add_child(layer)
	_overlay = ColorRect.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_message = Label.new()
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message.add_theme_font_size_override("font_size", 26)
	_message.add_theme_color_override("font_color", Color(1.0, 0.88, 0.63))
	_message.add_theme_color_override("font_outline_color", Color(0.12, 0.05, 0.03))
	_message.add_theme_constant_override("outline_size", 6)
	layer.add_child(_message)
	_message.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_message.offset_left = -500
	_message.offset_right = 500
	_message.offset_top = 85
	_message.offset_bottom = 135
