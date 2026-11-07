@tool
class_name SpineSlotNode3D
extends Node3D

## SB-26B：SpineSprite3D 的 3D 插槽挂载节点。
## 节点必须是 SpineSprite3D 的直接子节点；其普通 Node3D/GeometryInstance3D
## 子树保持用户自己的局部变换，只由父角色按 draw order 设置排序偏移。

const _SPRITE3D := preload("res://addons/spine_bridge/scripts/spine_sprite_3d.gd")

@export var slot_name: String = "":
    set(value):
        slot_name = value
        _slot_index = -1
        _reset_sorting()
        _mark_parent_dirty()
        update_configuration_warnings()

@export var depth_camera: NodePath = NodePath():
    set(value):
        depth_camera = value
        set_process(not depth_camera.is_empty())
        _update_depth_only()
        update_configuration_warnings()

@export var normal_material: ShaderMaterial = null:
    set(value):
        normal_material = value
        _mark_parent_dirty()

@export var additive_material: ShaderMaterial = null:
    set(value):
        additive_material = value
        _mark_parent_dirty()

var _sprite: Node3D = null
var _slot_index := -1
var _slot_active := false
var _physical_depth := 0.0
var _user_visible := true
var _user_visibility_initialized := false
var _setting_visibility := false
var _sorting_state: Dictionary = {}
var _geometry_ids: Array[int] = []
var _geometry_update_queued := false


func _enter_tree() -> void:
    if not _user_visibility_initialized:
        _user_visible = visible
        _user_visibility_initialized = true
    set_process(not depth_camera.is_empty())
    var tree := get_tree()
    if tree != null and not tree.tree_changed.is_connected(_on_tree_changed):
        tree.tree_changed.connect(_on_tree_changed)
    if not child_entered_tree.is_connected(_on_child_tree_changed):
        child_entered_tree.connect(_on_child_tree_changed)
    if not child_exiting_tree.is_connected(_on_child_tree_changed):
        child_exiting_tree.connect(_on_child_tree_changed)
    _bind_parent(get_parent())
    _update_geometry_list()
    update_configuration_warnings()


func _exit_tree() -> void:
    var tree := get_tree()
    if tree != null and tree.tree_changed.is_connected(_on_tree_changed):
        tree.tree_changed.disconnect(_on_tree_changed)
    if child_entered_tree.is_connected(_on_child_tree_changed):
        child_entered_tree.disconnect(_on_child_tree_changed)
    if child_exiting_tree.is_connected(_on_child_tree_changed):
        child_exiting_tree.disconnect(_on_child_tree_changed)
    _geometry_update_queued = false
    _reset_sorting()
    _geometry_ids.clear()
    _set_slot_active(false)
    _unbind_parent()
    set_process(false)
    _slot_index = -1


func _notification(what: int) -> void:
    match what:
        NOTIFICATION_PARENTED:
            _bind_parent(get_parent())
            update_configuration_warnings()
        NOTIFICATION_UNPARENTED:
            _reset_sorting()
            _set_slot_active(false)
            _unbind_parent()
            _slot_index = -1
            update_configuration_warnings()
        NOTIFICATION_VISIBILITY_CHANGED:
            if not _setting_visibility:
                _user_visible = visible
                _apply_visibility()


func _process(_delta: float) -> void:
    _update_depth_only()


func _bind_parent(parent: Node) -> void:
    var next: Node = parent if parent != null and parent is _SPRITE3D else null
    if next == _sprite:
        return
    _unbind_parent()
    _sprite = next
    _mark_parent_dirty()


func _unbind_parent() -> void:
    var old_sprite := _sprite
    if old_sprite == null:
        return
    _reset_sorting()
    _sprite = null
    if is_instance_valid(old_sprite) and old_sprite.has_method("_mark_render_dirty"):
        old_sprite.call("_mark_render_dirty")


func _on_tree_changed() -> void:
    if not is_inside_tree():
        return
    _queue_geometry_update()


func _on_child_tree_changed(_child: Node) -> void:
    if is_inside_tree():
        _queue_geometry_update()


func _queue_geometry_update() -> void:
    if _geometry_update_queued:
        return
    _geometry_update_queued = true
    call_deferred("_flush_geometry_update")


func _flush_geometry_update() -> void:
    _geometry_update_queued = false
    if not is_inside_tree():
        return
    if _update_geometry_list():
        _mark_parent_dirty()


func _mark_parent_dirty() -> void:
    if is_instance_valid(_sprite) and _sprite.has_method("_mark_render_dirty"):
        _sprite.call("_mark_render_dirty")


func get_material_for_blend(blend: int) -> Material:
    # Official 3D exposes only normal/additive overrides. Multiply and screen
    # are normalized to normal by SpineRenderShaders3D with a one-time warning.
    return additive_material if blend == 1 else normal_material


func get_slot_name() -> String:
    return slot_name


func set_slot_name(value: String) -> void:
    slot_name = value


func get_slot_index() -> int:
    return _slot_index


func set_depth_camera(path: NodePath) -> void:
    depth_camera = path


func get_depth_camera() -> NodePath:
    return depth_camera


func set_normal_material(value: ShaderMaterial) -> void:
    normal_material = value


func get_normal_material() -> ShaderMaterial:
    return normal_material


func set_additive_material(value: ShaderMaterial) -> void:
    additive_material = value


func get_additive_material() -> ShaderMaterial:
    return additive_material


func _sync_slot(row: Dictionary, setup_index: int, physical_depth: float) -> void:
    _slot_index = setup_index
    _physical_depth = physical_depth
    if row.is_empty() or not bool(row.get("bone_active", false)):
        _set_slot_active(false)
        return
    if not is_instance_valid(_sprite):
        _set_slot_active(false)
        return
    var core = _sprite.get("_core")
    if core == null or not core.is_loaded():
        _set_slot_active(false)
        return
    var bone_name := str(row.get("bone_name", ""))
    var world: Dictionary = core._data.get_bone_world_transform(
            core._instance_handle, bone_name)
    if world.is_empty():
        _set_slot_active(false)
        return
    var basis := Basis(
        Vector3(float(world.get("a", 1.0)), -float(world.get("c", 0.0)), 0.0),
        Vector3(float(world.get("b", 0.0)), -float(world.get("d", 1.0)), 0.0),
        Vector3(0.0, 0.0, 1.0))
    var pixel_size := float(_sprite.get_pixel_size())
    var target_transform := Transform3D(basis, Vector3(
            float(world.get("x", 0.0)) * pixel_size,
            -float(world.get("y", 0.0)) * pixel_size,
            _physical_depth * _get_depth_sign()))
    set_transform(target_transform)
    _set_slot_active(true)


func _set_slot_active(active: bool) -> void:
    _slot_active = active
    _apply_visibility()


func _apply_visibility() -> void:
    if not is_inside_tree():
        return
    var desired := _slot_active and _user_visible
    if visible == desired:
        return
    _setting_visibility = true
    visible = desired
    _setting_visibility = false


func _get_depth_sign() -> float:
    if not is_instance_valid(_sprite):
        return 1.0
    if depth_camera.is_empty() or not bool(_sprite.get_camera_relative_depth()):
        return 1.0
    var camera := get_node_or_null(depth_camera) as Camera3D
    var sprite_viewport := _sprite.get_viewport()
    var camera_viewport := camera.get_viewport() if camera != null else null
    if camera == null or not camera.is_inside_tree() \
            or sprite_viewport == null or camera_viewport == null \
            or sprite_viewport.find_world_3d() != camera_viewport.find_world_3d():
        return 1.0
    return -1.0 if _sprite.to_local(camera.global_position).z < 0.0 else 1.0


func _update_depth_only() -> void:
    if not _slot_active or not is_inside_tree():
        return
    var local_transform: Transform3D = self.transform
    var target_z := _physical_depth * _get_depth_sign()
    if not is_equal_approx(local_transform.origin.z, target_z):
        local_transform.origin.z = target_z
        set_transform(local_transform)


func _collect_geometry(node: Node, result: Array[GeometryInstance3D]) -> void:
    for child in node.get_children():
        if child is SpineSlotNode3D or child is _SPRITE3D:
            continue
        if child is GeometryInstance3D:
            result.append(child)
        _collect_geometry(child, result)


func _collect_geometry_ids(node: Node, result: Array[int]) -> void:
    for child in node.get_children():
        if child is SpineSlotNode3D or child is _SPRITE3D:
            continue
        if child.is_inside_tree() and child is GeometryInstance3D:
            result.append(child.get_instance_id())
        _collect_geometry_ids(child, result)


func _restore_sorting_state(id: int) -> void:
    if not _sorting_state.has(id):
        return
    var state: Dictionary = _sorting_state[id]
    var object: Variant = state.get("node")
    if is_instance_valid(object):
        var geometry := object as GeometryInstance3D
        if geometry != null:
            geometry.sorting_offset = float(state.get("offset", 0.0))
            geometry.sorting_use_aabb_center = bool(state.get("use_aabb_center", true))
    _sorting_state.erase(id)


func _update_geometry_list() -> bool:
    var current: Array[int] = []
    _collect_geometry_ids(self, current)
    if current == _geometry_ids:
        return false
    for id in _sorting_state.keys():
        var geometry_id := int(id)
        if not current.has(geometry_id):
            _restore_sorting_state(geometry_id)
    _geometry_ids = current
    return true


func _get_geometry_instances() -> Array[GeometryInstance3D]:
    _update_geometry_list()
    var result: Array[GeometryInstance3D] = []
    _collect_geometry(self, result)
    return result


func _set_geometry_sorting_offset(geometry: GeometryInstance3D, value: float) -> void:
    if not is_instance_valid(geometry) or not geometry.is_inside_tree():
        return
    var id := geometry.get_instance_id()
    if not _sorting_state.has(id):
        _sorting_state[id] = {
            "node": geometry,
            "offset": geometry.sorting_offset,
            "use_aabb_center": geometry.sorting_use_aabb_center,
        }
    geometry.sorting_offset = value
    geometry.sorting_use_aabb_center = false


func _set_sorting_offset(value: float) -> void:
    for geometry in _get_geometry_instances():
        _set_geometry_sorting_offset(geometry, value)


func _reset_sorting() -> void:
    for id in _sorting_state.keys():
        _restore_sorting_state(int(id))


func _validate_property(property: Dictionary) -> void:
    if property.name != "slot_name" or not is_instance_valid(_sprite):
        return
    property.hint = PROPERTY_HINT_ENUM_SUGGESTION
    property.hint_string = ",".join(_sprite.get_slot_names())


func _material_priority_matches(material: Material, priority: int) -> bool:
    var visited: Array[Material] = []
    var current := material
    while current != null:
        if visited.has(current):
            return false
        visited.append(current)
        if current.render_priority != priority:
            return false
        current = current.next_pass
    return true


func get_sorting_warnings() -> PackedStringArray:
    var warnings := PackedStringArray()
    if not get_parent() is _SPRITE3D:
        warnings.append("SpineSlotNode3D 必须是 SpineSprite3D 的直接子节点。")
        return warnings
    var sprite := get_parent() as _SPRITE3D
    if slot_name.is_empty():
        warnings.append("请选择插槽名称。")
    elif sprite.is_loaded() and slot_name not in sprite.get_slot_names():
        warnings.append("骨架中不存在插槽：" + slot_name)
    if not depth_camera.is_empty() and is_inside_tree():
        var camera := get_node_or_null(depth_camera) as Camera3D
        var sprite_viewport := sprite.get_viewport()
        var camera_viewport := camera.get_viewport() if camera != null else null
        if camera == null or not camera.is_inside_tree() \
                or sprite_viewport == null or camera_viewport == null \
                or sprite_viewport.find_world_3d() != camera_viewport.find_world_3d():
            warnings.append("depth_camera 必须指向同一 World3D 中的 Camera3D；当前按固定物理深度处理。")
        warnings.append("depth_camera 只支持单相机跟随，并会移动此节点的全部后代。")
    var expected_priority := int(sprite.get_render_priority())
    for geometry in _get_geometry_instances():
        var valid := true
        var inspected := false
        var override_material: Material = geometry.material_override
        var overlay_material: Material = geometry.material_overlay
        if override_material != null:
            inspected = true
            valid = _material_priority_matches(override_material, expected_priority)
        if overlay_material != null:
            inspected = true
            valid = valid and _material_priority_matches(overlay_material, expected_priority)
        if geometry is MeshInstance3D:
            inspected = true
            var mesh_instance := geometry as MeshInstance3D
            for surface in range(mesh_instance.get_surface_override_material_count()):
                var active_material: Material = mesh_instance.get_active_material(surface)
                if active_material == null:
                    valid = valid and expected_priority == 0
                else:
                    valid = valid and _material_priority_matches(active_material,
                            expected_priority)
        if geometry.has_method("get_render_priority"):
            inspected = true
            if int(geometry.call("get_render_priority")) != expected_priority:
                valid = false
        if not inspected:
            warnings.append("%s：无法检查渲染通道；请确认所有透明材质使用角色 render_priority。" \
                    % geometry.name)
        elif not valid:
            warnings.append("%s：所有挂载透明材质/通道应使用角色 render_priority %d。" \
                    % [geometry.name, expected_priority])
    return warnings


func _get_configuration_warnings() -> PackedStringArray:
    return get_sorting_warnings()
