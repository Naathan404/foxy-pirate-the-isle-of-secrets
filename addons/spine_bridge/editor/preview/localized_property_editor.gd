@tool
extends EditorProperty

## Localized editor widgets for the Spine node and skeleton-data resource.

var _property_name := ""
var _property_type := TYPE_NIL
var _hint_type := PROPERTY_HINT_NONE
var _hint_string := ""
var _resource_type := "Resource"
var _control: Control
var _updating := false
var _last_line_edit_value := ""


func _init(property_name: String = "", property_type: int = TYPE_NIL,
		hint_type: int = PROPERTY_HINT_NONE, hint_string: String = "") -> void:
	_property_name = property_name
	_property_type = property_type
	_hint_type = hint_type
	_hint_string = hint_string
	_resource_type = hint_string if hint_type == PROPERTY_HINT_RESOURCE_TYPE \
			and not hint_string.is_empty() else "Resource"
	_build_control()


func _build_control() -> void:
	match _property_type:
		TYPE_BOOL:
			var check := CheckBox.new()
			check.text = "启用"
			check.toggled.connect(_on_bool_changed)
			_control = check
		TYPE_INT:
			if _hint_type == PROPERTY_HINT_ENUM:
				_control = _make_enum_option()
			else:
				_control = _make_number_input()
		TYPE_FLOAT:
			_control = _make_preview_time_input() if _property_name == "preview_time" \
					else _make_number_input()
		TYPE_COLOR:
			var picker := ColorPickerButton.new()
			picker.color_changed.connect(_on_color_changed)
			_control = picker
		TYPE_OBJECT:
			var picker := EditorResourcePicker.new()
			picker.base_type = _resource_type
			picker.resource_changed.connect(_on_resource_changed)
			_control = picker
		TYPE_STRING:
			if _hint_type == PROPERTY_HINT_ENUM and not _hint_string.is_empty():
				_control = _make_string_option()
			else:
				var line_edit := LineEdit.new()
				line_edit.text_submitted.connect(_on_text_submitted)
				line_edit.focus_exited.connect(_commit_line_edit)
				_control = line_edit
		_:
			var fallback := Label.new()
			fallback.text = "不支持的属性类型"
			_control = fallback
	
	_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_control)
	if _control is Control:
		add_focusable(_control)


func _make_number_input() -> SpinBox:
	var spin := SpinBox.new()
	spin.step = 0.01 if _property_type == TYPE_FLOAT else 1.0
	spin.min_value = 0.0
	spin.max_value = 60.0
	if _hint_type == PROPERTY_HINT_RANGE:
		_apply_range_hint(spin)
	if _property_name == "time_scale":
		spin.min_value = -100.0
		spin.max_value = 100.0
		spin.allow_lesser = true
		spin.allow_greater = true
	elif _property_name == "playback_speed":
		spin.min_value = -100.0
		spin.max_value = 100.0
		spin.allow_lesser = true
		spin.allow_greater = true
	elif _property_name == "bones_thickness":
		spin.min_value = 0.1
		spin.max_value = 100.0
		spin.allow_greater = true
	elif _property_name == "default_mix":
		spin.min_value = 0.0
		spin.allow_lesser = false
		spin.allow_greater = true
		spin.suffix = " 秒"
	spin.value_changed.connect(_on_number_changed)
	return spin


func _make_preview_time_input() -> EditorSpinSlider:
	var slider := EditorSpinSlider.new()
	slider.step = 0.01
	if _hint_type == PROPERTY_HINT_RANGE:
		_apply_range_hint(slider)
	slider.suffix = " 秒"
	slider.value_changed.connect(_on_number_changed)
	return slider


func _apply_range_hint(spin: Range) -> void:
	var parts := _hint_string.split(",")
	if parts.size() < 2:
		return
	spin.min_value = float(parts[0])
	spin.max_value = float(parts[1])
	if parts.size() >= 3 and not parts[2].is_empty():
		spin.step = float(parts[2])
	for index in range(3, parts.size()):
		match parts[index].strip_edges():
			"or_greater":
				spin.allow_greater = true
			"or_less":
				spin.allow_lesser = true


func _make_enum_option() -> OptionButton:
	var option := OptionButton.new()
	option.fit_to_longest_item = false
	option.clip_text = true
	var names := _hint_string.split(",")
	for index in range(names.size()):
		var item_text := names[index]
		if _property_name == "update_mode":
			match index:
				0:
					item_text = "逐帧更新（Process）"
				1:
					item_text = "物理帧更新（Physics）"
				2:
					item_text = "手动更新（Manual）"
		option.add_item(item_text)
		option.set_item_metadata(index, index)
		if _property_name == "update_mode":
			option.set_item_tooltip(index, _update_mode_item_tooltip(index))
	option.item_selected.connect(_on_enum_selected)
	return option


func _make_string_option() -> OptionButton:
	var option := OptionButton.new()
	option.fit_to_longest_item = false
	option.clip_text = true
	for name in _hint_string.split(","):
		option.add_item(name)
		option.set_item_tooltip(option.item_count - 1, _string_option_tooltip(name))
	option.item_selected.connect(_on_string_selected)
	return option


func _update_mode_item_tooltip(index: int) -> String:
	match index:
		0:
			return "名字：Process\n说明：每个渲染帧推进骨架，更新间隔随帧率变化。"
		1:
			return "名字：Physics\n说明：按固定物理帧间隔推进骨架，默认每秒 60 次。"
		_:
			return "名字：Manual\n说明：停用自动推进，由脚本调用 update_skeleton(delta) 更新骨架。"


func _string_option_tooltip(option_name: String) -> String:
	if _property_name == "preview_skin":
		return "名字：%s\n说明：Spine 皮肤原始名称，用于编辑器视口预览。" % option_name
	if option_name == "-- Empty --":
		return "名字：无动画\n说明：预览默认姿势，不选择 Spine 动画。"
	if _property_name == "animation_name":
		return "名字：%s\n说明：循环播放该 Spine 动画；动画名称是骨架资源中的原始标识。" % option_name
	return "名字：%s\n说明：供编辑器视口预览使用的 Spine 动画原始名称。" % option_name


func set_localized_tooltip(tooltip: String) -> void:
	if _control != null:
		_control.tooltip_text = tooltip


static func _select_string_option(option: OptionButton, value: String) -> void:
	var selected_index := -1
	for index in range(option.item_count):
		if option.get_item_text(index) == value:
			selected_index = index
			break
	if selected_index == -1 and not value.is_empty():
		option.add_item(value)
		option.set_item_tooltip(option.item_count - 1,
				"名字：%s\n说明：当前资源中的原始名称未出现在选项列表中，暂予保留。" % value)
		selected_index = option.item_count - 1
	if selected_index >= 0:
		option.select(selected_index)
	else:
		option.select(-1)


func _update_property() -> void:
	var edited := get_edited_object()
	if edited == null or not is_instance_valid(edited) or _control == null:
		return
	var value: Variant = edited.get(_property_name)
	_updating = true
	if _control is CheckBox:
		_control.button_pressed = bool(value)
	elif _control is OptionButton:
		if _property_type == TYPE_STRING:
			_select_string_option(_control, str(value))
		else:
			_control.select(int(value))
	elif _control is Range:
		_control.value = float(value)
	elif _control is ColorPickerButton:
		_control.color = value
	elif _control is EditorResourcePicker:
		_control.edited_resource = value
	elif _control is LineEdit:
		_control.text = str(value)
		_last_line_edit_value = str(value)
	_updating = false


func _on_bool_changed(value: bool) -> void:
	if not _updating:
		emit_changed(get_edited_property(), value)


func _on_number_changed(value: float) -> void:
	if not _updating:
		emit_changed(get_edited_property(), value)


func _on_enum_selected(index: int) -> void:
	if not _updating:
		emit_changed(get_edited_property(), index)


func _on_string_selected(index: int) -> void:
	if not _updating:
		emit_changed(get_edited_property(), _control.get_item_text(index))


func _on_color_changed(value: Color) -> void:
	if not _updating:
		emit_changed(get_edited_property(), value)


func _on_resource_changed(value: Resource) -> void:
	if not _updating:
		emit_changed(get_edited_property(), value)


func _on_text_submitted(_value: String) -> void:
	_commit_line_edit()


func _commit_line_edit() -> void:
	if _updating or not (_control is LineEdit):
		return
	var value: String = _control.text
	if value == _last_line_edit_value:
		return
	_last_line_edit_value = value
	emit_changed(get_edited_property(), value)


func _set_read_only(read_only: bool) -> void:
	if _control is BaseButton:
		_control.disabled = read_only
	elif _control is EditorSpinSlider:
		_control.read_only = read_only
	elif _control is SpinBox:
		_control.editable = not read_only
	elif _control is LineEdit:
		_control.editable = not read_only
	elif _control is EditorResourcePicker:
		_control.editable = not read_only
