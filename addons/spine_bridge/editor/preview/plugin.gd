@tool
extends EditorPlugin

## SB-13：为 SpineSkeletonDataResource.animation_mixes 提供官方
## SpineEditorPropertyAnimationMixes 等价的行编辑器（API-EDITOR-005/006）。
## 节点预览属性本身由 SpineSprite/SpineSprite3D 的 @tool 动态属性提供，
## 此插件只负责资源检查器的混合配置 UI。
const MixInspectorPlugin := preload("res://addons/spine_bridge/editor/preview/mix_inspector_plugin.gd")

var _mix_inspector: EditorInspectorPlugin


func _enter_tree() -> void:
	_mix_inspector = MixInspectorPlugin.new()
	_mix_inspector.setup(self)
	add_inspector_plugin(_mix_inspector)


func _exit_tree() -> void:
	if _mix_inspector != null:
		remove_inspector_plugin(_mix_inspector)
		_mix_inspector = null
