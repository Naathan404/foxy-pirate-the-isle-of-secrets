@tool
class_name SpineSprite
extends "res://addons/spine_bridge/scripts/spine_sprite_core.gd"

## 2D SpineSprite 节点。骨架实例、动画更新和 2D 渲染由本节点执行；
## 共享基类复用 SpineSprite 与 SpineSprite3D 的运行逻辑，不创建 2D 代理节点。
signal _internal_spine_objects_invalidated()


@export var skeleton_data_res: SpineSkeletonDataResource = null:
	set(value):
		skeleton_data_res = value
		skeleton_data = value
		if is_inside_tree():
			_internal_spine_objects_invalidated.emit()
		notify_property_list_changed()
		update_configuration_warnings()


@export var time_scale: float = 1.0:
	set(value):
		time_scale = value
		playback_speed = value


var _automatic_playback_enabled := true


func _init() -> void:
	# 动画由 AnimationState 或 SpineAnimationTrack 设置；自动时钟仍运行更新阶段。
	auto_play = false
	is_playing = true


func _enter_tree() -> void:
	_set_event_dispatch_owner(self)
	_set_animation_event_dispatch_enabled(true)
	super._enter_tree()
	is_playing = _automatic_playback_enabled


func _on_data_changed() -> void:
	super._on_data_changed()
	if is_inside_tree():
		_internal_spine_objects_invalidated.emit()


func _load_from_resource(data: SpineSkeletonDataResource) -> bool:
	var loaded := super._load_from_resource(data)
	is_playing = _automatic_playback_enabled
	return loaded


func _release() -> void:
	super._release()
	is_playing = _automatic_playback_enabled


func _advance_frame(delta: float) -> void:
	if Engine.is_editor_hint():
		advance_editor_preview(delta)
	elif is_playing:
		update_skeleton(delta)


func pause() -> void:
	_automatic_playback_enabled = false
	is_playing = false


func resume() -> void:
	_automatic_playback_enabled = true
	is_playing = true


func update_skeleton(delta: float) -> void:
	if Engine.is_editor_hint():
		_update_skeleton_for_editor_preview(delta)
	else:
		super.update_skeleton(delta)


func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	for property in super._get_property_list():
		if property.get("name") != "animation_name":
			properties.append(property)
	return properties


func _validate_property(property: Dictionary) -> void:
	# 这些是共享实现的旧属性；公开节点只保存官方名称的资源/速度。
	if property.get("name") in ["skeleton_data", "fit_to_viewport", "character_scale",
			"auto_play", "playback_speed"]:
		property["usage"] = PROPERTY_USAGE_INTERNAL


func set_skeleton_data_res(value: SpineSkeletonDataResource) -> void:
	skeleton_data_res = value


func get_skeleton_data_res() -> SpineSkeletonDataResource:
	return skeleton_data_res


func set_update_mode(value: int) -> void:
	update_mode = value


func get_update_mode() -> int:
	return update_mode


func set_time_scale(value: float) -> void:
	time_scale = value


func get_time_scale() -> float:
	return time_scale


func new_skin(name: String) -> SpineSkin:
	if skeleton_data_res == null:
		return null
	return skeleton_data_res.create_skin_object(name)
