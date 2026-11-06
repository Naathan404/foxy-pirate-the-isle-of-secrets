@tool
class_name SpineSprite3D
extends Node3D

## SB-26：官方实验性 SpineSprite3D 的本地 GDScript 外观层。
## 内部共享运行脚本负责 Spine 实例、AnimationState、事件和更新阶段；
## 本节点把同一版本中立 render_commands 转成原生 MeshInstance3D，避免
## SubViewport 纹理中转。26B 在此补齐插槽挂载、深度/透明和材质边界；
## 26C 补齐可选灯光、atlas 法线、PBR 参数、阴影和定向诊断；26D
## 本轮补齐官方动态预览属性及保存/重开所需的编辑器状态；完整
## AnimationPlayer/SpineAnimationTrack 仍归 SB-19/20。

signal animation_started(spine_sprite: SpineSprite3D, animation_state: SpineAnimationState, track_entry: SpineTrackEntry)
signal animation_interrupted(spine_sprite: SpineSprite3D, animation_state: SpineAnimationState, track_entry: SpineTrackEntry)
signal animation_ended(spine_sprite: SpineSprite3D, animation_state: SpineAnimationState, track_entry: SpineTrackEntry)
signal animation_completed(spine_sprite: SpineSprite3D, animation_state: SpineAnimationState, track_entry: SpineTrackEntry)
signal animation_disposed(spine_sprite: SpineSprite3D, animation_state: SpineAnimationState, track_entry: SpineTrackEntry)
signal animation_event(spine_sprite: SpineSprite3D, animation_state: SpineAnimationState, track_entry: SpineTrackEntry, event: SpineEvent)

signal before_animation_state_update(spine_sprite: SpineSprite3D)
signal before_animation_state_apply(spine_sprite: SpineSprite3D)
signal before_world_transforms_change(spine_sprite: SpineSprite3D)
signal world_transforms_changed(spine_sprite: SpineSprite3D)
signal _internal_spine_objects_invalidated()

const _SHADERS := preload("res://addons/spine_bridge/scripts/spine_render_shaders_3d.gd")
const _SLOT_NODE_3D := preload("res://addons/spine_bridge/scripts/spine_slot_node_3d.gd")
const _CORE_SCRIPT := preload("res://addons/spine_bridge/scripts/spine_sprite_core.gd")
const _PREVIEW_EMPTY_ANIMATION := "-- Empty --"

enum CullMode {
	CULL_DISABLED,
	CULL_BACK,
	CULL_FRONT,
}

enum ShadowCasting {
	SHADOW_CASTING_OFF,
	SHADOW_CASTING_ON,
	SHADOW_CASTING_DOUBLE_SIDED,
	SHADOW_CASTING_SHADOWS_ONLY,
}

@export var skeleton_data_res: SpineSkeletonDataResource = null:
	set(value):
		_disconnect_skeleton_data()
		skeleton_data_res = value
		_connect_skeleton_data()
		if _core != null:
			_core.skeleton_data = value
		_emit_internal_invalidated()
		_editor_preview_dirty = true
		notify_property_list_changed()

@export var update_mode: int = _CORE_SCRIPT.UpdateMode.PROCESS:
	set(value):
		update_mode = value

@export var time_scale: float = 1.0:
	set(value):
		time_scale = value
		if _core != null:
			_core.playback_speed = value

@export var pixel_size: float = 0.01:
	set(value):
		pixel_size = maxf(value, 0.000001)
		_mark_render_dirty()

@export var slot_depth_offset: float = 0.001:
	set(value):
		slot_depth_offset = maxf(value, 0.0)
		_mark_render_dirty()

@export var camera_relative_depth: bool = true:
	set(value):
		camera_relative_depth = value
		_mark_render_dirty()

@export var depth_write_enabled: bool = true:
	set(value):
		depth_write_enabled = value
		_mark_render_dirty()

@export var alpha_cutoff: float = 0.001:
	set(value):
		alpha_cutoff = clampf(value, 0.0, 1.0)
		_mark_render_dirty()

@export var sorting_step: float = 1.0:
	set(value):
		sorting_step = maxf(value, 0.0)
		_mark_render_dirty()

@export_range(-128, 127, 1) var render_priority: int = 0:
	set(value):
		render_priority = clampi(value, -128, 127)
		_mark_render_dirty()


@export var cull_mode: CullMode = CullMode.CULL_DISABLED:
	set(value):
		cull_mode = value
		_mark_render_dirty()

@export var lighting_enabled: bool = false:
	set(value):
		lighting_enabled = value
		_mark_render_dirty()

@export var normal_map_enabled: bool = true:
	set(value):
		normal_map_enabled = value
		_mark_render_dirty()

@export var normal_map_flip_y: bool = true:
	set(value):
		normal_map_flip_y = value
		_mark_render_dirty()

@export_range(0.0, 16.0, 0.01, "or_greater") var normal_scale: float = 1.0:
	set(value):
		normal_scale = maxf(value, 0.0)
		_mark_render_dirty()

@export_range(0.0, 1.0, 0.01) var specular: float = 0.25:
	set(value):
		specular = clampf(value, 0.0, 1.0)
		_mark_render_dirty()

@export_range(0.0, 1.0, 0.01) var roughness: float = 0.65:
	set(value):
		roughness = clampf(value, 0.0, 1.0)
		_mark_render_dirty()

@export_range(0.0, 1.0, 0.01) var metallic: float = 0.0:
	set(value):
		metallic = clampf(value, 0.0, 1.0)
		_mark_render_dirty()

@export var shadow_casting: ShadowCasting = ShadowCasting.SHADOW_CASTING_OFF:
	set(value):
		shadow_casting = value
		_mark_render_dirty()

@export_range(0.0, 1.0, 0.001) var shadow_alpha_cutoff: float = 0.3:
	set(value):
		shadow_alpha_cutoff = clampf(value, 0.0, 1.0)
		_mark_render_dirty()

## 官方 3D 只暴露 normal/additive 两组 ShaderMaterial 覆盖；
## multiply/screen 由 _SHADERS 统一回退到 normal 并警告。
@export var normal_material: ShaderMaterial = null:
	set(value):
		normal_material = value
		_mark_render_dirty()

@export var additive_material: ShaderMaterial = null:
	set(value):
		additive_material = value
		_mark_render_dirty()

var _core = null
## 运行时自动播放开关；暂停意图不序列化，场景实例化时默认播放。
var is_playing := true
var _mesh_nodes: Array[MeshInstance3D] = []
var _shadow_mesh_nodes: Array[MeshInstance3D] = []
var _render_dirty := true
var _sorting_commands: Array = []
var _sorting_rows: Array = []
var _sorting_items: Array = []
var _sorting_origins := PackedVector3Array()
var _sorting_active := false
var _sorting_check_queued := false
var _preview_skin := "Default"
var _preview_animation := _PREVIEW_EMPTY_ANIMATION
var _preview_frame := false
var _preview_time := 0.0
var _editor_preview_dirty := true
var _local_aabb := AABB()
var _has_local_aabb := false
var _mesh_builds := 0
var _material_builds := 0
var _shadow_material_builds := 0
var _vertex_uploads := 0
var _index_uploads := 0
var _tangent_uploads := 0
var _attribute_uploads := 0


func _mark_render_dirty() -> void:
	_render_dirty = true


func _enter_tree() -> void:
	set_process(true)
	set_physics_process(true)
	_ensure_core()
	_connect_skeleton_data()
	_render_dirty = true
	_editor_preview_dirty = true


func _exit_tree() -> void:
	set_process(false)
	set_physics_process(false)
	_disconnect_skeleton_data()
	_clear_render_items()
	# The internal runtime node remains owned by this node and releases its
	# instance in its own _exit_tree; it is retained for re-entry.


func _process(delta: float) -> void:
	if update_mode == _CORE_SCRIPT.UpdateMode.PROCESS:
		_advance_automatic(delta)
	if Engine.is_editor_hint() and _editor_preview_dirty:
		_apply_editor_preview()
	if _render_dirty:
		_refresh_render_items()
	elif _sorting_active:
		_queue_sorting_check()


func _physics_process(delta: float) -> void:
	if update_mode == _CORE_SCRIPT.UpdateMode.PHYSICS:
		_advance_automatic(delta)
	if Engine.is_editor_hint() and _editor_preview_dirty:
		_apply_editor_preview()
	if _render_dirty:
		_refresh_render_items()
	elif _sorting_active:
		_queue_sorting_check()


func _ensure_core() -> void:
	if _core != null:
		return
	_core = _CORE_SCRIPT.new()
	_core.name = "_SpineSpriteCore3D"
	_core.auto_play = false
	_core.fit_to_viewport = false
	_core.render_enabled = false
	_core.update_mode = _CORE_SCRIPT.UpdateMode.MANUAL
	_core.playback_speed = time_scale
	_core._set_event_dispatch_owner(self)
	_core._set_animation_event_dispatch_enabled(true)
	_core.animation_started.connect(_on_animation_started)
	_core.animation_interrupted.connect(_on_animation_interrupted)
	_core.animation_ended.connect(_on_animation_ended)
	_core.animation_completed.connect(_on_animation_completed)
	_core.animation_disposed.connect(_on_animation_disposed)
	_core.animation_event.connect(_on_animation_event)
	_core.before_animation_state_update.connect(_on_before_animation_state_update)
	_core.before_animation_state_apply.connect(_on_before_animation_state_apply)
	_core.before_world_transforms_change.connect(_on_before_world_transforms_change)
	_core.world_transforms_changed.connect(_on_world_transforms_changed)
	add_child(_core, false, Node.INTERNAL_MODE_BACK)
	_editor_preview_dirty = true
	if skeleton_data_res != null:
		_core.skeleton_data = skeleton_data_res


func _connect_skeleton_data() -> void:
	if skeleton_data_res != null and not skeleton_data_res.changed.is_connected(_on_skeleton_data_changed):
		skeleton_data_res.changed.connect(_on_skeleton_data_changed)


func _disconnect_skeleton_data() -> void:
	if skeleton_data_res != null and skeleton_data_res.changed.is_connected(_on_skeleton_data_changed):
		skeleton_data_res.changed.disconnect(_on_skeleton_data_changed)


func _on_skeleton_data_changed() -> void:
	_emit_internal_invalidated()
	_render_dirty = true
	_editor_preview_dirty = true
	notify_property_list_changed()


func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	if skeleton_data_res == null or not skeleton_data_res.is_skeleton_data_loaded():
		return properties
	var usage := PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_STORAGE
	var skin_names: PackedStringArray = skeleton_data_res.get_skin_names()
	var animation_names: PackedStringArray = skeleton_data_res.get_animation_names()
	var animation_options := PackedStringArray([_PREVIEW_EMPTY_ANIMATION])
	animation_options.append_array(animation_names)
	properties.append({
		"name": "preview_skin",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM if not skin_names.is_empty() else PROPERTY_HINT_NONE,
		"hint_string": ",".join(skin_names),
		"usage": usage,
	})
	properties.append({
		"name": "preview_animation",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(animation_options),
		"usage": usage,
	})
	properties.append({
		"name": "preview_frame",
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": "",
		"usage": usage,
	})
	var duration := 0.0
	if not _preview_animation.is_empty() and _preview_animation != _PREVIEW_EMPTY_ANIMATION:
		var animation := skeleton_data_res.get_animation_object(_preview_animation)
		if animation != null:
			duration = maxf(float(animation.get_duration()), 0.0)
	properties.append({
		"name": "preview_time",
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0.0,%s,0.01" % duration,
		"usage": usage,
	})
	return properties


func _get(property: StringName) -> Variant:
	if property == &"preview_skin":
		return _preview_skin
	if property == &"preview_animation":
		return _preview_animation
	if property == &"preview_frame":
		return _preview_frame
	if property == &"preview_time":
		return _preview_time
	return null


func _set(property: StringName, value: Variant) -> bool:
	if property == &"preview_skin":
		_preview_skin = str(value)
		_editor_preview_dirty = true
		notify_property_list_changed()
		return true
	if property == &"preview_animation":
		_preview_animation = str(value)
		_editor_preview_dirty = true
		notify_property_list_changed()
		return true
	if property == &"preview_frame":
		_preview_frame = bool(value)
		_editor_preview_dirty = true
		return true
	if property == &"preview_time":
		_preview_time = maxf(float(value), 0.0)
		_editor_preview_dirty = true
		return true
	return false


func _apply_editor_preview() -> void:
	if not Engine.is_editor_hint():
		return
	if _core == null or not _core.is_loaded() or skeleton_data_res == null:
		_editor_preview_dirty = true
		return
	var skeleton: SpineSkeleton = get_skeleton()
	var state: SpineAnimationState = get_animation_state()
	if skeleton == null or state == null:
		_editor_preview_dirty = true
		return
	_editor_preview_dirty = false
	var skin: SpineSkin = null
	if not _preview_skin.is_empty() and _preview_skin != "Default":
		skin = skeleton_data_res.get_skin_object(_preview_skin)
	skeleton.set_skin(skin)
	skeleton.set_to_setup_pose()
	state.clear_track(0)
	if not _preview_animation.is_empty() and _preview_animation != _PREVIEW_EMPTY_ANIMATION:
		var entry: SpineTrackEntry = state.set_animation(_preview_animation, true, 0)
		if entry != null:
			entry.set_mix_duration(0.0)
			if _preview_frame:
				entry.set_time_scale(0.0)
				entry.set_track_time(_preview_time)
		else:
			state.set_empty_animation(0, 0.0)
	else:
		state.set_empty_animation(0, 0.0)
	state.update(0.0)
	state.apply(skeleton)
	skeleton_data_res.update_world_transform(_core._instance_handle, 0.0)
	_render_dirty = true
	_refresh_render_items()


func _emit_internal_invalidated() -> void:
	_render_dirty = true
	if is_inside_tree():
		emit_signal("_internal_spine_objects_invalidated")
		call_deferred("_refresh_render_items")


func _advance_automatic(delta: float) -> void:
	if _core != null:
		if Engine.is_editor_hint():
			_core._update_skeleton_for_editor_preview(delta)
		elif is_playing:
			_core.update_skeleton(delta)


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


## 停止本外观层的自动动画推进；显式 update_skeleton() 仍可手动推进。
func pause() -> void:
	is_playing = false


## 恢复本外观层的自动动画推进，不补入暂停期间的时间或事件。
func resume() -> void:
	is_playing = true


## 应用暂停期间的静态姿态写入并刷新 3D 渲染端及已连接的骨架消费者。
func refresh_pose() -> void:
	if _core != null:
		_core.refresh_pose()


func set_pixel_size(value: float) -> void:
	pixel_size = value


func get_pixel_size() -> float:
	return pixel_size


func set_slot_depth_offset(value: float) -> void:
	slot_depth_offset = value


func get_slot_depth_offset() -> float:
	return slot_depth_offset


func set_camera_relative_depth(value: bool) -> void:
	camera_relative_depth = value


func get_camera_relative_depth() -> bool:
	return camera_relative_depth


func set_depth_write_enabled(value: bool) -> void:
	depth_write_enabled = value


func get_depth_write_enabled() -> bool:
	return depth_write_enabled


func set_alpha_cutoff(value: float) -> void:
	alpha_cutoff = value


func get_alpha_cutoff() -> float:
	return alpha_cutoff


func set_sorting_step(value: float) -> void:
	sorting_step = value


func get_sorting_step() -> float:
	return sorting_step


func set_render_priority(value: int) -> void:
	render_priority = value


func get_render_priority() -> int:
	return render_priority


func set_cull_mode(value: int) -> void:
	cull_mode = value


func get_cull_mode() -> int:
	return cull_mode


func set_lighting_enabled(value: bool) -> void:
	lighting_enabled = value


func get_lighting_enabled() -> bool:
	return lighting_enabled


func set_normal_map_enabled(value: bool) -> void:
	normal_map_enabled = value


func get_normal_map_enabled() -> bool:
	return normal_map_enabled


func set_normal_map_flip_y(value: bool) -> void:
	normal_map_flip_y = value


func get_normal_map_flip_y() -> bool:
	return normal_map_flip_y


func set_normal_scale(value: float) -> void:
	normal_scale = value


func get_normal_scale() -> float:
	return normal_scale


func set_specular(value: float) -> void:
	specular = value


func get_specular() -> float:
	return specular


func set_roughness(value: float) -> void:
	roughness = value


func get_roughness() -> float:
	return roughness


func set_metallic(value: float) -> void:
	metallic = value


func get_metallic() -> float:
	return metallic


func set_shadow_casting(value: int) -> void:
	shadow_casting = value


func get_shadow_casting() -> int:
	return shadow_casting


func set_shadow_alpha_cutoff(value: float) -> void:
	shadow_alpha_cutoff = value


func get_shadow_alpha_cutoff() -> float:
	return shadow_alpha_cutoff


func set_normal_material(value: ShaderMaterial) -> void:
	normal_material = value


func get_normal_material() -> ShaderMaterial:
	return normal_material


func set_additive_material(value: ShaderMaterial) -> void:
	additive_material = value


func get_additive_material() -> ShaderMaterial:
	return additive_material


func update_skeleton(delta: float) -> void:
	if _core != null:
		# SB-20：与 2D 对齐；官方 SpineSprite3D::update_skeleton 在编辑器内同样可用，
		# 使 AnimationPlayer 驱动的 MANUAL 3D 角色可显式取样。
		if Engine.is_editor_hint():
			_core._update_skeleton_for_editor_preview(delta)
		else:
			_core.update_skeleton(delta)
	if _render_dirty:
		_refresh_render_items()


## SB-20（SB20-R1）：SpineAnimationTrack 编辑器 scrub 的定步重放入口。
## 仅供编辑器内的轨道回调调用；语义见共享运行脚本同名方法。
func replay_editor_scrub_time(entry: SpineTrackEntry, state: SpineAnimationState,
		target: float) -> void:
	if _core != null:
		_core.replay_editor_scrub_time(entry, state, target)


## SB-20（SB20-R1）：轨道输入未变时保持上一次采样结果；仅让本帧零增量收尾。
func hold_editor_scrub_time() -> void:
	if _core != null:
		_core.hold_editor_scrub_time()


func get_skeleton() -> SpineSkeleton:
	return _core.get_skeleton() if _core != null else null


func get_animation_state() -> SpineAnimationState:
	return _core.get_animation_state() if _core != null else null


## Use core playback for providers without the optional TrackEntry object API (3.8).
func set_animation(animation: String, loop: bool = true, track: int = 0) -> bool:
	if _core == null:
		return false
	var accepted: bool = _core.set_animation(animation, loop, track)
	if accepted:
		is_playing = true
	return accepted


func new_skin(name: String) -> SpineSkin:
	if skeleton_data_res == null:
		return null
	return skeleton_data_res.create_skin_object(name)


func get_aabb() -> AABB:
	if _render_dirty and is_inside_tree():
		_refresh_render_items()
	return _local_aabb if _has_local_aabb else AABB()


func is_loaded() -> bool:
	return _core != null and _core.is_loaded()


func get_slot_names() -> PackedStringArray:
	return _core.get_slot_names() if _core != null else PackedStringArray()


func get_render_statistics() -> Dictionary:
	var active_batches := 0
	var active_vertices := 0
	var active_indices := 0
	var materials := 0
	var shadow_materials := 0
	var shadow_instances := 0
	var vertex_capacity := 0
	var index_capacity := 0
	for mesh_node in _mesh_nodes:
		if not is_instance_valid(mesh_node) or mesh_node.mesh == null:
			continue
		if mesh_node.visible:
			active_batches += 1
		if mesh_node.material_override != null:
			materials += 1
		if mesh_node.mesh.get_surface_count() <= 0:
			continue
		var arrays: Array = mesh_node.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		active_vertices += vertices.size()
		active_indices += indices.size()
		vertex_capacity += vertices.size()
		index_capacity += indices.size()
	for shadow_node in _shadow_mesh_nodes:
		if not is_instance_valid(shadow_node) or shadow_node.mesh == null:
			continue
		if shadow_node.visible:
			shadow_instances += 1
		if shadow_node.material_override != null:
			shadow_materials += 1
	return {
		"batches": active_batches,
		"vertices": active_vertices,
		"indices": active_indices,
		"batch_pool": _mesh_nodes.size(),
		"materials": materials,
		"shadow_materials": shadow_materials,
		"shadow_instances": shadow_instances,
		"shadow_instance_pool": _shadow_mesh_nodes.size(),
		"mesh_builds": _mesh_builds,
		"index_uploads": _index_uploads,
		"vertex_uploads": _vertex_uploads,
		"tangent_uploads": _tangent_uploads,
		"attribute_uploads": _attribute_uploads,
		"material_builds": _material_builds,
		"shared_shaders": _SHADERS.get_shared_shader_count(),
		"vertex_capacity": vertex_capacity,
		"index_capacity": index_capacity,
	}


static func get_depth_shader_code() -> String:
	return """
// Shared depth helper for SpineSprite3D custom spatial shaders.
uniform bool spine_camera_relative_depth = true;
uniform float spine_alpha_cutoff = 0.001;

vec3 spine_apply_camera_depth(vec3 position, vec3 origin,
		vec3 plane_normal, vec3 camera_position) {
	if (spine_camera_relative_depth &&
			dot(camera_position - origin, plane_normal) < 0.0) {
		position.z = -position.z;
	}
	return position;
}

void spine_apply_alpha_cutoff(float alpha) {
	if (alpha <= 0.0 || alpha < spine_alpha_cutoff) {
		discard;
	}
}
"""


func _refresh_render_items() -> void:
	if not is_instance_valid(self) or not is_inside_tree():
		return
	_render_dirty = false
	if _core == null or not _core.is_loaded() or skeleton_data_res == null:
		_clear_render_items()
		return
	var commands: Array = _core._get_render_commands_for_external_consumer()
	var rows: Array = _core._get_slot_render_rows_for_external_consumer()
	var depth_indices := _get_command_depth_indices(commands, rows)
	_sync_mesh_pool(commands.size())
	_local_aabb = AABB()
	_has_local_aabb = false
	for i in range(_mesh_nodes.size()):
		var mesh_node := _mesh_nodes[i]
		if i >= commands.size():
			mesh_node.visible = false
			mesh_node.mesh = null
			mesh_node.material_override = null
			_shadow_mesh_nodes[i].visible = false
			_shadow_mesh_nodes[i].mesh = null
			_shadow_mesh_nodes[i].material_override = null
			continue
		var command: Dictionary = commands[i]
		var page_index := int(command.get("page_index", -1))
		var texture: Texture2D = skeleton_data_res.get_page_texture(page_index)
		var indices: PackedInt32Array = command.get("indices", PackedInt32Array())
		var positions: PackedVector2Array = command.get("positions", PackedVector2Array())
		if texture == null or indices.is_empty() or positions.is_empty():
			mesh_node.visible = false
			mesh_node.mesh = null
			mesh_node.material_override = null
			_shadow_mesh_nodes[i].visible = false
			_shadow_mesh_nodes[i].mesh = null
			_shadow_mesh_nodes[i].material_override = null
			continue
		mesh_node.mesh = _make_mesh(command, int(depth_indices[i]))
		var source_material: Material = _get_material_for_command(command)
		var options := _render_options(page_index)
		mesh_node.material_override = _SHADERS.make_material(
				command, texture, options, source_material)
		_material_builds += 1
		mesh_node.position = Vector3.ZERO
		mesh_node.cast_shadow = _shadow_casting_setting() if source_material != null \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh_node.visible = source_material != null \
				or shadow_casting != ShadowCasting.SHADOW_CASTING_SHADOWS_ONLY
		var shadow_node := _shadow_mesh_nodes[i]
		shadow_node.mesh = mesh_node.mesh
		shadow_node.position = Vector3.ZERO
		shadow_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		var generated_shadow := source_material == null \
				and shadow_casting != ShadowCasting.SHADOW_CASTING_OFF
		if generated_shadow:
			var shadow_options: Dictionary = options
			if shadow_casting == ShadowCasting.SHADOW_CASTING_DOUBLE_SIDED:
				shadow_options = options.duplicate()
				shadow_options["cull_mode"] = CullMode.CULL_DISABLED
			shadow_node.material_override = _SHADERS.make_shadow_material(
					command, texture, shadow_options)
		_shadow_material_builds += 1 if generated_shadow else 0
		if not generated_shadow:
			shadow_node.material_override = null
		shadow_node.visible = generated_shadow
		_update_aabb(positions, int(depth_indices[i]))
	_sync_slot_nodes(rows)
	_apply_render_sorting(commands, rows)


func _get_command_depth_indices(commands: Array, rows: Array) -> PackedInt32Array:
	var row_indices: Dictionary = {}
	for i in range(rows.size()):
		var row: Dictionary = rows[i]
		var name := str(row.get("slot_name", ""))
		if not name.is_empty():
			row_indices[name] = i
	var result := PackedInt32Array()
	result.resize(commands.size())
	for i in range(commands.size()):
		var command: Dictionary = commands[i]
		var name := str(command.get("slot_name", ""))
		result[i] = int(row_indices.get(name, i))
	return result


func _sync_mesh_pool(target: int) -> void:
	while _mesh_nodes.size() < target:
		var mesh_node := MeshInstance3D.new()
		mesh_node.name = "_SpineDraw3D_%d" % _mesh_nodes.size()
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh_node.sorting_use_aabb_center = false
		add_child(mesh_node, false, Node.INTERNAL_MODE_FRONT)
		_mesh_nodes.append(mesh_node)
		var shadow_node := MeshInstance3D.new()
		shadow_node.name = "_SpineShadow3D_%d" % _shadow_mesh_nodes.size()
		shadow_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		shadow_node.sorting_use_aabb_center = false
		shadow_node.visible = false
		add_child(shadow_node, false, Node.INTERNAL_MODE_FRONT)
		_shadow_mesh_nodes.append(shadow_node)
	while _mesh_nodes.size() > target:
		_mesh_nodes.pop_back().free()
		_shadow_mesh_nodes.pop_back().free()


func _clear_render_items() -> void:
	for mesh_node in _mesh_nodes:
		if is_instance_valid(mesh_node):
			mesh_node.visible = false
			mesh_node.mesh = null
			mesh_node.material_override = null
			mesh_node.sorting_offset = 0.0
	for shadow_node in _shadow_mesh_nodes:
		if is_instance_valid(shadow_node):
			shadow_node.visible = false
			shadow_node.mesh = null
			shadow_node.material_override = null
			shadow_node.sorting_offset = 0.0
	for node in _get_slot_nodes():
		node._reset_sorting()
		node._sync_slot({}, -1, 0.0)
	_sorting_commands = []
	_sorting_rows = []
	_sorting_items.clear()
	_sorting_origins = PackedVector3Array()
	_sorting_active = false
	_local_aabb = AABB()
	_has_local_aabb = false


func _make_mesh(command: Dictionary, command_index: int) -> ArrayMesh:
	var positions_2d: PackedVector2Array = command.get("positions", PackedVector2Array())
	var uvs: PackedVector2Array = command.get("uvs", PackedVector2Array())
	var colors: PackedColorArray = command.get("colors", PackedColorArray())
	if colors.size() != positions_2d.size():
		colors = PackedColorArray()
		colors.resize(positions_2d.size())
		for i in range(colors.size()):
			colors[i] = Color.WHITE
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	positions.resize(positions_2d.size())
	normals.resize(positions_2d.size())
	for i in range(positions_2d.size()):
		# Spine's yDown world coordinates map to Godot 3D's up-positive Y.
		positions[i] = Vector3(
				positions_2d[i].x * pixel_size,
				-positions_2d[i].y * pixel_size,
				float(command_index) * slot_depth_offset)
		normals[i] = Vector3(0.0, 0.0, 1.0)
	var tangents := _build_tangents(positions, uvs,
			command.get("indices", PackedInt32Array()), normals)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	var dark: Color = command.get("dark_color", Color.BLACK)
	var has_dark := bool(command.get("has_dark", false))
	var light_custom := PackedFloat32Array()
	var dark_custom := PackedFloat32Array()
	light_custom.resize(colors.size() * 4)
	dark_custom.resize(colors.size() * 4)
	for i in range(colors.size()):
		var light := colors[i]
		var base := i * 4
		light_custom[base] = light.r
		light_custom[base + 1] = light.g
		light_custom[base + 2] = light.b
		light_custom[base + 3] = light.a
		dark_custom[base] = dark.r if has_dark else 0.0
		dark_custom[base + 1] = dark.g if has_dark else 0.0
		dark_custom[base + 2] = dark.b if has_dark else 0.0
		dark_custom[base + 3] = 1.0
	arrays[Mesh.ARRAY_CUSTOM0] = light_custom
	arrays[Mesh.ARRAY_CUSTOM1] = dark_custom
	arrays[Mesh.ARRAY_INDEX] = command.get("indices", PackedInt32Array())
	var mesh := ArrayMesh.new()
	var format := Mesh.ARRAY_FORMAT_CUSTOM0 | Mesh.ARRAY_FORMAT_CUSTOM1
	format |= Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	format |= Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, format)
	_mesh_builds += 1
	_vertex_uploads += positions.size()
	_index_uploads += int(command.get("indices", PackedInt32Array()).size())
	_tangent_uploads += positions.size()
	_attribute_uploads += positions.size()
	return mesh


func _build_tangents(positions: PackedVector3Array, uvs: PackedVector2Array,
		indices: PackedInt32Array, normals: PackedVector3Array) -> PackedFloat32Array:
	var tangent_accum := PackedVector3Array()
	var bitangent_accum := PackedVector3Array()
	tangent_accum.resize(positions.size())
	bitangent_accum.resize(positions.size())
	for i in range(positions.size()):
		tangent_accum[i] = Vector3.ZERO
		bitangent_accum[i] = Vector3.ZERO
	for i in range(0, indices.size() - 2, 3):
		var i0 := int(indices[i])
		var i1 := int(indices[i + 1])
		var i2 := int(indices[i + 2])
		if i0 < 0 or i1 < 0 or i2 < 0 \
				or i0 >= positions.size() or i1 >= positions.size() \
				or i2 >= positions.size() or i0 >= uvs.size() \
				or i1 >= uvs.size() or i2 >= uvs.size():
			continue
		var edge1 := positions[i1] - positions[i0]
		var edge2 := positions[i2] - positions[i0]
		var delta_uv1 := uvs[i1] - uvs[i0]
		var delta_uv2 := uvs[i2] - uvs[i0]
		var denominator := delta_uv1.x * delta_uv2.y \
				- delta_uv2.x * delta_uv1.y
		if absf(denominator) <= 0.0000001:
			continue
		var inverse := 1.0 / denominator
		var tangent := (edge1 * delta_uv2.y - edge2 * delta_uv1.y) * inverse
		var bitangent := (edge2 * delta_uv1.x - edge1 * delta_uv2.x) * inverse
		for index in [i0, i1, i2]:
			tangent_accum[index] += tangent
			bitangent_accum[index] += bitangent
	var tangents := PackedFloat32Array()
	tangents.resize(positions.size() * 4)
	for i in range(positions.size()):
		var normal := normals[i]
		if normal.length_squared() <= 0.000000000001:
			normal = Vector3(0.0, 0.0, 1.0)
		else:
			normal = normal.normalized()
		var tangent := tangent_accum[i]
		if tangent.length_squared() <= 0.000000000001:
			tangent = Vector3(1.0, 0.0, 0.0)
		else:
			tangent = tangent - normal * normal.dot(tangent)
			if tangent.length_squared() <= 0.000000000001:
				tangent = Vector3(1.0, 0.0, 0.0)
			else:
				tangent = tangent.normalized()
		var handedness := 1.0
		if bitangent_accum[i].length_squared() > 0.000000000001 \
				and normal.cross(tangent).dot(bitangent_accum[i]) < 0.0:
			handedness = -1.0
		var base := i * 4
		tangents[base] = tangent.x
		tangents[base + 1] = tangent.y
		tangents[base + 2] = tangent.z
		tangents[base + 3] = handedness
	return tangents


func _update_aabb(positions: PackedVector2Array, command_index: int) -> void:
	for point_2d in positions:
		var point := Vector3(
			point_2d.x * pixel_size,
			-point_2d.y * pixel_size,
			float(command_index) * slot_depth_offset)
		if not _has_local_aabb:
			_local_aabb = AABB(point, Vector3.ZERO)
			_has_local_aabb = true
		else:
			_local_aabb = _local_aabb.expand(point)
		if camera_relative_depth and not is_zero_approx(point.z):
			_local_aabb = _local_aabb.expand(Vector3(point.x, point.y, -point.z))


func _render_options(page_index: int = -1) -> Dictionary:
	var normal_texture: Texture2D = null
	if lighting_enabled and normal_map_enabled and skeleton_data_res != null \
			and page_index >= 0:
		normal_texture = skeleton_data_res.get_page_normal_texture(page_index)
	return {
		"camera_relative_depth": camera_relative_depth,
		"depth_write_enabled": depth_write_enabled,
		"alpha_cutoff": alpha_cutoff,
		"render_priority": render_priority,
		"cull_mode": int(cull_mode),
		"lighting_enabled": lighting_enabled,
		"normal_map_enabled": normal_map_enabled,
		"normal_map_flip_y": normal_map_flip_y,
		"normal_scale": normal_scale,
		"specular": specular,
		"roughness": roughness,
		"metallic": metallic,
		"shadow_alpha_cutoff": shadow_alpha_cutoff,
		"normal_texture": normal_texture,
	}


func _shadow_casting_setting() -> int:
	match shadow_casting:
		ShadowCasting.SHADOW_CASTING_ON:
			return GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		ShadowCasting.SHADOW_CASTING_DOUBLE_SIDED:
			return GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		ShadowCasting.SHADOW_CASTING_SHADOWS_ONLY:
			return GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	return GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _get_slot_nodes() -> Array:
	var result: Array = []
	for child in get_children():
		if child is _SLOT_NODE_3D:
			result.append(child)
	return result


func _find_slot_node_3d(name: String) -> Node:
	for node in _get_slot_nodes():
		if node.get_slot_name() == name:
			return node
	return null


func _get_material_for_command(command: Dictionary) -> Material:
	var blend := int(command.get("blend_mode", 0))
	var normalized_blend := 1 if blend == 1 else 0
	var slot_name := str(command.get("slot_name", ""))
	if not slot_name.is_empty():
		var slot_node := _find_slot_node_3d(slot_name)
		if slot_node != null:
			var slot_material: Material = slot_node.get_material_for_blend(normalized_blend)
			if slot_material != null:
				return slot_material
	return additive_material if normalized_blend == 1 else normal_material


func _sync_slot_nodes(rows: Array) -> void:
	var rows_by_name: Dictionary = {}
	for i in range(rows.size()):
		var row: Dictionary = rows[i]
		var name := str(row.get("slot_name", ""))
		if not name.is_empty():
			rows_by_name[name] = {"row": row, "draw_index": i}
	var setup_names := get_slot_names()
	for node in _get_slot_nodes():
		var name: String = str(node.get_slot_name())
		if rows_by_name.has(name):
			var record: Dictionary = rows_by_name[name]
			node._sync_slot(record["row"], setup_names.find(name),
					float(record["draw_index"]) * slot_depth_offset)
		else:
			node._sync_slot({}, setup_names.find(name), 0.0)


func _build_render_sorting_items(commands: Array, rows: Array) -> Array:
	var nodes_by_name: Dictionary = {}
	for node in _get_slot_nodes():
		var name: String = str(node.get_slot_name())
		if not nodes_by_name.has(name):
			nodes_by_name[name] = []
		nodes_by_name[name].append(node)
	var items: Array = []
	var consumed: Dictionary = {}
	for row in rows:
		var row_name := str(row.get("slot_name", ""))
		for i in range(commands.size()):
			if consumed.has(i):
				continue
			var command: Dictionary = commands[i]
			if str(command.get("slot_name", "")) != row_name:
				continue
			items.append({"mesh_index": i})
			consumed[i] = true
		if nodes_by_name.has(row_name):
			for node in nodes_by_name[row_name]:
				for geometry in node._get_geometry_instances():
					items.append({"slot": node, "geometry": geometry})
	for i in range(commands.size()):
		if not consumed.has(i):
			items.append({"mesh_index": i})
	return items


func _apply_render_sorting(commands: Array, rows: Array) -> void:
	_sorting_commands = commands
	_sorting_rows = rows
	var items := _build_render_sorting_items(commands, rows)
	if items.is_empty():
		_sorting_items.clear()
		_sorting_origins = PackedVector3Array()
		_sorting_active = false
		return
	var offsets := PackedFloat32Array()
	offsets.resize(items.size())
	var origins := PackedVector3Array()
	origins.resize(items.size())
	var previous_origin := global_transform.origin
	var current_offset := 0.0
	var has_previous := false
	var geometry_items := 0
	for index in range(items.size()):
		var item: Dictionary = items[index]
		var origin := global_transform.origin
		var geometry: GeometryInstance3D = item.get("geometry")
		if is_instance_valid(geometry) and geometry.is_inside_tree():
			origin = geometry.global_transform.origin
			geometry_items += 1
		origins[index] = origin
		if has_previous:
			current_offset += previous_origin.distance_to(origin) + sorting_step
		offsets[index] = current_offset
		previous_origin = origin
		has_previous = true
	var center := current_offset * 0.5
	for index in range(items.size()):
		var item: Dictionary = items[index]
		var value := offsets[index] - center
		var mesh_index := int(item.get("mesh_index", -1))
		if mesh_index >= 0:
			_set_mesh_sorting(mesh_index, value)
			continue
		var geometry: GeometryInstance3D = item.get("geometry")
		var slot: Node = item.get("slot")
		if is_instance_valid(geometry) and is_instance_valid(slot):
			slot._set_geometry_sorting_offset(geometry, value)
	_sorting_items = items
	_sorting_origins = origins
	_sorting_active = geometry_items > 0


## SB26B-R5：MANUAL/静态角色的后代或祖先世界变换、depth_camera 跟随
## 变化不会触发角色重绘，这里在每帧绘制前按缓存排序输入检查世界原点。
func _queue_sorting_check() -> void:
	if _sorting_check_queued:
		return
	_sorting_check_queued = true
	call_deferred("_flush_sorting_check")


func _flush_sorting_check() -> void:
	_sorting_check_queued = false
	if not _sorting_active or _render_dirty or not is_inside_tree():
		return
	if _sorting_origins_changed():
		_apply_render_sorting(_sorting_commands, _sorting_rows)


func _sorting_origins_changed() -> bool:
	for index in range(_sorting_items.size()):
		var item: Dictionary = _sorting_items[index]
		var origin := global_transform.origin
		if item.has("geometry"):
			# 缓存项可能已被释放，先用 Variant 做存活检查再转换类型。
			var object: Variant = item.get("geometry")
			if not is_instance_valid(object):
				return true
			var geometry := object as GeometryInstance3D
			if geometry == null:
				return true
			if geometry.is_inside_tree():
				origin = geometry.global_transform.origin
		if not origin.is_equal_approx(_sorting_origins[index]):
			return true
	return false


func _set_mesh_sorting(index: int, value: float) -> void:
	if index < 0 or index >= _mesh_nodes.size():
		return
	var mesh_node := _mesh_nodes[index]
	if not is_instance_valid(mesh_node):
		return
	mesh_node.sorting_offset = value
	mesh_node.sorting_use_aabb_center = false
	if index < _shadow_mesh_nodes.size():
		var shadow_node := _shadow_mesh_nodes[index]
		if is_instance_valid(shadow_node):
			shadow_node.sorting_offset = value
			shadow_node.sorting_use_aabb_center = false


func _on_animation_started(_sprite, state: SpineAnimationState, entry: SpineTrackEntry) -> void:
	animation_started.emit(self, state, entry)


func _on_animation_interrupted(_sprite, state: SpineAnimationState, entry: SpineTrackEntry) -> void:
	animation_interrupted.emit(self, state, entry)


func _on_animation_ended(_sprite, state: SpineAnimationState, entry: SpineTrackEntry) -> void:
	animation_ended.emit(self, state, entry)


func _on_animation_completed(_sprite, state: SpineAnimationState, entry: SpineTrackEntry) -> void:
	animation_completed.emit(self, state, entry)


func _on_animation_disposed(_sprite, state: SpineAnimationState, entry: SpineTrackEntry) -> void:
	animation_disposed.emit(self, state, entry)


func _on_animation_event(_sprite, state: SpineAnimationState, entry: SpineTrackEntry, event: SpineEvent) -> void:
	animation_event.emit(self, state, entry, event)


func _on_before_animation_state_update(_sprite) -> void:
	before_animation_state_update.emit(self)


func _on_before_animation_state_apply(_sprite) -> void:
	before_animation_state_apply.emit(self)


func _on_before_world_transforms_change(_sprite) -> void:
	before_world_transforms_change.emit(self)


func _on_world_transforms_changed(_sprite) -> void:
	world_transforms_changed.emit(self)
	_render_dirty = true
	_refresh_render_items()
