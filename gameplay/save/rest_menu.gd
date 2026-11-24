class_name RestMenu
extends CanvasLayer
## Campfire choice shown while the tree is paused. It only presents state and reports the
## player's choice; CampfireRestPoint decides what resting and saving do.

signal save_requested
signal close_requested

const CANCEL_ACTION := &"ui_cancel"

@export_range(1.0, 1.3, 0.01) var button_lift: float = 1.06

var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE

@onready var _root: Control = %Root
@onready var _message: Label = %Message
@onready var _slot: Label = %Slot
@onready var _result: Label = %Result
@onready var _save_button: Button = %SaveButton
@onready var _leave_button: Button = %LeaveButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.hide()
	_save_button.pressed.connect(save_requested.emit)
	_leave_button.pressed.connect(close_requested.emit)
	for button: Button in [_save_button, _leave_button]:
		InventoryHoverFeedback.attach(button, null, button_lift)


# Handled here so one Escape press closes this menu and never also opens the pause menu.
func _unhandled_input(event: InputEvent) -> void:
	if not is_open() or not event.is_action_pressed(CANCEL_ACTION) or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	close_requested.emit()


func _exit_tree() -> void:
	if is_open():
		Input.mouse_mode = _previous_mouse_mode


func is_open() -> bool:
	return is_node_ready() and _root.visible


## `slot_text` names the save that Save will overwrite.
func open_for_rest(message: String, slot_text: String) -> void:
	_show(message)
	_slot.text = slot_text
	_slot.show()
	_save_button.show()
	_save_button.disabled = false
	_save_button.grab_focus()


## A campfire that cannot be used offers only Leave.
func open_unavailable(message: String) -> void:
	_show(message)
	_slot.hide()
	_save_button.hide()
	_leave_button.grab_focus()


func show_save_result(saved: bool, message: String, slot_text: String) -> void:
	_result.text = message
	_result.show()
	_slot.text = slot_text
	# After a good save, a second press would only rewrite the same state.
	_save_button.disabled = saved
	if saved:
		_leave_button.grab_focus()


func close() -> void:
	if not is_open():
		return
	_root.hide()
	Input.mouse_mode = _previous_mouse_mode


func is_save_available() -> bool:
	return is_open() and _save_button.visible and not _save_button.disabled


func get_message() -> String:
	return _message.text


func get_result() -> String:
	return _result.text if _result.visible else ""


func _show(message: String) -> void:
	if not is_open():
		_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_message.text = message
	_result.text = ""
	_result.hide()
	_root.show()
