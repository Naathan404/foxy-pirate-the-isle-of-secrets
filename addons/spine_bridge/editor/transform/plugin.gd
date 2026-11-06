@tool
extends EditorPlugin

const SPINE_SPRITE_SCRIPT_PATH := "res://addons/spine_bridge/scripts/spine_sprite.gd"
const FALLBACK_RECT := Rect2(-64.0, -64.0, 128.0, 128.0)
const TRANSFORM_EPSILON := 0.000000000001
const HANDLE_COUNT := 8
const GizmoMath = preload("res://addons/spine_bridge/editor/transform/transform_math.gd")

enum DragMode { NONE, MOVE_PENDING, MOVE, RESIZE }

var _spine_transform_mode := true
var _mode_button: Button
var _hover_handle := -1
var _drag_mode := DragMode.NONE
var _drag_handle := -1
var _drag_node: Node2D
var _drag_start_transform := Transform2D()
var _drag_start_node_canvas_transform := Transform2D()
var _drag_start_canvas_transform := Transform2D()
var _drag_start_mouse := Vector2()
var _drag_mouse := Vector2.ZERO
var _drag_bounds := Rect2()
var _canvas_control: Control
var _selecting := false


func _enter_tree() -> void:
	_mode_button = Button.new()
	_mode_button.text = "Spine 变换"
	_mode_button.tooltip_text = "名字：Spine Transform\n说明：在 2D 画布中移动 SpineSprite，并使用 8 个控制点缩放。"
	_mode_button.toggle_mode = true
	_mode_button.button_pressed = _spine_transform_mode
	_mode_button.focus_mode = Control.FOCUS_NONE
	_mode_button.toggled.connect(_on_transform_mode_toggled)
	add_control_to_container(CONTAINER_CANVAS_EDITOR_MENU, _mode_button)
	set_force_draw_over_forwarding_enabled()
	get_editor_interface().get_selection().selection_changed.connect(_on_selection_changed)
	scene_changed.connect(_on_scene_changed)
	set_process_input(true)
	set_process(true)
	update_overlays()


func _exit_tree() -> void:
	_cancel_drag(true)
	get_editor_interface().get_selection().selection_changed.disconnect(_on_selection_changed)
	if _mode_button != null and is_instance_valid(_mode_button):
		remove_control_from_container(CONTAINER_CANVAS_EDITOR_MENU, _mode_button)
		_mode_button.queue_free()
	_mode_button = null


func _on_transform_mode_toggled(enabled: bool) -> void:
	_spine_transform_mode = enabled
	if not enabled:
		_cancel_drag(true)
	update_overlays()


func _handles(object: Object) -> bool:
	return _is_spine_sprite(object)


func _edit(_object: Object) -> void:
	# Inspector activation is not a drag lifecycle event. In particular,
	# edit_node() can deliver this after the initiating mouse press has returned.
	update_overlays()


func _clear() -> void:
	update_overlays()


func _on_scene_changed(_root: Node) -> void:
	_cancel_drag(true)


func _on_selection_changed() -> void:
	if not _selecting:
		_validate_drag.call_deferred()
	update_overlays()


func _validate_drag() -> void:
	if _drag_mode != DragMode.NONE and (not is_instance_valid(_drag_node) \
			or _get_selected_sprite() != _drag_node or not _is_transform_editable(_drag_node)):
		_cancel_drag(true)


func _process(_delta: float) -> void:
	if _drag_mode != DragMode.NONE:
		_validate_drag()
		if not get_window().has_focus():
			_cancel_drag(true)


func _is_canvas_hovered() -> bool:
	if not Rect2(Vector2.ZERO, _canvas_control.size).has_point(_canvas_control.get_local_mouse_position()):
		return false
	# Do not steal clicks from floating editors or controls covering the canvas.
	var hovered := get_viewport().gui_get_hovered_control()
	return hovered == _canvas_control


func _input(event: InputEvent) -> void:
	if not _spine_transform_mode or not is_instance_valid(_canvas_control):
		return
	# Capture before CanvasItemEditor's selection/drag handler. Once captured,
	# keep receiving release/cancel even outside the canvas or after _clear().
	if _drag_mode == DragMode.NONE:
		if not _canvas_control.is_visible_in_tree() or not event is InputEventMouse:
			return
		if not _is_canvas_hovered():
			return
		if Input.is_key_pressed(KEY_SPACE):
			return
	var local_event := event
	if event is InputEventMouse:
		local_event = event.xformed_by(_canvas_control.get_global_transform_with_canvas().affine_inverse())
	if _route_canvas_input(local_event):
		get_viewport().set_input_as_handled()


func _forward_canvas_force_draw_over_viewport(overlay: Control) -> void:
	_canvas_control = overlay
	_draw_transform_box(overlay)


func _draw_transform_box(overlay: Control) -> void:
	if not _spine_transform_mode:
		return
	var node := _get_selected_sprite()
	if node == null or not _is_transform_editable(node):
		return

	var bounds := _drag_bounds if node == _drag_node else _get_edit_rect(node)
	var transform := _get_editor_node_transform(node)
	var corners := _get_corners(bounds, transform)
	var box_color := Color(0.35, 0.75, 1.0, 0.95)
	for index in range(4):
		overlay.draw_line(corners[index], corners[(index + 1) % 4], box_color, 2.0, true)

	var handles := _get_handle_points(bounds, transform)
	var handle_size := 8.0 * get_editor_interface().get_editor_scale()
	for index in range(HANDLE_COUNT):
		var size := handle_size if index != _hover_handle else handle_size + 2.0
		var rect := Rect2(handles[index] - Vector2.ONE * size * 0.5, Vector2.ONE * size)
		overlay.draw_rect(rect, Color.WHITE, true)
		overlay.draw_rect(rect, box_color, false, 1.0, true)


func _forward_canvas_gui_input(event: InputEvent) -> bool:
	# Input is owned by _input, independently of the inspector's plugin list.
	return false


func _route_canvas_input(event: InputEvent) -> bool:
	if not _spine_transform_mode:
		if _drag_mode != DragMode.NONE:
			_cancel_drag(true)
		return false

	if _drag_mode != DragMode.NONE and _get_selected_sprite() != _drag_node:
		_cancel_drag(true)
		return false

	if event is InputEventKey and event.keycode == KEY_SHIFT and _drag_mode == DragMode.RESIZE:
		_apply_drag(_drag_mouse, event.pressed)
		update_overlays()
		return true

	if event is InputEventKey and event.pressed and not event.echo \
			and (event.keycode == KEY_ESCAPE or event.is_action_pressed("ui_cancel")):
		if _drag_mode != DragMode.NONE:
			_cancel_drag(true)
			return true
		return false

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if _drag_mode != DragMode.NONE:
				_cancel_drag(true)
				return true
			return false

		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _drag_mode != DragMode.NONE:
					return true
				if event.alt_pressed or event.ctrl_pressed or event.meta_pressed:
					return false
				return _begin_left_drag(event.position)
			if _drag_mode != DragMode.NONE:
				if not is_instance_valid(_drag_node) or not _is_transform_editable(_drag_node):
					_cancel_drag(true)
					return true
				_apply_drag(event.position, event.shift_pressed)
				_finish_drag()
				return true
			return false

	if event is InputEventMouseMotion:
		if _drag_mode != DragMode.NONE:
			if _drag_node == null or not is_instance_valid(_drag_node):
				_cancel_drag(true)
				return true
			if not _is_transform_editable(_drag_node):
				_cancel_drag(true)
				return true
			_apply_drag(event.position, event.shift_pressed)
			update_overlays()
			return true

		var node := _get_selected_sprite()
		if node == null or not _is_transform_editable(node):
			_hover_handle = -1
			update_overlays()
			return false
		_hover_handle = _find_handle(node, event.position)
		update_overlays()
		return false

	return false


func _begin_left_drag(mouse_position: Vector2) -> bool:
	var selected := _get_selected_sprite()
	if selected != null and _is_transform_editable(selected):
		var handle := _find_handle(selected, mouse_position)
		if handle >= 0 and not _has_blocker_above(selected, mouse_position):
			_begin_resize(selected, handle, mouse_position)
			return true

	var hit := _get_spine_sprite_at_position(mouse_position)
	if hit == null:
		return false
	_begin_move(hit, mouse_position)
	if not _select_sprite(hit):
		_cancel_drag(true)
		return false
	return true


func _get_selected_sprite() -> Node2D:
	var selection := get_editor_interface().get_selection()
	if selection == null:
		return null
	var nodes := selection.get_selected_nodes()
	if nodes.size() == 1 and _is_spine_sprite(nodes[0]):
		return nodes[0]
	return null


func _select_sprite(node: Node2D) -> bool:
	if not _is_transform_editable(node):
		return false
	var selection := get_editor_interface().get_selection()
	if _get_selected_sprite() == node:
		return true
	_selecting = true
	selection.clear()
	selection.add_node(node)
	get_editor_interface().edit_node(node)
	_selecting = false
	return true


func _get_spine_sprite_at_position(mouse_position: Vector2) -> Node2D:
	var root := get_editor_interface().get_edited_scene_root()
	if root == null:
		return null

	var items: Array[CanvasItem] = []
	_collect_canvas_items(root, items)

	# Pick the topmost editable SpineSprite using effective z_index and the
	# scene order as a deterministic tie-breaker.
	var target: Node2D
	var target_order := -1
	for order in range(items.size()):
		var item := items[order]
		if not _is_spine_sprite(item):
			continue
		var node := item as Node2D
		if node == null or not _is_transform_editable(node):
			continue
		if not _canvas_item_contains_point(item, mouse_position):
			continue
		if target == null or _canvas_item_is_above(item, target, order, target_order):
			target = node
			target_order = order

	if target == null:
		return null

	# A visible CanvasItem with known geometry above the candidate owns this click.
	for order in range(items.size()):
		var item := items[order]
		if item == target or not _canvas_item_is_above(item, target, order, target_order):
			continue
		if _canvas_item_contains_point(item, mouse_position):
			return null
	return target


func _has_blocker_above(target: CanvasItem, mouse_position: Vector2) -> bool:
	var root := get_editor_interface().get_edited_scene_root()
	if root == null:
		return true
	var items: Array[CanvasItem] = []
	_collect_canvas_items(root, items)
	var target_order := items.find(target)
	for order in range(items.size()):
		var item := items[order]
		if item != target and _canvas_item_is_above(item, target, order, target_order) \
				and _canvas_item_contains_point(item, mouse_position):
			return true
	return false


func _collect_canvas_items(node: Node, result: Array[CanvasItem]) -> void:
	# A SubViewport has its own canvas and editor hit-test space. Until that
	# coordinate chain is implemented, never expose its children as candidates.
	if node is Viewport:
		return
	for child in node.get_children():
		if child is CanvasItem and child.show_behind_parent:
			_collect_canvas_items(child, result)
	if node is CanvasItem:
		result.append(node)
	for child in node.get_children():
		if child is CanvasItem and child.show_behind_parent:
			continue
		_collect_canvas_items(child, result)


func _canvas_item_is_above(first: CanvasItem, second: CanvasItem, first_order: int, second_order: int) -> bool:
	var first_layer := first.get_canvas_layer_node()
	var second_layer := second.get_canvas_layer_node()
	var first_layer_index := first_layer.layer if first_layer != null else 0
	var second_layer_index := second_layer.layer if second_layer != null else 0
	if first_layer_index != second_layer_index:
		return first_layer_index > second_layer_index
	# Separate canvases at the same layer and Y-sorted branches cannot be
	# ordered from a flat scene traversal. Treat overlapping geometry as a
	# blocker rather than selecting through it.
	if first_layer != second_layer:
		return true
	var first_z := _get_effective_z_index(first)
	var second_z := _get_effective_z_index(second)
	if first_z == second_z and (_has_y_sort_ancestor(first) or _has_y_sort_ancestor(second)):
		return true
	return first_z > second_z or (first_z == second_z and first_order > second_order)


func _has_y_sort_ancestor(item: CanvasItem) -> bool:
	var parent := item.get_parent() as CanvasItem
	while parent != null:
		if parent.y_sort_enabled:
			return true
		parent = parent.get_parent() as CanvasItem
	return false


func _get_effective_z_index(item: CanvasItem) -> int:
	var parent := item.get_parent() as CanvasItem
	if item.z_as_relative and not item.is_set_as_top_level() and parent != null:
		return clampi(item.z_index + _get_effective_z_index(parent), -4096, 4096)
	return item.z_index


func _canvas_item_contains_point(item: CanvasItem, mouse_position: Vector2) -> bool:
	if not item.is_visible_in_tree() or not _is_canvas_item_transform_usable(item):
		return false

	var transform := _get_editor_canvas_item_transform(item)
	var local_mouse := transform.affine_inverse() * mouse_position
	var local_rect = _get_canvas_item_local_rect(item)
	if local_rect is Rect2:
		return local_rect.has_point(local_mouse)

	# Custom drawing without exposed geometry cannot participate in hit testing.
	return false


func _get_canvas_item_local_rect(item: CanvasItem):
	if _is_spine_sprite(item):
		var spine_node := item as Node2D
		return _get_edit_rect(spine_node) if spine_node != null else null

	if item is Control:
		return Rect2(Vector2.ZERO, (item as Control).size)
	if item.has_method("get_rect"):
		var rect = item.call("get_rect")
		if rect is Rect2:
			return rect
	if item is Polygon2D:
		return _get_points_rect((item as Polygon2D).polygon)
	if item is Line2D:
		return _get_points_rect((item as Line2D).points).grow((item as Line2D).width * 0.5)
	# Plain transform containers have no rendered geometry.
	if item.get_class() == "Node2D" and item.get_script() == null:
		return Rect2()
	return null


func _get_points_rect(points: PackedVector2Array):
	if points.is_empty():
		return Rect2()
	var minimum := points[0]
	var maximum := points[0]
	for point in points:
		minimum.x = minf(minimum.x, point.x)
		minimum.y = minf(minimum.y, point.y)
		maximum.x = maxf(maximum.x, point.x)
		maximum.y = maxf(maximum.y, point.y)
	return Rect2(minimum, maximum - minimum)


func _is_spine_sprite(object: Object) -> bool:
	if not object is Node2D:
		return false
	var script := object.get_script() as Script
	while script != null:
		if script.resource_path == SPINE_SPRITE_SCRIPT_PATH:
			return true
		script = script.get_base_script()
	return false


func _is_transform_editable(node: Node2D) -> bool:
	if node == null or not is_instance_valid(node) or not _is_spine_sprite(node):
		return false
	if not node.is_inside_tree() or not node.is_visible_in_tree():
		return false
	var root := get_editor_interface().get_edited_scene_root()
	if root == null or (node != root and not root.is_ancestor_of(node)):
		return false
	var ancestor: Node = node
	while ancestor != null:
		if ancestor is SubViewport:
			return false
		if ancestor == root:
			break
		ancestor = ancestor.get_parent()
	if bool(node.get_meta("_edit_lock_", false)):
		return false
	if bool(node.get_meta("_edit_group_", false)):
		return false
	if _get_edit_group_ancestor(node) != null:
		return false
	if not _is_node_transform_usable(node):
		return false

	if node == root or node.owner == root:
		return true
	var owner := node.owner
	return owner != null and root.has_method("is_editable_instance") \
			and bool(root.call("is_editable_instance", owner))


func _get_edit_group_ancestor(node: Node) -> Node:
	var root := get_editor_interface().get_edited_scene_root()
	var current := node.get_parent()
	while current != null:
		if bool(current.get_meta("_edit_group_", false)):
			return current
		if current == root:
			break
		current = current.get_parent()
	return null


func _is_invertible_transform(transform: Transform2D) -> bool:
	return transform.is_finite() and absf(transform.determinant()) > TRANSFORM_EPSILON


func _is_node_transform_usable(node: Node2D) -> bool:
	return _is_canvas_item_transform_usable(node)


func _is_canvas_item_transform_usable(item: CanvasItem) -> bool:
	if not _is_invertible_transform(_get_editor_canvas_transform()):
		return false
	if not _is_invertible_transform(item.get_global_transform_with_canvas()):
		return false
	var viewport := item.get_viewport()
	return viewport == null or _is_invertible_transform(viewport.get_canvas_transform())


func _get_editor_canvas_transform() -> Transform2D:
	var viewport := get_editor_interface().get_editor_viewport_2d()
	if viewport == null:
		return Transform2D()
	return viewport.global_canvas_transform


func _get_editor_node_transform(node: Node2D) -> Transform2D:
	return _get_editor_canvas_item_transform(node)


func _get_editor_canvas_item_transform(item: CanvasItem) -> Transform2D:
	return _get_editor_canvas_transform() * _get_node_canvas_transform(item)


func _get_node_canvas_transform(item: CanvasItem) -> Transform2D:
	# Remove the scene viewport's canvas transform, then apply the editor's
	# canvas transform. This keeps CanvasLayer canvas transforms while still
	# matching the 2D editor's pan and zoom.
	var transform := item.get_global_transform_with_canvas()
	var viewport := item.get_viewport()
	if viewport != null:
		var viewport_transform := viewport.get_canvas_transform()
		if not _is_invertible_transform(viewport_transform):
			return Transform2D()
		transform = viewport_transform.affine_inverse() * transform
	return transform


func _get_edit_rect(node: Node2D) -> Rect2:
	# SpineSprite.get_bounds() already returns y-down Godot canvas
	# coordinates (spine-cpp is configured with Bone::yDown = true).
	var bounds: Dictionary = node.call("get_bounds")
	if bounds.is_empty():
		return FALLBACK_RECT

	var rect := Rect2(
		float(bounds.get("x", 0.0)),
		float(bounds.get("y", 0.0)),
		float(bounds.get("width", 0.0)),
		float(bounds.get("height", 0.0)))
	if not rect.is_finite() or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return FALLBACK_RECT
	return rect


func _get_corners(bounds: Rect2, transform: Transform2D) -> PackedVector2Array:
	return PackedVector2Array([
		transform * bounds.position,
		transform * Vector2(bounds.end.x, bounds.position.y),
		transform * bounds.end,
		transform * Vector2(bounds.position.x, bounds.end.y),
	])


func _get_handle_points(bounds: Rect2, transform: Transform2D) -> PackedVector2Array:
	var center := bounds.get_center()
	var local_points := PackedVector2Array([
		bounds.position,
		Vector2(center.x, bounds.position.y),
		Vector2(bounds.end.x, bounds.position.y),
		Vector2(bounds.end.x, center.y),
		bounds.end,
		Vector2(center.x, bounds.end.y),
		Vector2(bounds.position.x, bounds.end.y),
		Vector2(bounds.position.x, center.y),
	])
	var points := PackedVector2Array()
	for point in local_points:
		points.append(transform * point)
	return points


func _find_handle(node: Node2D, mouse_position: Vector2) -> int:
	var transform := _get_editor_node_transform(node)
	var points := _get_handle_points(_get_edit_rect(node), transform)
	var closest := -1
	var closest_distance := 12.0 * get_editor_interface().get_editor_scale()
	for index in range(points.size()):
		var distance := points[index].distance_to(mouse_position)
		if distance <= closest_distance:
			closest = index
			closest_distance = distance
	if closest < 0:
		# The entire edge is draggable, not just its midpoint square.
		for index in [1, 3, 5, 7]:
			var point := Geometry2D.get_closest_point_to_segment(mouse_position,
				points[index - 1], points[(index + 1) % HANDLE_COUNT])
			var distance := point.distance_to(mouse_position)
			if distance <= 5.0 * get_editor_interface().get_editor_scale() and distance < closest_distance:
				closest = index
				closest_distance = distance
	return closest


func _begin_resize(node: Node2D, handle: int, mouse_position: Vector2) -> void:
	_begin_drag(node, mouse_position)
	_drag_mode = DragMode.RESIZE
	_drag_handle = handle
	_hover_handle = handle


func _begin_move(node: Node2D, mouse_position: Vector2) -> void:
	_begin_drag(node, mouse_position)
	_drag_mode = DragMode.MOVE_PENDING


func _begin_drag(node: Node2D, mouse_position: Vector2) -> void:
	_drag_node = node
	_drag_handle = -1
	_hover_handle = -1
	_drag_start_transform = node.transform
	_drag_start_node_canvas_transform = _get_node_canvas_transform(node)
	_drag_start_canvas_transform = _get_editor_canvas_transform() * _drag_start_node_canvas_transform
	_drag_start_mouse = mouse_position
	_drag_mouse = mouse_position
	_drag_bounds = _get_edit_rect(node)


func _apply_drag(mouse_position: Vector2, shift_pressed: bool) -> void:
	_drag_mouse = mouse_position
	if _drag_node == null or not is_instance_valid(_drag_node):
		_cancel_drag(true)
		return
	if not _is_invertible_transform(_drag_start_transform) \
			or not _is_invertible_transform(_drag_start_node_canvas_transform) \
			or not _is_invertible_transform(_drag_start_canvas_transform):
		_cancel_drag(true)
		return

	if _drag_mode == DragMode.MOVE_PENDING:
		if mouse_position.distance_to(_drag_start_mouse) < 3.0 * get_editor_interface().get_editor_scale():
			return
		_drag_mode = DragMode.MOVE
	if _drag_mode == DragMode.MOVE:
		var inverse := _drag_start_canvas_transform.affine_inverse()
		var delta := inverse * mouse_position - inverse * _drag_start_mouse
		_drag_node.transform = _drag_start_transform * Transform2D(0.0, delta)
		return

	if _drag_mode != DragMode.RESIZE:
		return

	var inverse := _drag_start_canvas_transform.affine_inverse()
	var local_delta := inverse * mouse_position - inverse * _drag_start_mouse
	_drag_node.transform = GizmoMath.resize_transform(_drag_start_transform,
		_drag_bounds, _drag_handle, local_delta, shift_pressed, _drag_start_canvas_transform)


func _is_corner_handle(handle: int) -> bool:
	return handle in [0, 2, 4, 6]


func _finish_drag() -> void:
	if _drag_node == null or not is_instance_valid(_drag_node):
		_cancel_drag(true)
		return
	if not _is_transform_editable(_drag_node):
		_cancel_drag(true)
		return

	var final_transform := _drag_node.transform
	if not final_transform.is_equal_approx(_drag_start_transform):
		var undo_redo := get_undo_redo()
		var action_name := "移动 SpineSprite" \
				if _drag_mode == DragMode.MOVE else "缩放 SpineSprite"
		undo_redo.create_action(action_name, UndoRedo.MERGE_DISABLE, _drag_node)
		undo_redo.add_do_property(_drag_node, "transform", final_transform)
		undo_redo.add_undo_property(_drag_node, "transform", _drag_start_transform)
		undo_redo.commit_action(false)
	_clear_drag()
	update_overlays()


func _cancel_drag(restore_transform: bool) -> void:
	if restore_transform and _drag_node != null and is_instance_valid(_drag_node):
		_drag_node.transform = _drag_start_transform
	_clear_drag()
	update_overlays()


func _clear_drag() -> void:
	_drag_mode = DragMode.NONE
	_drag_handle = -1
	_drag_node = null
	_hover_handle = -1
	_drag_start_transform = Transform2D()
	_drag_start_node_canvas_transform = Transform2D()
	_drag_start_canvas_transform = Transform2D()
	_drag_start_mouse = Vector2()
	_drag_bounds = Rect2()


func _get_handle_axes(handle: int) -> Vector2:
	match handle:
		0:
			return Vector2(-1.0, -1.0)
		1:
			return Vector2(0.0, -1.0)
		2:
			return Vector2(1.0, -1.0)
		3:
			return Vector2(1.0, 0.0)
		4:
			return Vector2(1.0, 1.0)
		5:
			return Vector2(0.0, 1.0)
		6:
			return Vector2(-1.0, 1.0)
		7:
			return Vector2(-1.0, 0.0)
	return Vector2.ZERO


func _get_opposite_anchor(bounds: Rect2, handle: int) -> Vector2:
	match handle:
		0:
			return bounds.end
		1:
			return Vector2(bounds.get_center().x, bounds.end.y)
		2:
			return Vector2(bounds.position.x, bounds.end.y)
		3:
			return Vector2(bounds.position.x, bounds.get_center().y)
		4:
			return bounds.position
		5:
			return Vector2(bounds.get_center().x, bounds.position.y)
		6:
			return Vector2(bounds.end.x, bounds.position.y)
		7:
			return Vector2(bounds.end.x, bounds.get_center().y)
	return bounds.get_center()
