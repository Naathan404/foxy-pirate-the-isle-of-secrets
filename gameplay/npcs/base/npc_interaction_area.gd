class_name NpcInteractionArea
extends Area3D

## Reusable proximity interaction. It deliberately stops handling input while a
## conversation is active so Dialogic can receive its own advance/choice keys.

signal interaction_requested(interactor: Player)

@export_range(0.0, 10.0, 0.1) var prompt_height: float = 2.2

var _enabled := true
var _interactors: Array[Player] = []
var _prompt: Label3D


func _ready() -> void:
	_prompt = _create_prompt()
	add_child(_prompt)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	for body in get_overlapping_bodies():
		_register_interactor(body)
	_refresh_input()


func set_interaction_enabled(value: bool) -> void:
	_enabled = value
	_refresh_input()


func _unhandled_input(event: InputEvent) -> void:
	if not _enabled or not event.is_action_pressed(_get_dialogue_input_action()):
		return
	var interactor := _get_interactor()
	if interactor == null:
		return
	get_viewport().set_input_as_handled()
	interaction_requested.emit(interactor)


func _get_interactor() -> Player:
	for interactor in _interactors:
		if is_instance_valid(interactor) and not interactor.dead:
			return interactor
	return null


func _create_prompt() -> Label3D:
	var prompt := Label3D.new()
	prompt.name = "Prompt"
	prompt.text = _get_action_prompt()
	prompt.font_size = 56
	prompt.outline_size = 12
	prompt.pixel_size = 0.01
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.no_depth_test = true
	prompt.position.y = prompt_height
	return prompt


func _get_action_prompt() -> String:
	var action := _get_dialogue_input_action()
	if not InputMap.has_action(action):
		return String(action)
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return String(action)
	var primary_event: InputEvent = events.front()
	if primary_event is InputEventKey:
		var key_event := primary_event as InputEventKey
		if key_event.physical_keycode:
			return key_event.as_text_physical_keycode()
		return key_event.as_text_keycode()
	return primary_event.as_text()


func _get_dialogue_input_action() -> StringName:
	# Dialogic owns the project-wide action; the plugin's documented fallback is
	# dialogic_default_action. NPCs never define a key binding themselves.
	return ProjectSettings.get_setting(
		"dialogic/text/input_action", &"dialogic_default_action"
	) as StringName


func _on_body_entered(body: Node3D) -> void:
	_register_interactor(body)
	_refresh_input()


func _on_body_exited(body: Node3D) -> void:
	if body is Player:
		_interactors.erase(body as Player)
	_refresh_input()


func _register_interactor(body: Node3D) -> void:
	if body is Player and not _interactors.has(body):
		_interactors.append(body)


func _refresh_input() -> void:
	var can_interact := _enabled and _get_interactor() != null
	set_process_unhandled_input(can_interact)
	if is_instance_valid(_prompt):
		_prompt.visible = can_interact
