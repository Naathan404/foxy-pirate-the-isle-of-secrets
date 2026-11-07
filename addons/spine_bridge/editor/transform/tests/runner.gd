@tool
extends "res://addons/spine_bridge/editor/transform/plugin.gd"
## Run only as the enabled plugin in an isolated headless editor project.

var failures: Array[String] = []


func _enter_tree() -> void:
	super._enter_tree()
	_run_tests.call_deferred()


func _process(_delta: float) -> void:
	# A headless test window deliberately has no focus.
	pass


func _is_spine_sprite(object: Object) -> bool:
	return object is Node2D and str(object.name).begins_with("Character")


func _get_edit_rect(_node: Node2D) -> Rect2:
	return Rect2(-50, -40, 100, 80)


func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
		push_error(label)


func _mouse_button(position: Vector2, pressed: bool, button := MOUSE_BUTTON_LEFT) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = button
	event.pressed = pressed
	return event


func _run_tests() -> void:
	await get_tree().process_frame
	var scene := Node2D.new()
	scene.name = "Fixture"
	var character := Node2D.new()
	character.name = "Character"
	scene.add_child(character)
	character.owner = scene
	var packed := PackedScene.new()
	packed.pack(scene)
	ResourceSaver.save(packed, "res://fixture.tscn")
	scene.free()
	get_editor_interface().open_scene_from_path("res://fixture.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	scene = get_editor_interface().get_edited_scene_root()
	if scene == null:
		push_error("Fixture did not open")
		get_tree().quit(1)
		return
	character = scene.get_node("Character")
	_on_transform_mode_toggled(true)
	var start := _get_editor_node_transform(character) * Vector2.ZERO
	var initial := character.global_transform
	_check(_route_canvas_input(_mouse_button(start, true)), "Interior press captured")
	_check(_get_selected_sprite() == character, "Interior press selects")
	_edit(character)
	_clear()
	await get_tree().process_frame
	_check(_drag_mode == DragMode.MOVE_PENDING, "Selection/edit callbacks preserve captured press")
	var motion := InputEventMouseMotion.new()
	motion.position = start + Vector2(30, 20)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	_check(_route_canvas_input(motion), "Interior motion captured")
	_check(not character.global_transform.is_equal_approx(initial), "MOVE changes transform")
	var manager := get_undo_redo()
	var history := manager.get_history_undo_redo(manager.get_object_history_id(character))
	var version := history.get_version()
	_route_canvas_input(_mouse_button(motion.position, false))
	var moved := character.global_transform
	_check(history.get_version() == version + 1, "Release creates one action")
	_route_canvas_input(_mouse_button(motion.position, false))
	_check(history.get_version() == version + 1, "Duplicate release creates no action")
	history.undo()
	_check(character.global_transform.is_equal_approx(initial), "Undo MOVE")
	history.redo()
	_check(character.global_transform.is_equal_approx(moved), "Redo MOVE")
	character.global_transform = initial
	version = history.get_version()
	_route_canvas_input(_mouse_button(start, true))
	_route_canvas_input(_mouse_button(start, false))
	_check(history.get_version() == version, "Click without drag has no Undo")
	for cancel_button in [false, true]:
		_route_canvas_input(_mouse_button(start, true))
		_route_canvas_input(motion)
		if cancel_button:
			_route_canvas_input(_mouse_button(motion.position, true, MOUSE_BUTTON_RIGHT))
		else:
			var escape := InputEventKey.new()
			escape.pressed = true
			escape.keycode = KEY_ESCAPE
			_route_canvas_input(escape)
		_check(character.global_transform.is_equal_approx(initial), "Cancel restores MOVE")
		_check(history.get_version() == version, "Cancel has no Undo")
	# All eight handles retain the opposite anchor, with and without Shift.
	for handle in range(HANDLE_COUNT):
		for shift in [false, true]:
			character.transform = Transform2D(0.3, Vector2(1.3, 0.7), 0.15, Vector2(10, 20))
			var original := character.global_transform
			var bounds := _get_edit_rect(character)
			var anchor := _get_opposite_anchor(bounds, handle)
			var points := _get_handle_points(bounds, _get_editor_node_transform(character))
			_begin_resize(character, handle, points[handle])
			_apply_drag(points[handle] + Vector2(25, 15), shift)
			_check((character.global_transform * anchor).is_equal_approx(original * anchor), "Fixed anchor %s Shift=%s" % [handle, shift])
			var relative := original.affine_inverse() * character.global_transform
			if not _is_corner_handle(handle):
				var axes := _get_handle_axes(handle)
				_check(is_equal_approx(relative.x.x if axes.x == 0 else relative.y.y, 1.0), "Edge single axis %s" % handle)
			elif shift:
				_check(is_equal_approx(relative.x.x, relative.y.y), "Corner aspect ratio %s" % handle)
			_cancel_drag(true)
	# A resize is one transaction, including modifier changes and an off-center grab.
	character.transform = initial
	var resize_points := _get_handle_points(_get_edit_rect(character), _get_editor_node_transform(character))
	var grab := resize_points[4] + Vector2(2, -2)
	_begin_resize(character, 4, grab)
	_apply_drag(grab, false)
	_check(character.transform.is_equal_approx(initial), "Off-center grab does not jump")
	_apply_drag(grab + Vector2(35, 10), false)
	var free_transform := character.transform
	var shift_event := InputEventKey.new()
	shift_event.keycode = KEY_SHIFT
	shift_event.pressed = true
	_route_canvas_input(shift_event)
	_check(is_equal_approx(character.scale.x, character.scale.y), "Shift updates without mouse motion")
	shift_event.pressed = false
	_route_canvas_input(shift_event)
	_check(character.transform.is_equal_approx(free_transform), "Releasing Shift restores free resize")
	version = history.get_version()
	_route_canvas_input(_mouse_button(grab + Vector2(35, 10), false))
	_check(history.get_version() == version + 1, "Resize release creates one action")
	history.undo()
	_check(character.transform.is_equal_approx(initial), "Undo resize")
	history.redo()
	_check(character.transform.is_equal_approx(free_transform), "Redo resize")
	for right_click in [false, true]:
		_begin_resize(character, 4, grab)
		_apply_drag(grab + Vector2(20, 15), false)
		if right_click:
			_route_canvas_input(_mouse_button(grab, true, MOUSE_BUTTON_RIGHT))
		else:
			var escape := InputEventKey.new()
			escape.keycode = KEY_ESCAPE
			escape.pressed = true
			_route_canvas_input(escape)
		_check(character.transform.is_equal_approx(free_transform), "Cancel restores resize")
	# Exercise global input coordinate conversion and release outside the canvas.
	var saved_canvas := _canvas_control
	var input_canvas := Control.new()
	get_editor_interface().get_base_control().add_child(input_canvas)
	input_canvas.position = Vector2(120, 80)
	input_canvas.size = Vector2(200, 150)
	_canvas_control = input_canvas
	character.transform = initial
	start = _get_editor_node_transform(character) * Vector2.ZERO
	_begin_move(character, start)
	var release_position := start + Vector2(260, 180)
	version = history.get_version()
	_input(_mouse_button(input_canvas.get_global_transform_with_canvas() * release_position, false))
	_check(_drag_mode == DragMode.NONE, "Global release ends capture outside canvas")
	_check((_get_editor_node_transform(character) * Vector2.ZERO).is_equal_approx(release_position), "Global input converted to canvas space")
	_check(history.get_version() == version + 1, "Global release commits once")
	_canvas_control = saved_canvas
	input_canvas.queue_free()
	character.transform = initial
	start = _get_editor_node_transform(character) * Vector2.ZERO
	for metadata in ["_edit_lock_", "_edit_group_"]:
		character.set_meta(metadata, true)
		_check(not _begin_left_drag(start), "Protected character %s" % metadata)
		character.remove_meta(metadata)
	scene.set_meta("_edit_group_", true)
	_check(not _is_transform_editable(character), "Group ancestor protected")
	scene.remove_meta("_edit_group_")
	var sprite := Sprite2D.new()
	var texture := GradientTexture2D.new()
	texture.width = 200
	texture.height = 200
	sprite.texture = texture
	scene.add_child(sprite)
	sprite.owner = scene
	_check(_get_spine_sprite_at_position(start) == null, "Upper Sprite blocks interior")
	_check(not _begin_left_drag(_get_handle_points(_get_edit_rect(character), _get_editor_node_transform(character))[0]), "Upper Sprite blocks handle")
	sprite.z_index = -1
	_check(_get_spine_sprite_at_position(start) == character, "Lower Sprite does not block")
	sprite.free()
	var control := Control.new()
	control.position = Vector2(-40, -30)
	control.size = Vector2(80, 60)
	scene.add_child(control)
	_check(_get_spine_sprite_at_position(start) == null, "Control local rect blocks")
	control.free()
	var other := Node2D.new()
	scene.add_child(other)
	_begin_move(character, start)
	_apply_drag(start + Vector2(25, 25), false)
	get_editor_interface().get_selection().clear()
	get_editor_interface().get_selection().add_node(other)
	await get_tree().process_frame
	_check(_drag_mode == DragMode.NONE and character.global_transform.is_equal_approx(initial), "External selection cancels")
	var viewport := SubViewport.new()
	scene.add_child(viewport)
	var nested := Node2D.new()
	nested.name = "CharacterNested"
	viewport.add_child(nested)
	nested.owner = scene
	_check(not _is_transform_editable(nested), "SubViewport excluded")
	print("Spine Transform focused tests: ", "PASS" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)
