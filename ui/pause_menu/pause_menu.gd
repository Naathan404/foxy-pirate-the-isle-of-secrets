class_name PauseMenu
extends CanvasLayer
## In-game pause menu. Escape opens a page that slides in from the left while ink spreads from the
## left edge. GameManager owns the tree pause (State.PAUSE_MENU); this node only asks for it.

enum Phase { CLOSED, OPENING, OPEN, CLOSING, LEAVING }

const CANCEL_ACTION := &"ui_cancel"
const INK_PROGRESS_PARAM := &"progress"
const INK_HIDDEN := 0.0
const INK_SHOWN := 1.0
const PAGE_FADE_RATIO := 0.6

@export_group("Motion")
@export_range(0.1, 1.5, 0.01, "suffix:s") var ink_open_seconds: float = 0.55
@export_range(0.1, 1.0, 0.01, "suffix:s") var page_open_seconds: float = 0.4
@export_range(0.05, 1.0, 0.01, "suffix:s") var ink_close_seconds: float = 0.3
@export_range(0.05, 0.8, 0.01, "suffix:s") var page_close_seconds: float = 0.24
@export_range(40.0, 900.0, 1.0, "suffix:px") var slide_distance_pixels: float = 420.0
@export_range(1.0, 1.3, 0.01) var button_lift: float = 1.06

var _phase: Phase = Phase.CLOSED
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _tween: Tween

@onready var _root: Control = %Root
@onready var _background: TextureRect = %Background
@onready var _slide: Control = %Slide
@onready var _resume_button: Button = %ResumeButton
@onready var _quit_button: Button = %QuitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.hide()
	_resume_button.pressed.connect(_request_close)
	_quit_button.pressed.connect(_request_leave)
	for button: Button in [_resume_button, _quit_button]:
		InventoryHoverFeedback.attach(button, null, button_lift)
	get_node("/root/GameManager").scene_transition_finished.connect(_on_transition_finished)


# Unhandled on purpose: shops, the forge, the inventory and the potion wheel consume Escape
# first, so one press never closes a panel and opens this menu.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(CANCEL_ACTION) or event.is_echo():
		return
	match _phase:
		Phase.CLOSED:
			if _open():
				get_viewport().set_input_as_handled()
		Phase.OPEN:
			_request_close()
			get_viewport().set_input_as_handled()
		_:
			# Opening, closing or leaving: swallow the key so it cannot repeat the action.
			get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	_kill_tween()
	if _phase == Phase.CLOSED:
		return
	Input.mouse_mode = _previous_mouse_mode
	# No-op while GameManager is mid-transition: it resumes the tree itself.
	get_node("/root/GameManager").exit_pause_menu()


func is_open() -> bool:
	return _phase != Phase.CLOSED


func _open() -> bool:
	var player := get_parent() as Player
	if player != null and (player.dead or player.is_gameplay_input_blocked()):
		return false
	if not get_node("/root/GameManager").enter_pause_menu():
		return false
	_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_phase = Phase.OPENING
	_root.show()
	_set_buttons_disabled(true)
	_set_ink_progress(INK_HIDDEN)
	_slide.position.x = -slide_distance_pixels
	_slide.modulate.a = 0.0
	_kill_tween()
	_tween = create_tween().set_parallel()
	_tween.set_ignore_time_scale(true)
	var ink := _tween.tween_method(_set_ink_progress, INK_HIDDEN, INK_SHOWN, ink_open_seconds)
	ink.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var slide := _tween.tween_property(_slide, "position:x", 0.0, page_open_seconds)
	slide.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_slide, "modulate:a", 1.0, page_open_seconds * PAGE_FADE_RATIO)
	_tween.chain().tween_callback(_on_opened)
	return true


func _on_opened() -> void:
	_phase = Phase.OPEN
	_set_buttons_disabled(false)
	_resume_button.grab_focus()


func _request_close() -> void:
	if _phase != Phase.OPEN:
		return
	_phase = Phase.CLOSING
	_set_buttons_disabled(true)
	_kill_tween()
	_tween = create_tween().set_parallel()
	_tween.set_ignore_time_scale(true)
	var ink := _tween.tween_method(
		_set_ink_progress, _ink_progress(), INK_HIDDEN, ink_close_seconds
	)
	ink.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var slide := _tween.tween_property(
		_slide, "position:x", -slide_distance_pixels, page_close_seconds
	)
	slide.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(_slide, "modulate:a", 0.0, page_close_seconds)
	_tween.chain().tween_callback(_finish_close)


func _finish_close() -> void:
	_root.hide()
	_phase = Phase.CLOSED
	Input.mouse_mode = _previous_mouse_mode
	get_node("/root/GameManager").exit_pause_menu()


func _request_leave() -> void:
	if _phase != Phase.OPEN:
		return
	_phase = Phase.LEAVING
	_set_buttons_disabled(true)
	if not get_node("/root/GameManager").return_to_main_menu():
		_restore_after_failed_leave()


## GameManager emits this after every transition, including a failed one that left this scene.
func _on_transition_finished() -> void:
	if _phase == Phase.LEAVING and is_inside_tree():
		_restore_after_failed_leave()


func _restore_after_failed_leave() -> void:
	_phase = Phase.OPEN
	_set_buttons_disabled(false)
	_quit_button.grab_focus()


func _set_buttons_disabled(disabled: bool) -> void:
	_resume_button.disabled = disabled
	_quit_button.disabled = disabled


func _set_ink_progress(progress: float) -> void:
	(_background.material as ShaderMaterial).set_shader_parameter(INK_PROGRESS_PARAM, progress)


func _ink_progress() -> float:
	return float((_background.material as ShaderMaterial).get_shader_parameter(INK_PROGRESS_PARAM))


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
