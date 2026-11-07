@tool
class_name SpineBoneNode
extends Node2D
## Child under SpineSprite. FOLLOW moves this node with a bone;
## DRIVE writes this node's transform after animation application.

enum BoneMode { FOLLOW, DRIVE }

@export var bone_name: String = "":
	set(value):
		bone_name = value
		_refresh()

@export var bone_mode: BoneMode = BoneMode.FOLLOW:
	set(value):
		bone_mode = value
		_refresh()

@export var enabled: bool = true:
	set(value):
		enabled = value
		_refresh()

## SB-13：官方 Debug 组（API-BONENODE-003/004）。绘制只在编辑器内执行，
## 不进入导出运行的绘制逻辑；默认值与官方一致。
@export_group("Debug")
@export var thickness := 5.0:
	set(value):
		thickness = value
		queue_redraw()

@export var color := Color(0xff000077):
	set(value):
		color = value
		queue_redraw()

var _sprite: SpineSprite = null

func _enter_tree() -> void:
	_bind_sprite()
	_refresh()

func _exit_tree() -> void:
	_unbind_sprite()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_PARENTED:
			if is_inside_tree():
				_bind_sprite()
				_refresh()
		NOTIFICATION_UNPARENTED:
			_unbind_sprite()

func _find_sprite() -> SpineSprite:
	var current := get_parent()
	while current != null:
		if current is SpineSprite:
			return current as SpineSprite
		current = current.get_parent()
	return null

func _bind_sprite() -> void:
	var next := _find_sprite()
	if next == _sprite:
		return
	_unbind_sprite()
	_sprite = next
	if _sprite == null:
		return
	if not _sprite.before_world_transforms_change.is_connected(_drive):
		_sprite.before_world_transforms_change.connect(_drive)
	if not _sprite.world_transforms_changed.is_connected(_follow):
		_sprite.world_transforms_changed.connect(_follow)

func _unbind_sprite() -> void:
	if is_instance_valid(_sprite):
		if _sprite.before_world_transforms_change.is_connected(_drive):
			_sprite.before_world_transforms_change.disconnect(_drive)
		if _sprite.world_transforms_changed.is_connected(_follow):
			_sprite.world_transforms_changed.disconnect(_follow)
	_sprite = null

func _process(_delta: float) -> void:
	# Runtime follows the parent's update mode; editor preview follows bones
	# explicitly so the debug shape tracks the current pose.
	if Engine.is_editor_hint():
		_follow(_sprite)
		queue_redraw()


## SB-13：骨骼调试形状（仅编辑器）。以骨骼长度画出方向线，
## thickness/color 对齐官方属性。
func _draw() -> void:
	if not Engine.is_editor_hint() or not enabled:
		return
	var bone := find_bone()
	if bone == null:
		return
	var bone_data := bone.get_data()
	var length := float(bone_data.get_length()) if bone_data != null else 0.0
	var draw_thickness: float = maxf(thickness, 0.1)
	draw_line(Vector2.ZERO, Vector2(length, 0.0), color, draw_thickness)
	draw_circle(Vector2.ZERO, draw_thickness * 0.5, color)

func _has_bone() -> bool:
	return find_bone() != null

func _follow(source: Node) -> void:
	if source != _sprite:
		return
	if enabled and bone_mode == BoneMode.FOLLOW and _has_bone():
		global_transform = _sprite.get_global_bone_transform(bone_name)

func _drive(source: Node) -> void:
	if source != _sprite:
		return
	if not enabled or bone_mode != BoneMode.DRIVE or not _has_bone():
		return
	# A zero parent scale cannot be inverted when converting to skeleton space.
	if global_transform.is_finite() and _sprite.global_transform.is_finite() \
			and not is_zero_approx(_sprite.global_transform.determinant()):
		_sprite.set_global_bone_transform(bone_name, global_transform)

func _refresh() -> void:
	if is_inside_tree():
		_bind_sprite()
		_follow(_sprite)
		update_configuration_warnings()
		notify_property_list_changed()

func _validate_property(property: Dictionary) -> void:
	if property.name == "bone_name" and is_instance_valid(_sprite):
		property.hint = PROPERTY_HINT_ENUM_SUGGESTION
		property.hint_string = ",".join(_sprite.get_bone_names())

func _get_configuration_warnings() -> PackedStringArray:
	if _find_sprite() == null:
		return PackedStringArray(["SpineBoneNode 必须位于 SpineSprite 下方。"])
	if bone_name.is_empty():
		return PackedStringArray(["请选择骨骼名称。"])
	if is_instance_valid(_sprite) and _sprite.is_loaded() and not _has_bone():
		return PackedStringArray(["骨架中不存在骨骼：" + bone_name])
	return PackedStringArray()

## 对齐官方节点的选择入口；返回当前实例中的借用 SpineBone 包装。
func find_bone() -> SpineBone:
	if not is_inside_tree() or not is_visible_in_tree() or not is_instance_valid(_sprite):
		return null
	var skeleton: SpineSkeleton = _sprite.get_skeleton()
	if skeleton == null or not skeleton.is_valid():
		return null
	return skeleton.find_bone(bone_name)

## 返回父链中的 SpineSprite。
func find_sprite() -> SpineSprite:
	var current := get_parent()
	while current != null:
		if current is SpineSprite:
			return current as SpineSprite
		current = current.get_parent()
	return null
