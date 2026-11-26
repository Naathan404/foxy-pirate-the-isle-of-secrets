class_name RestMenu
extends CanvasLayer
## Campfire choice shown while the tree is paused. It only presents state and reports the
## player's choice; CampfireRestPoint decides what resting and saving do.

signal rest_requested
signal rest_and_save_requested
signal close_requested

const CANCEL_ACTION := &"ui_cancel"

@export_range(1.0, 1.3, 0.01) var button_lift: float = 1.06
@export_group("Rest fade")
@export_range(0.05, 2.0, 0.05, "suffix:s") var fade_out_seconds: float = 0.6
## How long the screen stays black while the island resets.
@export_range(0.0, 2.0, 0.05, "suffix:s") var dark_hold_seconds: float = 0.4
@export_range(0.05, 2.0, 0.05, "suffix:s") var fade_in_seconds: float = 0.6

var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _fade_tween: Tween

@onready var _root: Control = %Root
@onready var _message: Label = %Message
@onready var _slot: Label = %Slot
@onready var _panel: Control = %Center
@onready var _rest_button: Button = %RestButton
@onready var _rest_and_save_button: Button = %RestAndSaveButton
@onready var _quit_button: Button = %QuitButton
@onready var _fade: ColorRect = %Fade


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.hide()
	_fade.hide()
	_rest_button.pressed.connect(rest_requested.emit)
	_rest_and_save_button.pressed.connect(rest_and_save_requested.emit)
	_quit_button.pressed.connect(close_requested.emit)
	for button: Button in [_rest_button, _rest_and_save_button, _quit_button]:
		InventoryHoverFeedback.attach(button, null, button_lift)


# Handled here so one Escape press closes this menu and never also opens the pause menu.
# While the rest fade runs, Escape is swallowed so the rest cannot be left half done.
func _unhandled_input(event: InputEvent) -> void:
	if not is_open() or not event.is_action_pressed(CANCEL_ACTION) or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	if not is_fading():
		close_requested.emit()


func _exit_tree() -> void:
	if is_open():
		Input.mouse_mode = _previous_mouse_mode


func is_open() -> bool:
	return is_node_ready() and _root.visible


func is_fading() -> bool:
	return _fade_tween != null and _fade_tween.is_valid()


## Hides the choices, darkens the screen, calls `on_dark` while it is fully black,
## brightens it again, then calls `on_finished`. The tree stays paused by the caller, so
## this runs on real time.
func play_rest_fade(on_dark: Callable, on_finished: Callable) -> void:
	if is_fading():
		_fade_tween.kill()
	_panel.hide()
	_fade.modulate.a = 0.0
	_fade.show()
	_fade_tween = create_tween()
	_fade_tween.set_ignore_time_scale(true)
	_fade_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fade_tween.tween_property(_fade, "modulate:a", 1.0, fade_out_seconds)
	_fade_tween.tween_callback(on_dark)
	_fade_tween.tween_interval(dark_hold_seconds)
	_fade_tween.tween_property(_fade, "modulate:a", 0.0, fade_in_seconds)
	_fade_tween.tween_callback(_finish_fade.bind(on_finished))


## The three choices. `slot_text` names the save that Rest and save will overwrite.
func open_choices(message: String, slot_text: String) -> void:
	_show(message)
	_slot.text = slot_text
	_slot.show()
	_show_choices(true)
	_rest_button.grab_focus()


## A campfire that cannot be used offers only Quit.
func open_unavailable(message: String) -> void:
	_show(message)
	_slot.hide()
	_show_choices(false)
	_quit_button.grab_focus()


## Shown after a rest that included a save; the player then leaves with Quit.
func show_save_result(message: String, slot_text: String) -> void:
	_show(message)
	_slot.text = slot_text
	_slot.show()
	_show_choices(false)
	_quit_button.grab_focus()


func close() -> void:
	if is_fading():
		_fade_tween.kill()
		_fade_tween = null
		_fade.hide()
	if not is_open():
		return
	_root.hide()
	Input.mouse_mode = _previous_mouse_mode


func get_message() -> String:
	return _message.text


func are_rest_choices_available() -> bool:
	return is_open() and _rest_button.visible


func _finish_fade(on_finished: Callable) -> void:
	_fade.hide()
	_fade_tween = null
	on_finished.call()


func _show(message: String) -> void:
	if not is_open():
		_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_message.text = message
	_panel.show()
	_root.show()


func _show_choices(rest_available: bool) -> void:
	_rest_button.visible = rest_available
	_rest_and_save_button.visible = rest_available
