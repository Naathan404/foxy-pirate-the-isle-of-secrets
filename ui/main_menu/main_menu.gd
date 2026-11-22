class_name MainMenu
extends Control
## Entry scene: Play starts the gameplay scene through GameManager, Quit closes the game.

const INK_PROGRESS_PARAM := &"progress"
const INK_HIDDEN := 0.0
const INK_SHOWN := 1.0

## First gameplay scene of a run. Progress is kept in memory only, so Play always starts here.
@export_file("*.tscn") var gameplay_scene: String = "res://world/biomes/hub/map/room_02.tscn"
@export_group("Intro")
@export_range(0.1, 2.0, 0.05, "suffix:s") var ink_open_seconds: float = 0.9
@export_range(0.05, 1.0, 0.05, "suffix:s") var title_fade_seconds: float = 0.5
@export_range(0.0, 1.0, 0.05, "suffix:s") var buttons_delay_seconds: float = 0.35
@export_range(1.0, 1.3, 0.01) var button_lift: float = 1.06

var _intro_tween: Tween
var _starting: bool = false

@onready var _background: TextureRect = %Background
@onready var _title: Control = %TitleBlock
@onready var _play_button: Button = %PlayButton
@onready var _quit_button: Button = %QuitButton


func _ready() -> void:
	# A fresh session starts at the menu; saved files are never touched.
	get_node("/root/GameManager").reset_session()
	_play_button.pressed.connect(_on_play_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	for button: Button in [_play_button, _quit_button]:
		InventoryHoverFeedback.attach(button, null, button_lift)
	_play_intro()
	_play_button.grab_focus()


func _exit_tree() -> void:
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()


func _play_intro() -> void:
	_set_ink_progress(INK_HIDDEN)
	_title.modulate.a = 0.0
	_intro_tween = create_tween().set_parallel()
	_intro_tween.set_ignore_time_scale(true)
	var ink := _intro_tween.tween_method(_set_ink_progress, INK_HIDDEN, INK_SHOWN, ink_open_seconds)
	ink.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_property(_title, "modulate:a", 1.0, title_fade_seconds)
	(
		_intro_tween
		. tween_callback(InventoryMenuFx.stagger_in.bind([_play_button, _quit_button]))
		. set_delay(buttons_delay_seconds)
	)


func _set_ink_progress(progress: float) -> void:
	(_background.material as ShaderMaterial).set_shader_parameter(INK_PROGRESS_PARAM, progress)


func _on_play_pressed() -> void:
	if _starting:
		return
	_starting = true
	_set_buttons_disabled(true)
	if not get_node("/root/GameManager").change_scene(gameplay_scene):
		push_error("MainMenu: cannot start %s" % gameplay_scene)
		_starting = false
		_set_buttons_disabled(false)
		_play_button.grab_focus()


func _on_quit_pressed() -> void:
	if _starting:
		return
	_starting = true
	get_tree().quit()


func _set_buttons_disabled(disabled: bool) -> void:
	_play_button.disabled = disabled
	_quit_button.disabled = disabled
