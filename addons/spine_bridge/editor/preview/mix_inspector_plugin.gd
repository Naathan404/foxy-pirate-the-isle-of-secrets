@tool
extends EditorInspectorPlugin

## SB-13（API-EDITOR-005）：把 SpineSkeletonDataResource 的 animation_mixes
## 属性换成可增删行的自定义编辑器；其余属性保持默认检查器。

const MixEditorProperty := preload("res://addons/spine_bridge/editor/preview/mix_editor_property.gd")
const LocalizedEditorProperty := preload(
		"res://addons/spine_bridge/editor/preview/localized_property_editor.gd")

const RESOURCE_LABELS := {
	"atlas_res": ["图集资源", "名字：Atlas Resource\n说明：Spine 图集资源，提供角色纹理页与相关导入设置。"],
	"skeleton_file_res": ["骨架文件资源", "名字：Skeleton File Resource\n说明：已导入的 Spine 骨架文件资源（.skel 或 .spine-json）。"],
	"default_mix": ["默认混合时长", "名字：Default Mix\n说明：动画间未单独配置时使用的过渡时长，单位为秒。"],
	"animation_mixes": ["动画混合", "名字：Animation Mixes\n说明：指定动画对之间的混合时长，单位为秒；配置会应用于之后创建的实例。"],
}

const SPRITE_LABELS := {
	"skeleton_data": ["骨架数据（兼容属性）", "名字：Skeleton Data\n说明：底层骨架数据资源属性；SpineSprite 场景建议使用 Skeleton Data Resource 设置。"],
	"skeleton_data_res": ["骨架数据资源", "名字：Skeleton Data Resource\n说明：SpineSprite 使用的骨架与图集组合资源，建议多个角色实例共享。"],
	"fit_to_viewport": ["适配视口", "名字：Fit to Viewport\n说明：加载完成后自动缩放并居中骨架以适配当前视口。"],
	"character_scale": ["角色缩放", "名字：Character Scale\n说明：设置 Spine 渲染的整体缩放；1 为导出原始尺寸。"],
	"auto_play": ["自动播放", "名字：Auto Play\n说明：运行时加载骨架后是否自动开始播放；编辑器视口预览由 Preview 组控制。"],
	"animation_name": ["动画名称", "名字：Animation Name\n说明：设置运行时循环播放的 Spine 动画；留空时使用首个动画。"],
	"update_mode": ["更新模式", "名字：Update Mode\n说明：选择自动按渲染帧、物理帧推进，或由脚本手动调用 update_skeleton(delta)。"],
	"time_scale": ["时间缩放", "名字：Time Scale\n说明：动画播放速度倍率；1 为原速，0 停止推进，小于 0 可反向推进。"],
	"playback_speed": ["播放速度缩放（底层属性）", "名字：Playback Speed\n说明：底层骨架推进速度倍率；SpineSprite 建议通过 Time Scale 设置。"],
	"normal_material": ["标准混合材质", "名字：Normal Material\n说明：Spine 标准混合模式使用的覆盖材质；留空时使用内置材质。"],
	"additive_material": ["加法混合材质", "名字：Additive Material\n说明：Spine 加法混合模式使用的覆盖材质；留空时使用内置材质。"],
	"multiply_material": ["乘法混合材质", "名字：Multiply Material\n说明：Spine 乘法混合模式使用的覆盖材质；留空时使用内置材质。"],
	"root": ["根点", "名字：Root\n说明：在编辑器视口显示根骨骼标记。"],
	"root_color": ["根点颜色", "名字：Root Color\n说明：设置骨架根点调试标记的颜色。"],
	"bones": ["骨骼", "名字：Bones\n说明：在编辑器视口沿骨骼方向绘制菱形标记。"],
	"bones_color": ["骨骼颜色", "名字：Bones Color\n说明：设置骨骼调试绘制的颜色。"],
	"bones_thickness": ["骨骼粗细", "名字：Bones Thickness\n说明：设置骨骼调试标记的半宽度。"],
	"regions": ["区域附件", "名字：Regions\n说明：在编辑器视口显示区域附件的边界。"],
	"regions_color": ["区域颜色", "名字：Regions Color\n说明：设置区域附件调试边界的颜色。"],
	"meshes": ["网格附件", "名字：Meshes\n说明：在编辑器视口显示网格附件的三角形边线。"],
	"meshes_color": ["网格颜色", "名字：Meshes Color\n说明：设置网格附件调试边线的颜色。"],
	"bounding_boxes": ["边界框", "名字：Bounding Boxes\n说明：在编辑器视口显示边界框附件的轮廓。"],
	"bounding_boxes_color": ["边界框颜色", "名字：Bounding Boxes Color\n说明：设置边界框附件调试轮廓的颜色。"],
	"paths": ["路径附件", "名字：Paths\n说明：在编辑器视口显示路径附件。"],
	"paths_color": ["路径颜色", "名字：Paths Color\n说明：设置路径附件调试绘制的颜色。"],
	"clipping": ["裁剪附件", "名字：Clipping\n说明：在编辑器视口显示裁剪附件的轮廓。"],
	"paths_clipping": ["裁剪颜色", "名字：Clipping Color\n说明：设置裁剪附件调试轮廓的颜色。"],
	"preview_skin": ["预览皮肤", "名字：Preview Skin\n说明：选择编辑器视口预览使用的 Spine 皮肤。"],
	"preview_animation": ["预览动画", "名字：Preview Animation\n说明：选择编辑器视口预览使用的 Spine 动画。"],
	"preview_frame": ["固定预览帧", "名字：Preview Frame\n说明：启用后停在指定预览时间；关闭后按更新模式持续播放预览动画。"],
	"preview_time": ["预览时间", "名字：Preview Time\n说明：拖动滑条或输入秒数定位动画；先启用固定预览帧才能看到停在该时间的姿态。"],
}

var _plugin: EditorPlugin


func setup(plugin: EditorPlugin) -> void:
	_plugin = plugin


func _can_handle(object: Object) -> bool:
	return object is SpineSkeletonDataResource or object is SpineSprite


func _parse_group(object: Object, group: String) -> void:
	if not (object is SpineSprite):
		return
	if group == "调试":
		add_custom_control(_make_section_note("调试绘制仅在编辑器视口显示。",
				"名字：调试\n说明：检查骨架根点、骨骼、附件轮廓与裁剪几何的可视化选项。"))
	elif group == "Preview":
		add_custom_control(_make_section_note("设置编辑器视口中的皮肤、动画与固定帧。",
				"名字：Preview\n说明：配置 SpineSprite 的编辑器视口预览状态。"))


func _parse_property(_object: Object, _type: Variant.Type, name: String,
		hint_type: PropertyHint, hint_string: String, _usage_flags: int,
		_wide: bool) -> bool:
	if _object is SpineSkeletonDataResource:
		if name == "animation_mixes":
			var mixes_editor := MixEditorProperty.new(_plugin)
			var mix_labels: Array = RESOURCE_LABELS[name]
			_set_tooltip(mixes_editor, mix_labels[1])
			add_property_editor(name, mixes_editor, false, mix_labels[0])
			return true
		if RESOURCE_LABELS.has(name):
			_add_localized_editor(_object, name, _type, hint_type, hint_string,
					RESOURCE_LABELS[name])
			return RESOURCE_LABELS.has(name)
	if _object is SpineSprite:
		if not SPRITE_LABELS.has(name):
			return false
		if name == "normal_material":
			add_custom_control(_make_section_note("材质覆盖按 Spine 混合模式应用。",
					"名字：Materials\n说明：为标准、加法和乘法混合模式分别指定自定义材质。"))
		_add_localized_editor(_object, name, _type, hint_type, hint_string,
				SPRITE_LABELS[name])
		return true
	return false


func _add_localized_editor(object: Object, name: String, type: Variant.Type,
		hint_type: PropertyHint, hint_string: String, labels: Array) -> void:
	var editor := LocalizedEditorProperty.new(name, type, hint_type, hint_string)
	_set_tooltip(editor, labels[1])
	add_property_editor(name, editor, false, labels[0])


func _set_tooltip(control: Control, tooltip: String) -> void:
	if control.has_method("set_localized_tooltip"):
		control.call("set_localized_tooltip", tooltip)
	# EditorProperty.tooltip_text is a Godot document ID, not free-form text.
	# LocalizedEditorProperty applies the description to its child input instead.


func _make_section_note(text: String, tooltip: String) -> Label:
	var note := Label.new()
	note.text = text
	note.tooltip_text = tooltip
	return note
