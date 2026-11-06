@tool
class_name SpineSlotNode
extends Node2D
## Children draw immediately after this slot's attachment. Keep z_index at 0
## and children out of top-level mode to participate in skeleton draw order.
##
## 可见性语义：插槽有效（`_slot_active`）且用户在脚本/检查器里的 `visible`
## 为 true 时才显示。内部通过 RenderingServer 隐藏（不覆盖用户的 visible 属性），
## 用户任何时候都能改 visible——包括插槽无效、后续恢复有效时的记忆不会丢失。

@export var slot_name: String = "":
	set(value):
		slot_name = value
		_refresh_slot_index()
		if is_instance_valid(_sprite):
			_sprite.queue_redraw()
		update_configuration_warnings()

## SB-25B：插槽级材质覆盖（§12.8 顺序第 1 级；官方 API-SLOTNODE 003-005，
## screen 为官方排除项不提供）。null 时回落下一级；仅影响 v2 渲染路径中
## 该插槽 draw 的对应混合模式，v1 路径不受影响。自定义材质按 §12.6 消费
## straight COLOR（has_dark draw 的 COLOR 为纯调制、不含 light/dark）。
@export var normal_material: Material = null:
	set(value):
		normal_material = value
		_notify_material_changed()

@export var additive_material: Material = null:
	set(value):
		additive_material = value
		_notify_material_changed()

@export var multiply_material: Material = null:
	set(value):
		multiply_material = value
		_notify_material_changed()


## SB-25B：按 blend（0=normal/1=additive/2=multiply）返回该插槽的覆盖材质。
func get_material_for_blend(blend: int) -> Material:
	match blend:
		1:
			return additive_material
		2:
			return multiply_material
		_:
			return normal_material


func _notify_material_changed() -> void:
	if is_instance_valid(_sprite):
		_sprite.queue_redraw()

var _sprite: SpineSprite = null
var _slot_index := -1
## 用户对 visible 的意图（默认值与场景中的赋值一致地来自节点初始 visible）。
var _user_visible := true
## 当前插槽是否绑定到骨架中的有效活动插槽行。
var _slot_active := false

func _enter_tree() -> void:
	_user_visible = visible
	_set_sprite(_get_parent_sprite())
	_refresh_slot_index()
	update_configuration_warnings()
	_refresh_visibility()

func _exit_tree() -> void:
	# 手动 free()/reparent 都会经 _exit_tree：先解登记避免角色持有已释放
	# 节点；_sprite 可能已被销毁，is_instance_valid 保护。
	# 保留 _user_visible：用户对可见性的意图跨离树/再入树不变。
	# free() 时通知顺序是 PARENTED→EXIT：PARENTED 阶段父节点仍为角色，登记
	# 尚未解除；这里的一致性守卫确保免费路径也必然从角色插槽清单移除。
	_detach_sprite()
	_slot_active = false
	_slot_index = -1

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_VISIBILITY_CHANGED:
			# 引擎本地级联或父级有效可见性变化都经此通知；任何情况下都以
			# “插槽有效 && 用户 visible”的最终规则刷新，同时对齐用户的意图记录。
			var changed_value := visible
			_user_visible = changed_value
			_refresh_visibility()
		NOTIFICATION_PARENTED, NOTIFICATION_UNPARENTED:
			# UNPARENTED 的通知到达时 get_parent() 仍可能返回旧角色；
			# 不重新解析父节点，先无条件解除旧绑定，避免离树节点被旧角色驱动。
			if what == NOTIFICATION_UNPARENTED:
				_detach_sprite()
				_slot_active = false
				_slot_index = -1
				_refresh_visibility()
			else:
				_set_sprite(_get_parent_sprite())
				_refresh_slot_index()
				update_configuration_warnings()
				_refresh_visibility()

func _set_sprite(next: SpineSprite) -> void:
	if next == _sprite:
		return
	_detach_sprite()
	_sprite = next
	if _sprite == null:
		return
	_sprite._register_slot_node(self)
	if not _sprite.world_transforms_changed.is_connected(_on_world_transforms_changed):
		_sprite.world_transforms_changed.connect(_on_world_transforms_changed)


func _get_parent_sprite() -> SpineSprite:
	var parent := get_parent()
	if parent is SpineSprite:
		return parent as SpineSprite
	return null

func _detach_sprite() -> void:
	if not is_instance_valid(_sprite):
		_sprite = null
		return
	if _sprite.world_transforms_changed.is_connected(_on_world_transforms_changed):
		_sprite.world_transforms_changed.disconnect(_on_world_transforms_changed)
	_sprite._unregister_slot_node(self)
	_sprite = null

func _refresh_visibility() -> void:
	if not is_inside_tree():
		return
	# RenderingServer 可见性应用于角色自身，但用户 visible 属性保留。
	RenderingServer.canvas_item_set_visible(get_canvas_item(), _slot_active and _user_visible)

func _sync_slot(row: Dictionary) -> void:
	_refresh_slot_index()
	_slot_active = not row.is_empty() and bool(row.get("bone_active", false))
	_refresh_visibility()
	if _slot_active and is_instance_valid(_sprite):
		global_transform = _sprite.get_global_bone_transform(row["bone_name"])

## Sync the attachment transform as soon as world transforms are complete. Draw-order
## sorting still owns canvas order, but must not be the first transform update.
func _on_world_transforms_changed(source: Node) -> void:
	if source != _sprite or not is_instance_valid(_sprite):
		return
	_sync_slot(_sprite._get_slot_render_row(slot_name))

func _refresh_slot_index() -> void:
	_slot_index = -1
	if not is_instance_valid(_sprite) or not _sprite.is_loaded():
		return
	_slot_index = _sprite.get_slot_names().find(slot_name)

## Official SpineSlotNode exposes the setup-order slot index for sorting/querying.
func get_slot_index() -> int:
	return _slot_index

func set_slot_name(value: String) -> void:
	slot_name = value

func get_slot_name() -> String:
	return slot_name

func _validate_property(property: Dictionary) -> void:
	if property.name == "slot_name" and is_instance_valid(_sprite):
		property.hint = PROPERTY_HINT_ENUM_SUGGESTION
		property.hint_string = ",".join(_sprite.get_slot_names())

func _get_configuration_warnings() -> PackedStringArray:
	var parent := get_parent()
	if not parent is SpineSprite:
		return PackedStringArray(["SpineSlotNode 必须是 SpineSprite 的直接子节点。"])
	if slot_name.is_empty():
		return PackedStringArray(["请选择插槽名称。"])
	if is_instance_valid(_sprite) and _sprite.is_loaded() and slot_name not in _sprite.get_slot_names():
		return PackedStringArray(["骨架中不存在插槽：" + slot_name])
	return PackedStringArray()
