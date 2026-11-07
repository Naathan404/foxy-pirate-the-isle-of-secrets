@tool
extends EditorProperty

## SB-13（API-EDITOR-006）：animation_mixes 行编辑器。每行包含 from/to 动画
## 下拉和 mix 时长；增删行、下拉选择和数值输入都经 EditorUndoRedoManager
## 提交整个数组，支持撤销/重做。
##
## 本地差异（已在 API 映射登记）：官方把混合配置写在共享 AnimationStateData
## 上，修改影响全部实例；本 Bridge 的资源级配置是实例创建时的模板，不改变
## 已存在实例（SB-08B）。

var _plugin: EditorPlugin
var _rows: VBoxContainer
var _add_button: Button
var _resource: SpineSkeletonDataResource
var _signature := ""


func _init(plugin: EditorPlugin = null) -> void:
	_plugin = plugin
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_rows)
	add_focusable(_rows)


func _update_property() -> void:
	var edited := get_edited_object()
	if not (edited is SpineSkeletonDataResource):
		return
	if _resource != edited or _signature != _current_signature():
		bind_resource(edited)


## 绑定/刷新资源（检查器经 _update_property 调用；定向测试直接调用）。
func bind_resource(resource: SpineSkeletonDataResource) -> void:
	_resource = resource
	_rebuild()


## 行编辑器当前行数（不含 Add Mix 按钮）。
func get_row_count() -> int:
	return _rows.get_child_count() - 1 if _add_button != null else 0


func add_mix() -> void:
	var mixes := _duplicate_mixes()
	mixes.append(SpineAnimationMix.new())
	_commit_mixes("Add Spine Animation Mix", mixes)


func delete_mix(index: int) -> void:
	var mixes := _duplicate_mixes()
	if index >= 0 and index < mixes.size():
		mixes.remove_at(index)
	_commit_mixes("Delete Spine Animation Mix", mixes)


func set_mix_field(index: int, field: String, value: Variant) -> void:
	var mixes := _duplicate_mixes()
	if index < 0 or index >= mixes.size():
		return
	var mix: SpineAnimationMix = mixes[index]
	if field == "from":
		mix.set_from(str(value))
	elif field == "to":
		mix.set_to(str(value))
	elif field == "mix":
		mix.set_mix(maxf(float(value), 0.0))
	else:
		return
	_commit_mixes("Edit Spine Animation Mix", mixes, false)


## 克隆现有条目（数组与每个 SpineAnimationMix 都复制），保证旧数组仍可作为
## 撤销快照；直接修改资源数组会让撤销无数据可比。
func _duplicate_mixes() -> Array:
	var old_mixes: Array = _resource.get_animation_mixes().duplicate()
	var new_mixes: Array = old_mixes.duplicate()
	for i in range(new_mixes.size()):
		new_mixes[i] = (old_mixes[i] as SpineAnimationMix).duplicate()
	return new_mixes


func _commit_mixes(description: String, new_mixes: Array, rebuild: bool = true) -> void:
	if _resource == null:
		return
	var old_mixes: Array = _resource.get_animation_mixes().duplicate()
	# 先手动应用，再以 execute=false 记录同一变更，避免 UndoRedo 重复执行。
	_resource.set_animation_mixes(new_mixes)
	_signature = _signature_for(new_mixes)
	var undo_redo: EditorUndoRedoManager = _get_undo_redo()
	if undo_redo != null:
		undo_redo.create_action(description, UndoRedo.MERGE_DISABLE, _resource)
		undo_redo.add_do_property(_resource, "animation_mixes", new_mixes)
		undo_redo.add_undo_property(_resource, "animation_mixes", old_mixes)
		undo_redo.commit_action(false)
	if rebuild:
		_rebuild.call_deferred()


func _get_undo_redo() -> EditorUndoRedoManager:
	if _plugin != null:
		var manager: EditorUndoRedoManager = _plugin.get_undo_redo()
		if manager != null:
			return manager
	return EditorInterface.get_editor_undo_redo()


func _rebuild() -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.free()
	_add_button = null
	var mixes: Array = _resource.get_animation_mixes() if _resource != null else []
	for i in range(mixes.size()):
		var mix := mixes[i] as SpineAnimationMix
		if mix != null:
			_rows.add_child(_make_row(i, mix))
	_add_button = Button.new()
	_add_button.text = "添加混合"
	_add_button.tooltip_text = "名字：添加混合\n说明：新增一条动画对及其混合时长配置。"
	_add_button.pressed.connect(add_mix)
	_rows.add_child(_add_button)
	_signature = _current_signature()


func _make_row(index: int, mix: SpineAnimationMix) -> HBoxContainer:
	var row := HBoxContainer.new()
	var names := _resource.get_animation_names()

	var from_option := OptionButton.new()
	from_option.fit_to_longest_item = false
	from_option.clip_text = true
	from_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fill_options(from_option, names, mix.get_from())
	from_option.tooltip_text = "名字：来源动画\n说明：动画切换时从该动画混合离开。"
	from_option.item_selected.connect(func(item: int) -> void:
		set_mix_field(index, "from", from_option.get_item_text(item)))
	row.add_child(from_option)

	var arrow := Label.new()
	arrow.text = "→"
	arrow.tooltip_text = "名字：动画切换方向\n说明：左侧动画混合到右侧动画。"
	row.add_child(arrow)

	var to_option := OptionButton.new()
	to_option.fit_to_longest_item = false
	to_option.clip_text = true
	to_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fill_options(to_option, names, mix.get_to())
	to_option.tooltip_text = "名字：目标动画\n说明：动画切换时混合进入该动画。"
	to_option.item_selected.connect(func(item: int) -> void:
		set_mix_field(index, "to", to_option.get_item_text(item)))
	row.add_child(to_option)

	var mix_spin := SpinBox.new()
	mix_spin.min_value = 0.0
	mix_spin.max_value = 60.0
	mix_spin.allow_lesser = false
	mix_spin.allow_greater = true
	mix_spin.step = 0.01
	mix_spin.value = mix.get_mix()
	mix_spin.suffix = " 秒"
	mix_spin.tooltip_text = "名字：混合时长\n说明：从来源动画过渡到目标动画所需的时间，单位为秒。"
	mix_spin.value_changed.connect(func(value: float) -> void:
		set_mix_field(index, "mix", value))
	row.add_child(mix_spin)

	var delete_button := Button.new()
	delete_button.text = "删除"
	delete_button.tooltip_text = "名字：删除混合\n说明：移除当前动画对配置。"
	delete_button.pressed.connect(func() -> void:
		delete_mix(index))
	row.add_child(delete_button)
	return row


## 资源中的动画名可能已被删除；把缺失项保留在下拉里可见，避免静默改写数据。
func _fill_options(option: OptionButton, names: PackedStringArray, current: String) -> void:
	option.clear()
	var found := false
	for name in names:
		option.add_item(name)
		option.set_item_tooltip(option.item_count - 1,
				"名字：Spine 动画名\n说明：项目骨架资源中的原始动画标识。")
		if name == current:
			found = true
	if not current.is_empty() and not found:
		option.add_item(current)
		option.set_item_tooltip(option.item_count - 1,
				"名字：缺失的 Spine 动画名\n说明：保留当前资源中不存在的原始名称，避免静默改写配置。")
	for i in range(option.item_count):
		if option.get_item_text(i) == current:
			option.select(i)
			break


func _signature_for(mixes: Array) -> String:
	var names := _resource.get_animation_names() if _resource != null else PackedStringArray()
	var parts := PackedStringArray()
	for mix in mixes:
		if mix is SpineAnimationMix:
			parts.append("%s>%s:%s" % [mix.get_from(), mix.get_to(), mix.get_mix()])
	return "%s|%s" % [",".join(names), ";".join(parts)]


func _current_signature() -> String:
	if _resource == null:
		return ""
	return _signature_for(_resource.get_animation_mixes())
