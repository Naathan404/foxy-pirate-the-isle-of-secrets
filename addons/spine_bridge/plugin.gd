@tool
extends EditorPlugin

const PLUGIN_NAME := "spine_bridge"


func _enter_tree() -> void:
	_enable_subplugins.call_deferred()


func _enable_plugin() -> void:
	_enable_subplugins()


func _enable_subplugins() -> void:
	for plugin_path in [PLUGIN_NAME + "/editor/preview", PLUGIN_NAME + "/editor/transform"]:
		if not EditorInterface.is_plugin_enabled(plugin_path):
			EditorInterface.set_plugin_enabled(plugin_path, true)


func _disable_plugin() -> void:
	for plugin_path in [PLUGIN_NAME + "/editor/transform", PLUGIN_NAME + "/editor/preview"]:
		if EditorInterface.is_plugin_enabled(plugin_path):
			EditorInterface.set_plugin_enabled(plugin_path, false)
