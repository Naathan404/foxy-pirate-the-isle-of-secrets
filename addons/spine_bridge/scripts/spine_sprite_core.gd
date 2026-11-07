@tool
extends Node2D

## SpineSprite 与 SpineSprite3D 共享的内部运行实现；不注册为可创建节点。

## 已登记的插槽子节点（SpineSlotNode 在入树/离树时登记与解登记）。
var _slot_nodes: Array[Node2D] = []
## 逐槽路径使用的内部 MeshInstance2D（与插槽行一一对应）。
var _slot_meshes: Array[MeshInstance2D] = []
## 逐槽重绘帧号：延迟排序用其识别过期 rows（重绘或资源替换后帧号即变）。
var _slot_frame := 0
## SB-10 v2 批量路径使用的内部 MeshInstance2D（逐 draw 一项；CanvasItem 材质
## 作用于整个画布项，逐 draw 混合/双色必须逐 draw 画布项）。与 _slot_meshes
## 互斥：批量路径用 _draw_meshes，逐槽路径用 _slot_meshes（v1 渲染两路均
## 保持原路径不变）。
var _draw_meshes: Array[MeshInstance2D] = []
## SB10-R2：self_modulate 只作用于节点自身画布、不被子节点继承；v2 内部网格
## 须手动镜像一次（缓存用于检测运行时修改，经树级 process_frame 轮询同步，
## 见 _sync_v2_self_modulate——不随节点暂停停止）。
var _v2_self_modulate := Color.WHITE
## SB-11：已同步到 v2 内部网格的 light_mask（缓存用于检测运行时修改）。
var _v2_light_mask := 1
## SB11-R1：上次轮询见到的"有效用户整节点材质"（material 排除自动 premult；
## 变化时经树级轮询触发重绘，使 v2 逐 draw 材质选择即时生效——CanvasItem
## 的 material setter 无法在脚本拦截）。
var _v2_user_material: Material = null
## _slot_meshes 是否处于 v2 逐槽模式（v2 路径置位；v1 路径与清池复位）。
var _slot_meshes_v2 := false
## SB-25B：当前视口是否为 HDR-2D + RD 渲染器（每次重绘刷新；
## 双色材质的 light/dark uniform 需 srgb_to_linear，§12.8）。
var _v2_hdr_2d := false
## SB-11：v2 页级 CanvasTexture 缓存（page_index → diffuse+normal）。法线页经
## CanvasTexture 进入 Godot 内建 2D 灯光管线（与官方 10-2d-lighting 示例同路，
## 官方 SpineAtlasResource.cpp:217-222 将 normal 装入 CanvasTexture）；无法线页
## 直接用 diffuse 贴图，行为与此前完全一致。资源重建（_release）时清空。
var _v2_page_canvas_textures: Dictionary = {}
## SB-23C（步骤 3）：has_dark draw 的纯白顶点色按顶点数缓存复用
## （add_surface_from_arrays 消费时复制数据，缓存不跨帧再变）。
## 与 _v2_page_canvas_textures 同步随 _release 清空。
var _v2_white_arrays: Dictionary = {}
## SB-23D（D2）：原生渲染帧消费者（Bridge C++ 直接消费 provider v2 帧
## 并提交网格数据；仅 v2 能力 provider 非空）。随 _release 释放；任何
## 回退帧（Dictionary 路径）前必须置空（见 _try_draw_v2_native 不变式）。
var _v2_consumer: SpineRenderFrameConsumer = null
## SB-23D（D2）：本次加载周期内原生消费不可用（旧 provider / 创建失败）；
## 避免逐帧重试，_release/_load_from_resource 复位。
var _v2_native_unavailable := false
## SB-23D（D2）：测试用开关——禁用原生路径，回退 D1 的 GDScript
## Dictionary 路径（spine_sb23d_mesh_update_test 验证回退路径语义）。
## 正常运行恒为 false；非公开契约。
var _v2_native_render_disabled := false
## SB-23D（D2）：最近一帧原生消费的提交信息（定向验证用；非公开契约）。
var _v2_last_native_info: Dictionary = {}
## SB-23D（D3）：材质选择输入代数（变化时令逐 draw 材质缓存整体失效）。
## 递增时机：sprite 级覆盖材质赋值、用户整节点 material 变化（重绘帧内
## 轮询，见 _apply_v2_materials）、HDR-2D 判定翻转、消费者重建、批量池
## 节点新建（池重建后节点材质为 null，需重新赋值）。
var _v2_material_state_gen := 0
## SB-23D（D3）：原生路径逐 draw 材质选择缓存（变化标记）。仅在无插槽
## 节点的批量路径使用：_v2_material_cache[i] 为上次选择并已赋到池节点 i
## 的材质；_v2_material_cache_gen 记录填充时的输入代数；
## _v2_material_applied_size 为已确认赋值的前缀长度（消费者 changed 掩码
## 与该长度共同决定本帧需重选的 draw）。
var _v2_material_cache: Array = []
var _v2_material_cache_gen := -1
var _v2_material_applied_size := 0
## SB-11：_apply_page_material 自动分配的整节点 premult 材质（v1 批量路径）。
## 仅当当前 material 为 null 或即本引用时才改写——用户设置的整节点自定义
## 材质不被 load/reload 覆盖（官方 SpineSprite 从不改写自身 material）。
var _auto_page_material: CanvasItemMaterial = null
## SB-10 内置 premult 材质（单色/双色 × normal/additive/multiply × 页 PMA）。
const _render_shaders := preload("res://addons/spine_bridge/scripts/spine_render_shaders.gd")
var _v2_normal_material_cache = null
## SB-13：官方 Preview 组（API-SPRITE-043）的空动画选项与缺省皮肤名。
const PREVIEW_EMPTY_ANIMATION := "-- Empty --"
const PREVIEW_DEFAULT_SKIN := "Default"
## SB-13 物理预览定步重放策略（卡步骤 3）：
## - 步长对齐 Godot 默认物理帧 1/60 s，与运行时 PHYSICS 模式的 delta 一致；
## - 每个 seek 的代价是 O(target / step) 次 update/apply/world-update；
## - 上限 _PREVIEW_PHYSICS_MAX_STEPS 步（约 60 s 动画时间），超出部分不再
##   重放，改为直接设置轨道时间并在编辑器内提示，避免拖动时间条时长时间卡顿。
const _PREVIEW_PHYSICS_STEP := 1.0 / 60.0
const _PREVIEW_PHYSICS_MAX_STEPS := 3600

## SB-13 编辑器预览状态（动态属性 preview_*，EDITOR|STORAGE）。只存四个值，
## 不序列化 Skeleton/AnimationState 句柄；运行时加载这些值不改变自动播放。
var _preview_skin := PREVIEW_DEFAULT_SKIN
var _preview_animation := PREVIEW_EMPTY_ANIMATION
var _preview_frame := false
var _preview_time := 0.0
## 预览参数变化后需要在编辑器内重新应用（皮肤/动画/固定帧/时间）。
var _preview_dirty := false
## 调试图形画在父 CanvasItem；启用时让内部网格画在父节点后方。
var _debug_meshes_behind_parent := false
## 骨骼名称、长度和三角索引在实例生命周期内不变；仅世界变换逐帧更新。
var _debug_bone_names := PackedStringArray()
var _debug_bone_lengths := PackedFloat32Array()
var _debug_bone_indices := PackedInt32Array()
## SB-20（SB20-R1）：轨道回调内已完成编辑器 scrub 的定步重放；本帧
## _update_stages 以零增量收尾，避免物理约束多模拟一帧并保证暂停采样与
## 编辑器帧间隔无关。
var _editor_scrub_replayed := false
## Spine 角色显示节点：把 Spine Bridge 输出的渲染数据画到画布上。
##
## 操作模式对齐官方 spine-godot：本节点只负责显示与实例生命周期，
## 骨架数据由挂载的 SpineSkeletonDataResource（原生资源）持有——
## 该资源组合 SpineAtlasResource（.atlas 导入）与
## SpineSkeletonFileResource（.skel/.spine-json 导入），
## 多个角色引用同一资源时共享解析结果与贴图。
##
## 编辑器用法：把 .atlas / .skel / .png 放入项目（自动导入为资源），
## 新建 SpineSkeletonDataResource 并在其检查器中分配 atlas 与骨架文件，
## 再把该资源拖到本节点的 Skeleton Data 属性上。
## 本脚本为 @tool：编辑器视口内静态预览当前姿态（不推进动画）。


## 加载或播放失败时发出，参数为人类可读的错误说明。
signal load_failed(reason: String)

## Spine 官方 AnimationState 生命周期信号。状态和条目均为对象包装。
signal animation_started(spine_sprite: Node, animation_state: SpineAnimationState, track_entry: SpineTrackEntry)
signal animation_interrupted(spine_sprite: Node, animation_state: SpineAnimationState, track_entry: SpineTrackEntry)
signal animation_ended(spine_sprite: Node, animation_state: SpineAnimationState, track_entry: SpineTrackEntry)
signal animation_disposed(spine_sprite: Node, animation_state: SpineAnimationState, track_entry: SpineTrackEntry)
signal animation_completed(spine_sprite: Node, animation_state: SpineAnimationState, track_entry: SpineTrackEntry)
signal animation_event(spine_sprite: Node, animation_state: SpineAnimationState, track_entry: SpineTrackEntry, event: SpineEvent)

signal before_animation_state_update(sprite: Node)
signal before_animation_state_apply(sprite: Node)
signal before_world_transforms_change(sprite: Node)
signal world_transforms_changed(sprite: Node)

var _updating_skeleton := false

## SpineSprite 与 SpineSprite3D 在进入场景树时启用同步事件回调。
var _animation_event_dispatch_enabled := false

## 资源同步接收器每次进入（包括空事件批）都会递增。监听者在发射中调用
## AnimationState 的另一操作时，嵌套接收器会使外层批次立即过期，避免把
## 已被回调替换的旧状态事件继续投递。
var _animation_event_generation := 0

## SpineSprite3D 以弱引用登记自己；其内部运行节点仍可能在当前原生调用栈
## 中存活，故外层请求离树/删除后必须停止同步事件和更新阶段。2D 节点登记自身。
var _event_dispatch_owner: WeakRef = null


## 骨架数据资源
## 组合 atlas 与骨架文件；多个角色可共享同一资源。
@export var skeleton_data: SpineSkeletonDataResource = null:
	set(value):
		skeleton_data = value
		if is_inside_tree():
			if value != null:
				_load_from_resource(value)
			else:
				_release()
		elif _data != null:
			_release()


## 适配视口
## 加载后是否自动缩放到当前视口大小；手动摆场景时关闭。
## 默认关闭，避免仅分配 Skeleton Data 就改写场景中的缩放和位置。
@export var fit_to_viewport: bool = false


## 角色缩放
## 渲染整体缩放；1.0 为导出原始尺寸。
## 作为 scale.x 的纯别名：不单独存储（PROPERTY_USAGE_NO_STORAGE），
## 场景文件只保留 Node2D 自带的 scale —— 此前本属性独立存储，
## 与 scale 各存一份、加载时后应用者覆盖前者，正是"加载 Skeleton
## Data 后缩放变得极小"的根因（旧的 fit_to_viewport 值残留场景）。
## 注：Godot 4.7 的检查器属性读取存在不走脚本 getter 的缓存路径，
## 故用 @export_custom + PROPERTY_USAGE_NO_STORAGE 而非 @export 存储。
@export_custom(PROPERTY_HINT_RANGE, "0.001,10,0.001,or_greater", PROPERTY_USAGE_EDITOR)
var character_scale: float:
	get:
		return scale.x
	set(value):
		var clamped: float = maxf(value, 0.001)
		scale = Vector2(clamped, clamped)


## 自动播放
## 加载完成后是否立即开始播放（编辑器内始终为静态预览）。
@export var auto_play: bool = true


## 更新模式（对齐官方 SpineConstant::UpdateMode）。
## PROCESS：在 _process 推进；PHYSICS：在 _physics_process 推进；
## MANUAL：不自动推进，由脚本调用 update_skeleton(delta)。
enum UpdateMode {
	PROCESS,
	PHYSICS,
	MANUAL,
}


## 骨架更新模式；切换后下一帧生效。只启用对应的 Godot 时钟回调，MANUAL
## 不启用自动推进；显式 update_skeleton() 仍可在暂停或离开自动模式时调用。
@export var update_mode: UpdateMode = UpdateMode.PROCESS:
	set(value):
		update_mode = value
		_configure_update_callbacks()


## 播放速度
## 播放速度缩放；1.0 为原始速度。
@export var playback_speed: float = 1.0

## SB-25B v2 材质覆盖（§12.8 顺序第 2 级；官方 API-SPRITE 013-015，
## screen 为官方排除项不提供）。null 时回落下一级；仅影响 v2 渲染路径
## 的对应混合模式 draw，v1 路径与整节点 CanvasItem material 不受影响。
## 自定义材质按 §12.6 消费 straight COLOR（has_dark draw 的 COLOR 为纯
## 调制、不含 light/dark），PMA/双色处理由材质作者负责。
@export var normal_material: Material = null:
	set(value):
		normal_material = value
		# SB-23D（D3）：覆盖材质是逐 draw 材质选择输入，变化时令缓存失效。
		_v2_material_state_gen += 1
		queue_redraw()

@export var additive_material: Material = null:
	set(value):
		additive_material = value
		_v2_material_state_gen += 1
		queue_redraw()

@export var multiply_material: Material = null:
	set(value):
		multiply_material = value
		_v2_material_state_gen += 1
		queue_redraw()

## SB-13：官方 Debug 组（API-SPRITE-017..031）。数值可随场景保存，但绘制只在
## 编辑器内执行，不进入导出运行的绘制逻辑。root/bones 使用版本中立骨骼世界
## 变换；region/mesh/boundingbox/path/clipping 使用 v1.16 调试几何通道
## （显式附件类型 + 当前姿态世界顶点，见 SB13-R1/R2）。
@export_group("调试")
@export var root := false:
	set(value):
		root = value
		queue_redraw()

@export var root_color := Color(1, 1, 1, 0.5):
	set(value):
		root_color = value
		queue_redraw()

@export var bones := false:
	set(value):
		bones = value
		queue_redraw()

@export var bones_color := Color(1, 1, 0, 0.5):
	set(value):
		bones_color = value
		queue_redraw()

@export var bones_thickness := 5.0:
	set(value):
		bones_thickness = value
		queue_redraw()

@export var regions := false:
	set(value):
		regions = value
		queue_redraw()

@export var regions_color := Color(0, 0, 1, 0.5):
	set(value):
		regions_color = value
		queue_redraw()

@export var meshes := false:
	set(value):
		meshes = value
		queue_redraw()

@export var meshes_color := Color(0, 0, 1, 0.5):
	set(value):
		meshes_color = value
		queue_redraw()

@export var bounding_boxes := false:
	set(value):
		bounding_boxes = value
		update_configuration_warnings()
		queue_redraw()

@export var bounding_boxes_color := Color(0, 1, 0, 0.5):
	set(value):
		bounding_boxes_color = value
		queue_redraw()

@export var paths := false:
	set(value):
		paths = value
		update_configuration_warnings()
		queue_redraw()

@export var paths_color := Color(1, 0.498039, 0, 0.466667):
	set(value):
		paths_color = value
		queue_redraw()

@export var clipping := false:
	set(value):
		clipping = value
		update_configuration_warnings()
		queue_redraw()

@export var paths_clipping := Color(0.8, 0, 0, 0.8):
	set(value):
		paths_clipping = value
		queue_redraw()


## 动画名称
## 循环播放的动画名；留空时自动选第一个动画。加载完成后在检查器
## 中显示为该骨架全部动画的下拉列表（经 _get_property_list 动态提供）。
var animation_name: String = "":
	set(value):
		animation_name = value
		_apply_animation()


## 是否正在播放（实例就绪且有动画轨道）。
var is_playing: bool = false


## 最近一次加载失败的错误说明（无失败时为空）。
var last_error: String = ""


## 实际使用的骨架数据资源（导出资源或 load_from_files 构造的临时资源）。
var _data: SpineSkeletonDataResource = null


## 实例句柄；0 表示未加载。
var _instance_handle: int = 0


## load_from_files 构造的临时资源引用（保持存活以维持解析结果）。
var _temp_data: SpineSkeletonDataResource = null


## 渲染网格池。draw_mesh 提交的是 mesh 的 RID，有两个约束：
## 1）对象必须存活到本帧渲染结束（局部变量在 _draw() 返回后释放会导致
##    渲染器拿到悬空 RID 而丢失绘制）；
## 2）渲染器不感知同一 RID 的表面数据更新，必须每帧使用新的网格对象。
## 因此每帧重建网格并保留到下一次 _draw() 再释放。
var _mesh_pool: Array[ArrayMesh] = []

## SB-26A：SpineSprite3D 复用本节点作为动画/实例核心，但由自身消费
## 版本中立的 render_commands；关闭内部 2D _draw，避免同一实例被重复提交。
var render_enabled := true


## 动态属性：动画名称在骨架加载后变为下拉列表。
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	var entry := {
		"name": "animation_name",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": "",
		"usage": PROPERTY_USAGE_DEFAULT,
	}
	if _data != null and _data.is_skeleton_data_loaded():
		var names := _data.get_animation_names()
		if not names.is_empty():
			# 枚举提示：逗号分隔的动画名列表（名称含逗号的资源不受支持）。
			entry["hint"] = PROPERTY_HINT_ENUM
			entry["hint_string"] = ",".join(names)
	properties.append(entry)
	properties.append_array(_preview_property_entries())
	return properties


## SB-13：官方 Preview 组动态属性（仅在骨架数据可用后提供；枚举来自实际
## 名单，缺失项经配置警告提示）。属性 usage 与官方一致为 EDITOR|STORAGE。
func _preview_property_entries() -> Array[Dictionary]:
	return build_preview_property_entries(_data, _preview_animation)


## Preview 属性表由 SpineSprite 与 SpineSprite3D 共用。
static func build_preview_property_entries(data: SpineSkeletonDataResource,
		animation: String) -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	if data == null or not data.is_skeleton_data_loaded():
		return properties
	var usage := PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_STORAGE
	properties.append({
		"name": "Preview",
		"type": TYPE_NIL,
		"hint_string": "",
		"usage": PROPERTY_USAGE_GROUP,
	})
	var skin_names := data.get_skin_names()
	properties.append({
		"name": "preview_skin",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM if not skin_names.is_empty() else PROPERTY_HINT_NONE,
		"hint_string": ",".join(skin_names),
		"usage": usage,
	})
	var animation_options := PackedStringArray([PREVIEW_EMPTY_ANIMATION])
	animation_options.append_array(data.get_animation_names())
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
	if is_preview_animation_set(animation):
		var animation_object := data.get_animation_object(animation)
		if animation_object != null:
			duration = maxf(float(animation_object.get_duration()), 0.0)
	properties.append({
		"name": "preview_time",
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0.0,%s,0.01" % duration,
		"usage": usage,
	})
	return properties


## 预览动画是否选中（非空且不是官方 "-- Empty --" 空态）。
static func is_preview_animation_set(animation: String) -> bool:
	return not animation.is_empty() and animation != PREVIEW_EMPTY_ANIMATION


func _get(property: StringName) -> Variant:
	match property:
		&"preview_skin":
			return _preview_skin
		&"preview_animation":
			return _preview_animation
		&"preview_frame":
			return _preview_frame
		&"preview_time":
			return _preview_time
	return null


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"preview_skin":
			set_preview_skin(str(value))
			return true
		&"preview_animation":
			set_preview_animation(str(value))
			return true
		&"preview_frame":
			set_preview_frame(bool(value))
			return true
		&"preview_time":
			set_preview_time(float(value))
			return true
	return false


func _enter_tree() -> void:
	_configure_update_callbacks()
	# _ready only runs once; characters can leave and re-enter the scene tree.
	# SB10-R2：v2 自身调制镜像挂到 SceneTree.process_frame（树级信号每渲染
	# 帧发射、不受本节点暂停影响）——同步不依赖角色动画处理回调获准运行，
	# 暂停期间修改/修改后立即暂停均在下一渲染帧生效，且不推进暂停中的骨架
	# 动画；已连接时跳过（防重复入树重连）。
	if not get_tree().process_frame.is_connected(_sync_v2_self_modulate):
		get_tree().process_frame.connect(_sync_v2_self_modulate)
	var data := _data if _data != null else skeleton_data
	if data != null and _instance_handle == 0:
		_load_from_resource(data)


func _exit_tree() -> void:
	set_process(false)
	set_physics_process(false)
	# SB10-R2：先断开树级同步，退出过程中的后续 process_frame 不得触达正被
	# 释放的内部网格。
	var tree := get_tree()
	if tree != null and tree.process_frame.is_connected(_sync_v2_self_modulate):
		tree.process_frame.disconnect(_sync_v2_self_modulate)
	_release_instance()
	_clear_slot_meshes()
	_clear_draw_meshes()
	if _data != null and _data.changed.is_connected(_on_data_changed):
		_data.changed.disconnect(_on_data_changed)
	_mesh_pool.clear()
	# Retain the resource (including load_from_files data) for the next entry.


func _process(delta: float) -> void:
	if update_mode == UpdateMode.PROCESS:
		_advance_frame(delta)


func _physics_process(delta: float) -> void:
	if update_mode == UpdateMode.PHYSICS:
		_advance_frame(delta)

func _configure_update_callbacks() -> void:
	set_process(update_mode == UpdateMode.PROCESS)
	set_physics_process(update_mode == UpdateMode.PHYSICS)


## 自动模式共用的逐帧推进。编辑器内走 Preview 组时钟；运行时保持原播放语义。
func _advance_frame(delta: float) -> void:
	if Engine.is_editor_hint():
		advance_editor_preview(delta)
		return
	if not is_playing:
		return
	update_skeleton(delta)


## 手动推进一帧（MANUAL 模式的入口；对齐官方 SpineSprite::update_skeleton）。
## 不受 is_playing 限制；playback_speed 与自动模式同样生效。
func update_skeleton(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_update_skeleton_internal(delta)


## 供 SpineSprite 与 SpineSprite3D 编辑器预览复用同一套更新阶段。
func _update_skeleton_for_editor_preview(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	_update_skeleton_internal(delta)


## 编辑器预览时钟，由 2D/3D 节点共用。
## 固定帧只保证停在 preview_time；非固定帧按 PROCESS/PHYSICS 模式持续更新
## 同一 AnimationState。仅在编辑器内运行，运行时自动播放路径不受影响。
func advance_editor_preview(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	if _preview_dirty:
		_apply_editor_preview()
	if _preview_frame:
		return
	# SB-20：官方 SpineSprite 在编辑器内始终推进状态时钟，Preview 动画只是轨道 0
	# 的初始内容，因此没有 preview_animation 时也要给 before_animation_state_update
	# 留出稳定回调（SpineAnimationTrack 编辑器 scrub 依赖它）。空动画下姿态仍是
	# setup pose，SB-13 的固定帧/持续推进语义不变。
	_update_skeleton_for_editor_preview(delta)


## 预览动画是否选中（非空且不是官方 "-- Empty --" 空态）。
func _has_preview_animation() -> bool:
	return is_preview_animation_set(_preview_animation)


## 官方 Preview 组状态访问器。
func set_preview_skin(value: String) -> void:
	_preview_skin = value
	_mark_preview_dirty(true)

func get_preview_skin() -> String:
	return _preview_skin

func set_preview_animation(value: String) -> void:
	_preview_animation = value
	_mark_preview_dirty(true)

func get_preview_animation() -> String:
	return _preview_animation

func set_preview_frame(value: bool) -> void:
	_preview_frame = value
	_mark_preview_dirty(false)

func get_preview_frame() -> bool:
	return _preview_frame

func set_preview_time(value: float) -> void:
	_preview_time = maxf(value, 0.0)
	_mark_preview_dirty(false)

func get_preview_time() -> float:
	return _preview_time


## 预览参数变化：标记待应用、刷新检查器和配置警告；编辑器内立即应用一次，
## 使固定帧 seek 不等下一帧。运行时仅保存值，不触碰实例状态。
func _mark_preview_dirty(refresh_list: bool) -> void:
	_preview_dirty = true
	if refresh_list:
		notify_property_list_changed()
	update_configuration_warnings()
	if Engine.is_editor_hint():
		_apply_editor_preview()
	queue_redraw()


## SB-13：在编辑器内把 Preview 组应用到当前实例。皮肤缺失退回默认皮肤、
## 动画缺失退回空动画并保留用户选择（配置警告提示）；预览句柄不进入场景
## 序列化，四个属性值才是存储内容。
func _apply_editor_preview() -> void:
	if not Engine.is_editor_hint():
		return
	if _instance_handle == 0 or _data == null:
		_preview_dirty = true
		return
	var skeleton := get_skeleton()
	var state := get_animation_state()
	if skeleton == null or not skeleton.is_valid() or state == null:
		_preview_dirty = true
		return
	_preview_dirty = false
	var skin: SpineSkin = null
	if not _preview_skin.is_empty() and _preview_skin != PREVIEW_DEFAULT_SKIN:
		skin = _data.get_skin_object(_preview_skin)
	skeleton.set_skin(skin)
	skeleton.set_to_setup_pose()
	state.clear_track(0)
	if not _has_preview_animation() \
			or _data.get_animation_object(_preview_animation) == null:
		state.set_empty_animation(0, 0.0)
		state.update(0.0)
		state.apply(skeleton)
		_data.update_world_transform(_instance_handle, 0.0)
		queue_redraw()
		return
	var entry: SpineTrackEntry = state.set_animation(_preview_animation, true, 0)
	if entry == null:
		state.set_empty_animation(0, 0.0)
		state.update(0.0)
		state.apply(skeleton)
		_data.update_world_transform(_instance_handle, 0.0)
		queue_redraw()
		return
	entry.set_mix_duration(0.0)
	if _preview_frame:
		_seek_editor_preview_time(entry, state, skeleton)
	else:
		state.update(0.0)
		state.apply(skeleton)
		_data.update_world_transform(_instance_handle, 0.0)
	queue_redraw()


## SB-13：固定帧 seek。无物理约束时直接求值（set_track_time）；骨架含物理
## 约束时从基准状态定步重放（见文件头常量注释的精度/耗时策略）。
func _seek_editor_preview_time(entry: SpineTrackEntry, state: SpineAnimationState,
		skeleton: SpineSkeleton) -> void:
	_replay_editor_animation_time(entry, state, skeleton, maxf(_preview_time, 0.0))


## SB-20（SB20-R1）：SpineAnimationTrack 编辑器 scrub 入口。轨道在
## before_animation_state_update 回调内调用；调用方负责把骨架复位到基准
## （set_to_setup_pose）并建好条目、写完条目选项。重放语义与 Preview 固定帧
## 完全一致，因此同一动画时间的物理姿态与固定步长重放一致；完成后条目保持
## 暂停，且本帧后续阶段以零增量收尾（暂停采样与编辑器帧间隔无关）。
func replay_editor_scrub_time(entry: SpineTrackEntry, state: SpineAnimationState,
		target: float) -> void:
	if not Engine.is_editor_hint():
		return
	_editor_scrub_replayed = true
	var skeleton := get_skeleton()
	if skeleton == null or not skeleton.is_valid():
		return
	_replay_editor_animation_time(entry, state, skeleton, maxf(target, 0.0))


## SB-20（SB20-R1）：轨道输入未变时保持上一次 scrub 结果；仅标记本帧零增量，
## 使暂停采样在任意编辑器帧间隔下完全不变。
func hold_editor_scrub_time() -> void:
	if Engine.is_editor_hint():
		_editor_scrub_replayed = true


## SB-13/SB-20 共用的编辑器定步重放：无物理约束直接求值（set_track_time）；
## 含物理约束时从 setup pose + 约束 reset 的基准定步重放，保证重复 seek 与
## 编辑器帧间隔无关。
func _replay_editor_animation_time(entry: SpineTrackEntry, state: SpineAnimationState,
		skeleton: SpineSkeleton, target: float) -> void:
	var saved_state_time_scale := state.get_time_scale()
	if not _preview_has_physics(skeleton):
		entry.set_time_scale(0.0)
		entry.set_track_time(target)
		state.update(0.0)
		state.apply(skeleton)
		_data.update_world_transform(_instance_handle, 0.0)
		return
	# 物理约束带历史状态，seek 必须从基准状态定步重放：setup pose 已重置骨骼
	# 姿态，再清物理约束内部累积（velocity/remaining/lastTime），保证同一时间
	# 重复 seek 结果一致。状态时钟与条目时钟在重放期间必须可推进。
	for constraint in skeleton.get_physics_constraints():
		constraint.reset()
	state.set_time_scale(1.0)
	entry.set_time_scale(1.0)
	var remaining := target
	var steps := 0
	while true:
		var step := minf(remaining, _PREVIEW_PHYSICS_STEP)
		state.update(step)
		state.apply(skeleton)
		_data.update_world_transform(_instance_handle, step)
		remaining -= step
		steps += 1
		if remaining <= 0.000001 or steps >= _PREVIEW_PHYSICS_MAX_STEPS:
			break
	if remaining > 0.000001:
		# 超长区间不再重放，剩余时间直接设置轨道时间（策略已文档化）。
		entry.set_track_time(target)
		state.update(0.0)
		state.apply(skeleton)
		_data.update_world_transform(_instance_handle, 0.0)
		push_warning("Spine 预览：时间 %.2f s 超出物理定步重放上限（%d 步），剩余部分未重放。"
				% [target, _PREVIEW_PHYSICS_MAX_STEPS])
	entry.set_time_scale(0.0)
	state.set_time_scale(saved_state_time_scale)


## SB-13：骨架是否含物理约束（决定 seek 是否需要定步重放）。
func _preview_has_physics(skeleton: SpineSkeleton) -> bool:
	var constraints := skeleton.get_physics_constraints()
	return constraints != null and not constraints.is_empty()


func _update_skeleton_internal(delta: float) -> void:
	if _updating_skeleton or _instance_handle == 0 or _data == null:
		return
	if not _is_active_update_instance(_data, _instance_handle):
		return
	_updating_skeleton = true
	var ok := _update_stages(delta)
	if not is_instance_valid(self):
		return
	_updating_skeleton = false
	if ok:
		queue_redraw()


## 重新计算当前骨架世界变换并刷新消费者，不推进 AnimationState 或动画事件。
## 运行时可用于暂停期间应用脚本写入的骨骼姿态；编辑器预览由 Preview 组管理。
func refresh_pose() -> void:
	if Engine.is_editor_hint() or _updating_skeleton or _instance_handle == 0 or _data == null:
		return
	var source := _data
	var instance := _instance_handle
	if not _is_active_update_instance(source, instance):
		return
	_updating_skeleton = true
	var ok := _refresh_pose_stages(source, instance)
	if not is_instance_valid(self):
		return
	_updating_skeleton = false
	if ok:
		queue_redraw()


func _refresh_pose_stages(source: SpineSkeletonDataResource, instance: int) -> bool:
	if not _emit_update_stage("before_world_transforms_change", source, instance):
		return false
	if not source.update_world_transform(instance, 0.0):
		last_error = source.get_last_error()
		return false
	last_error = ""
	return _emit_update_stage("world_transforms_changed", source, instance)


func _update_stages(delta: float) -> bool:
	var source := _data
	var instance := _instance_handle
	if not _emit_update_stage("before_animation_state_update", source, instance):
		return false
	var step := delta * playback_speed
	if _editor_scrub_replayed:
		# SB-20（SB20-R1）：轨道回调内已完成定步重放，本帧不再叠加帧增量，
		# 否则物理约束会多模拟一帧且姿态随编辑器帧间隔漂移。
		_editor_scrub_replayed = false
		step = 0.0
	if not source.update_animation_state(instance, step):
		last_error = source.get_last_error()
		return false
		# 动画信号回调可在 update 返回前换资源、离树或请求销毁；不要
	# 让旧实例继续 apply 到已经替换后的资源。
	if not _is_active_update_instance(source, instance):
		return false
	if not _emit_update_stage("before_animation_state_apply", source, instance):
		return false
	if not source.apply_animation_state(instance):
		last_error = source.get_last_error()
		return false
	if not _is_active_update_instance(source, instance):
		return false
	if not _emit_update_stage("before_world_transforms_change", source, instance):
		return false
	if not source.update_world_transform(instance, step):
		last_error = source.get_last_error()
		return false
	last_error = ""
	return _emit_update_stage("world_transforms_changed", source, instance)


func _emit_update_stage(stage: StringName, source: SpineSkeletonDataResource, instance: int) -> bool:
	emit_signal(stage, self)
	# Hooks may remove/free this node, replace its resource or request an update.
	return _is_active_update_instance(source, instance)


func _is_active_update_instance(source: SpineSkeletonDataResource, instance: int) -> bool:
	return is_instance_valid(self) and not is_queued_for_deletion() \
		and is_inside_tree() and _data == source and _instance_handle == instance \
		and _has_active_event_dispatch_owner()


## 从文件加载 Spine 角色（程序化调用入口；编辑器流程走资源）。
## atlas_path 是 .atlas 文本文件；skeleton_path 是骨架文件
## （.skel 二进制或 .json/.spine-json 文本）。返回 true 表示加载成功。
func load_from_files(atlas_path: String, skeleton_path: String) -> bool:
	_release()
	last_error = ""

	var atlas_res := SpineAtlasResource.new()
	if atlas_res.load_from_atlas_file(atlas_path) != OK:
		last_error = atlas_res.get_last_error()
		load_failed.emit(last_error)
		return false

	var file_res := SpineSkeletonFileResource.new()
	if file_res.load_from_file(skeleton_path) != OK:
		last_error = file_res.get_last_error()
		load_failed.emit(last_error)
		return false

	var data := SpineSkeletonDataResource.new()
	data.atlas_res = atlas_res
	data.skeleton_file_res = file_res
	if not _load_from_resource(data):
		return false
	_temp_data = data
	return true


## 是否已成功加载并可渲染。
func is_loaded() -> bool:
	return _instance_handle != 0


## SB-13：预览皮肤/动画不存在时的配置警告（编辑器节点警告图标）；
## bounding_boxes/paths/clipping 在 provider 无 v1.16 调试几何通道时才提示，
## 有通道而缺几何数据属于正常空态，不产生警告。
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if _data != null and _data.is_skeleton_data_loaded():
		if not _preview_skin.is_empty() and _preview_skin != PREVIEW_DEFAULT_SKIN \
				and _data.get_skin_object(_preview_skin) == null:
			warnings.append("预览皮肤不存在：" + _preview_skin)
		if _has_preview_animation() and _data.get_animation_object(_preview_animation) == null:
			warnings.append("预览动画不存在：" + _preview_animation)
	var unavailable := PackedStringArray()
	if _data != null and _data.is_skeleton_data_loaded() \
			and not _data.has_debug_geometry_capability():
		if bounding_boxes:
			unavailable.append("bounding_boxes")
		if paths:
			unavailable.append("paths")
		if clipping:
			unavailable.append("clipping")
	if not unavailable.is_empty():
		warnings.append("调试绘制不可用（当前 provider 未提供调试几何通道 v1.16）："
				+ ",".join(unavailable))
	return warnings


## 立即播放指定动画（0 号轨道，循环）；失败返回 false。
func play(animation: String) -> bool:
	if animation.is_empty():
		return false
	var was_applying := _applying_animation
	_applying_animation = true
	animation_name = animation
	_applying_animation = was_applying
	return set_animation(animation, true, 0)


func set_animation(animation: String, loop: bool = true, track: int = 0) -> bool:
	if not is_loaded() or _data == null:
		return false
	return _animation_result(_data.set_animation(_instance_handle, track, animation, loop), true)


func add_animation(animation: String, delay: float = 0.0, loop: bool = true, track: int = 0) -> bool:
	if not is_loaded() or _data == null:
		return false
	return _animation_result(_data.add_animation(_instance_handle, track, animation, loop, delay), true)


func clear_track(track: int = 0) -> bool:
	if not is_loaded() or _data == null:
		return false
	return _animation_result(_data.clear_track(_instance_handle, track), false)


func clear_tracks() -> bool:
	if not is_loaded() or _data == null:
		return false
	return _animation_result(_data.clear_tracks(_instance_handle), false)


func set_empty_animation(track: int = 0, mix_duration: float = 0.2) -> bool:
	if not is_loaded() or _data == null:
		return false
	return _animation_result(_data.set_empty_animation(_instance_handle, track, mix_duration), true)


func add_empty_animation(track: int = 0, mix_duration: float = 0.2, delay: float = 0.0) -> bool:
	if not is_loaded() or _data == null:
		return false
	return _animation_result(_data.add_empty_animation(_instance_handle, track, mix_duration, delay), true)


func set_default_mix(duration: float) -> bool:
	if not is_loaded() or _data == null:
		return false
	return _animation_result(_data.set_default_mix(_instance_handle, duration), false)


func set_mix(from: String, to: String, duration: float) -> bool:
	if not is_loaded() or _data == null:
		return false
	return _animation_result(_data.set_mix(_instance_handle, from, to, duration), false)


func get_current(track: int = 0) -> Dictionary:
	if not is_loaded() or _data == null:
		return {}
	return _data.get_current(_instance_handle, track)


## --- 骨骼（对齐官方 SpineSprite / SpineBone 用法） ---

## 骨架包含的骨骼名列表；未加载时为空。
func get_bone_names() -> PackedStringArray:
	if _data == null or not _data.is_skeleton_data_loaded():
		return PackedStringArray()
	return _data.get_bone_names()


## 骨架包含的插槽名列表；未加载时为空。
func get_slot_names() -> PackedStringArray:
	if _data == null or not _data.is_skeleton_data_loaded():
		return PackedStringArray()
	return _data.get_slot_names()


## 骨骼 setup 数据快照（parent/length/x/y/rotation/scale/shear）；
## 骨骼不存在返回空字典。
func get_bone_data(name: String) -> Dictionary:
	if _data == null or not _data.is_skeleton_data_loaded():
		return {}
	return _data.get_bone_data(name)


## 实例上骨骼的当前局部姿态快照（x/y/rotation/scale/shear）。
func get_bone_pose(name: String) -> Dictionary:
	if not is_loaded() or _data == null:
		return {}
	return _data.get_bone_pose(_instance_handle, name)


## 修改实例上骨骼的局部姿态（部分字段字典：x/y/rotation/scale_x/
## scale_y/shear_x/shear_y），立即重算世界变换。失败返回 false。
func set_bone_pose(name: String, pose: Dictionary) -> bool:
	if not is_loaded() or _data == null:
		return false
	var ok := _data.set_bone_pose(_instance_handle, name, pose)
	if ok:
		queue_redraw()
	else:
		last_error = _data.get_last_error()
	return ok


## 骨骼的全局 Transform2D（含本节点的全局变换；对齐官方
## SpineSprite::get_global_bone_transform，Y 轴列按 yDown 取反）。
## 未加载或骨骼不存在时返回节点自身的全局变换（与官方一致）。
func get_global_bone_transform(bone_name: String) -> Transform2D:
	if not is_loaded() or _data == null:
		return global_transform
	var local := _bone_local_transform(bone_name)
	if local == Transform2D():
		return global_transform
	return global_transform * local


## 骨骼在节点局部空间的 Transform2D（Y 轴列按 yDown 取反，与顶点绘制一致）；
## 未加载或骨骼不存在时为空变换。
func _bone_local_transform(bone_name: String) -> Transform2D:
	if _data == null:
		return Transform2D()
	var world := _data.get_bone_world_transform(_instance_handle, bone_name)
	if world.is_empty():
		return Transform2D()
	var local := Transform2D()
	local[0] = Vector2(world["a"], world["c"])
	local[1] = Vector2(-world["b"], -world["d"])
	local[2] = Vector2(world["x"], world["y"])
	return local


## 直接设置骨骼的全局 Transform2D（对齐官方
## SpineSprite::set_global_bone_transform：换算到骨架局部并立即生效）。
## 未加载或骨骼不存在时不产生效果（与官方一致）。
func set_global_bone_transform(bone_name: String, transform: Transform2D) -> void:
	if not is_loaded() or _data == null:
		return
	var local := global_transform.affine_inverse() * transform
	var world := {
		"a": local[0].x,
		"c": local[0].y,
		"b": -local[1].x,
		"d": -local[1].y,
		"x": local.origin.x,
		"y": local.origin.y,
	}
	if _data.set_bone_world_transform(_instance_handle, bone_name, world):
		queue_redraw()


## --- 插槽与附件（换装） ---


## 指定插槽在全部皮肤中出现过的附件名列表（换装可选项）。
func get_attachment_names(slot_name: String) -> PackedStringArray:
	if _data == null or not _data.is_skeleton_data_loaded():
		return PackedStringArray()
	return _data.get_attachment_names(slot_name)


## 插槽当前显示的附件名；无附件为空字符串。
func get_slot_attachment(slot_name: String) -> String:
	if not is_loaded() or _data == null:
		return ""
	return _data.get_slot_attachment(_instance_handle, slot_name)


## 替换插槽附件（空名清空插槽）。失败返回 false 并写 last_error。
func set_attachment(slot_name: String, attachment_name: String) -> bool:
	if not is_loaded() or _data == null:
		return false
	var ok := _data.set_attachment(_instance_handle, slot_name, attachment_name)
	if ok:
		queue_redraw()
	else:
		last_error = _data.get_last_error()
	return ok


## --- 皮肤 ---


## 切换皮肤；皮肤名不存在返回 false。
func set_skin(skin_name: String) -> bool:
	if not is_loaded() or _data == null:
		return false
	var ok := _data.set_skin(_instance_handle, skin_name)
	if ok:
		queue_redraw()
	else:
		last_error = _data.get_last_error()
	return ok


## 皮肤组合：按顺序叠加多个皮肤并应用（后者覆盖前者），
## 官方 new_skin + add_skin 流程的等价物。任一皮肤不存在返回 false
## 且不改变现有皮肤。
func set_combined_skin(skin_names: PackedStringArray) -> bool:
	if not is_loaded() or _data == null:
		return false
	var ok := _data.set_combined_skin(_instance_handle, skin_names)
	if ok:
		queue_redraw()
	else:
		last_error = _data.get_last_error()
	return ok


## --- 骨架整体状态 ---


## 实例整体颜色（乘进全部顶点色）；未加载时返回白色。
func get_skeleton_color() -> Color:
	if not is_loaded() or _data == null:
		return Color.WHITE
	return _data.get_skeleton_color(_instance_handle)


## 设置实例整体颜色（各分量 0–1）。失败返回 false。
func set_skeleton_color(color: Color) -> bool:
	if not is_loaded() or _data == null:
		return false
	var ok := _data.set_skeleton_color(_instance_handle, color)
	if ok:
		queue_redraw()
	else:
		last_error = _data.get_last_error()
	return ok


## 实例骨架空间状态（x/y/scale_x/scale_y/time）；未加载时为空字典。
func get_skeleton_state() -> Dictionary:
	if not is_loaded() or _data == null:
		return {}
	return _data.get_skeleton_state(_instance_handle)


## 修改实例骨架空间状态（部分字段字典；scale 不允许 0）。
func set_skeleton_state(state: Dictionary) -> bool:
	if not is_loaded() or _data == null:
		return false
	var ok := _data.set_skeleton_state(_instance_handle, state)
	if ok:
		queue_redraw()
	else:
		last_error = _data.get_last_error()
	return ok


## --- SB-07：官方风格对象包装（对齐官方 SpineSprite.get_skeleton / get_animation_state） ---

## SB-09 收口（官方缓存身份）：官方 SpineSprite 持有单个 SpineSkeleton Ref，
## get_skeleton 每次返回同一对象；本地对齐——同一实例复用同一包装，
## find_bone/find_slot 的缓存身份因此跨调用成立。资源重建/卸载时清空
##（_release），旧包装经 is_valid() 确定失效。
var _skeleton_object: SpineSkeleton = null


## 官方 SpineSprite.get_skeleton 等价：返回绑定当前实例的 SpineSkeleton 包装对象；
## 未加载时为 null。实例销毁/资源替换后旧对象 is_valid() 为 false。
func get_skeleton() -> SpineSkeleton:
	if not is_loaded() or _data == null:
		return null
	if _skeleton_object != null and _skeleton_object.is_valid():
		return _skeleton_object
	var skeleton := _data.get_skeleton_object(_instance_handle)
	if skeleton != null:
		skeleton._set_display_node(self)
		_skeleton_object = skeleton
	return skeleton


## 官方 SpineSprite.get_animation_state 等价：返回绑定当前实例的
## SpineAnimationState 包装对象；未加载时为 null。
func get_animation_state() -> SpineAnimationState:
	if not is_loaded() or _data == null:
		return null
	return _data.get_animation_state_object(_instance_handle)


## --- TrackEntry 控制（修改轨道当前条目） ---


func set_track_loop(track: int, loop: bool) -> bool:
	if not is_loaded() or _data == null:
		return false
	return _animation_result(_data.set_track_loop(_instance_handle, track, loop), false)


func set_track_time_scale(track: int, value: float) -> bool:
	if not is_loaded() or _data == null:
		return false
	return _animation_result(_data.set_track_time_scale(_instance_handle, track, value), false)


func set_track_alpha(track: int, value: float) -> bool:
	if not is_loaded() or _data == null:
		return false
	return _animation_result(_data.set_track_alpha(_instance_handle, track, value), false)


func set_track_delay(track: int, value: float) -> bool:
	if not is_loaded() or _data == null:
		return false
	return _animation_result(_data.set_track_delay(_instance_handle, track, value), false)


func set_track_time(track: int, value: float) -> bool:
	if not is_loaded() or _data == null:
		return false
	return _animation_result(_data.set_track_time(_instance_handle, track, value), false)


func set_track_mix_duration(track: int, value: float) -> bool:
	if not is_loaded() or _data == null:
		return false
	return _animation_result(_data.set_track_mix_duration(_instance_handle, track, value), false)


func _animation_result(ok: bool, start_playback: bool) -> bool:
	last_error = "" if ok else _data.get_last_error()
	if ok:
		if start_playback and not Engine.is_editor_hint():
			is_playing = true
		queue_redraw()
	return ok


## SpineSprite 与 SpineSprite3D 在实例上注册同步事件回调。
func _set_animation_event_dispatch_enabled(enabled: bool) -> void:
	if _animation_event_dispatch_enabled == enabled:
		return
	_animation_event_dispatch_enabled = enabled
	_sync_animation_event_callback()


## 仅供 SpineSprite 设置同步事件/更新阶段的外观宿主；WeakRef 不改变节点
## 所有权或资源生命周期。
func _set_event_dispatch_owner(owner: Node) -> void:
	_event_dispatch_owner = weakref(owner) if owner != null else null


func _sync_animation_event_callback() -> void:
	if _data == null or _instance_handle == 0:
		return
	if _animation_event_dispatch_enabled:
		_data.set_immediate_event_callback(
				_instance_handle, Callable(self, "_on_animation_events"))
	else:
		_data.clear_immediate_event_callback(_instance_handle)


## 由 SpineSkeletonDataResource 在相关原生操作返回前同步调用。
func _on_animation_events(events: Array) -> void:
	if not _animation_event_dispatch_enabled or _data == null or not is_loaded() \
			or not is_inside_tree() or is_queued_for_deletion() \
			or not _has_active_event_dispatch_owner():
		return
	_animation_event_generation += 1
	var batch_generation := _animation_event_generation
	# 空批不产生 Godot 信号，但仍表示一个在监听者中发起的状态操作已经
	# 返回；递增 generation 可令其外层事件批停止。
	if events.is_empty():
		return
	var source := _data
	var instance := _instance_handle
	var state_obj: SpineAnimationState = source.get_animation_state_object(instance)
	for event: Dictionary in events:
		if not _can_emit_animation_event(source, instance, state_obj, batch_generation):
			break
		var event_type := str(event["type"])
		var entry_obj: SpineTrackEntry = source.get_track_entry_object(
				instance, event.get("entry_handle", 0))
		if event_type == "event":
			var event_obj: SpineEvent = source.get_event_object(event)
			emit_signal("animation_event", self, state_obj, entry_obj, event_obj)
		else:
			emit_signal("animation_" + event_type, self, state_obj, entry_obj)
		if not _can_emit_animation_event(source, instance, state_obj, batch_generation):
			break


func _can_emit_animation_event(source: SpineSkeletonDataResource, instance: int,
		state: SpineAnimationState, batch_generation: int) -> bool:
	return _animation_event_generation == batch_generation \
		and is_inside_tree() and not is_queued_for_deletion() \
		and _data == source and _instance_handle == instance \
		and state != null and state.is_valid() \
		and _has_active_event_dispatch_owner()


func _has_active_event_dispatch_owner() -> bool:
	if _event_dispatch_owner == null:
		return true
	var owner := _event_dispatch_owner.get_ref() as Node
	return owner != null and is_instance_valid(owner) \
		and owner.is_inside_tree() and not owner.is_queued_for_deletion()


## 停止自动推进动画（画面停在当前帧）。不影响 update_skeleton() 显式手动更新。
func pause() -> void:
	is_playing = false


## 继续自动推进动画。仅当运行时实例已加载时生效；暂停期间不累积追赶时间。
func resume() -> void:
	if _instance_handle != 0 and not Engine.is_editor_hint():
		is_playing = true


## 当前骨架包含的动画名列表；未加载时为空。
func get_animation_names() -> PackedStringArray:
	if _data == null or not _data.is_skeleton_data_loaded():
		return PackedStringArray()
	return _data.get_animation_names()


## 当前实例的世界坐标包围盒（x / y / width / height）；未加载时为空字典。
func get_bounds() -> Dictionary:
	if _instance_handle == 0 or _data == null:
		return {}
	return _data.get_instance_bounds(_instance_handle)


## SB-26A：供 3D 外观层消费当前帧。Godot 3D 类型不进入 Bridge/Provider，
## 这里仅转发既有版本中立的 Dictionary/PackedArray 帧协议。
func _get_render_commands_for_external_consumer() -> Array:
	if _instance_handle == 0 or _data == null:
		return []
	return _data.get_render_commands(_instance_handle)


## SB-26B：供 3D 插槽节点消费当前 draw order 行。
## 只转发版本中立 Dictionary/PackedArray，不把 Godot 3D 类型送入 Bridge。
func _get_slot_render_rows_for_external_consumer() -> Array:
	if _instance_handle == 0 or _data == null:
		return []
	return _data.get_slot_render_commands(_instance_handle)


func _draw() -> void:
	_draw_skeleton()
	_draw_debug()


## 原有骨架绘制路径（v1 单材质 / v2 逐 draw 材质）。
func _draw_skeleton() -> void:
	if not render_enabled or _instance_handle == 0 or _data == null:
		return
	# v1 批量路径的网格仅由本帧 draw_mesh 命令引用（canvas_item_clear 先于
	# 本函数执行），可每帧新建；v2 路径自 SB-23D（D1）起改为常驻网格 +
	# 区域更新（见 _update_v2_mesh），RS 侧缓冲即渲染消费数据。
	#
	# 坐标系：spine-cpp 4.3 默认 Bone::yDown = true，世界坐标 Y 轴向下、
	# 与 Godot 画布一致，顶点直接使用，不做任何翻转（也不要改绕序——
	# 2D 画布不背面剔除，翻转曾导致角色倒置）。
	# SB-25B：每次重绘刷新 HDR-2D 判定（§12.8；双色 uniform 颜色转换）。
	_refresh_v2_hdr_2d()
	_mesh_pool.clear()
	# 登记清单可能残留已释放节点（节点 free 后 typed Array 仍持有悬空引用）；
	# 先清理再判断，否则空清单被误判为"有挂件"，永远不会走批量路径。
	_prune_slot_nodes()
	if not _slot_nodes.is_empty():
		_draw_slots()
		return
	_clear_slot_meshes()
	# SB-23D（D2）：v2 批量路径优先由原生消费者（Bridge C++）读帧并
	# 提交网格数据/纹理/可见性（consume_frame + sync_nodes），材质选择
	# 保留在 GDScript（插槽节点材质、sprite 覆盖、用户材质、内置 shader
	# 材质与 HDR 判定都是本节点状态）。消费失败、旧 provider 或禁用时
	# 回退既有 Dictionary 路径（v1 指令共用）。
	if _try_draw_v2_native():
		return
	var commands: Array = _data.get_render_commands(_instance_handle)
	# SB-10 v2：带 blend_mode 键的指令走逐 draw 材质路径；v1 指令保持
	# draw_mesh 原路径（渲染与现状逐位一致）。空帧两路径等价（无绘制），
	# 批量识别无需空帧标记；行级版本标记（"commands"）属逐槽路径（SB10-R1）。
	if commands.size() > 0 and commands[0].has("blend_mode"):
		# SB-23C（步骤 1）：v2 批量路径不再每帧 _clear_draw_meshes()；
		# 池由 _sync_v2_mesh_pool 按活动命令数复用/增减（命令减少由
		# 函数尾部 while 收缩释放，空帧下帧落入 v1 分支即时清空）。
		_draw_v2_batch(commands)
		return
	# v1 批量/空帧/旧 provider 回退：释放 v2 池节点，避免旧帧网格残留。
	_clear_draw_meshes()
	for command in commands:
		var texture: Texture2D = _data.get_page_texture(command["page_index"])
		var indices: PackedInt32Array = command["indices"]
		if texture == null or indices.is_empty():
			continue

		var mesh := _make_mesh(command)
		_mesh_pool.append(mesh)
		draw_mesh(mesh, texture)


## SB-13：官方 Debug 组绘制（仅编辑器）。骨骼世界变换走版本中立
## get_bone_world_transform；附件几何走 v1.16 调试几何通道（SB13-R1/R2）。
func _draw_debug() -> void:
	if not Engine.is_editor_hint() or not render_enabled \
			or _instance_handle == 0 or _data == null:
		return
	_sync_debug_mesh_order()
	if root:
		_draw_debug_root()
	if bones:
		_draw_debug_bones()
	for op in _debug_draw_ops():
		match op["type"]:
			"polyline":
				draw_polyline(op["points"], op["color"], op["width"])
			"multiline":
				draw_multiline(op["points"], op["color"], op["width"])
			"line":
				draw_line(op["from"], op["to"], op["color"], op["width"])


func _sync_debug_mesh_order() -> void:
	var enabled: bool = root or bones or regions or meshes or bounding_boxes or paths or clipping
	if enabled == _debug_meshes_behind_parent:
		return
	_debug_meshes_behind_parent = enabled
	for mesh in _draw_meshes:
		mesh.show_behind_parent = enabled
	for mesh in _slot_meshes:
		mesh.show_behind_parent = enabled


func _draw_debug_root() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or not skeleton.is_valid():
		return
	var root_bone := skeleton.get_root_bone()
	if root_bone != null:
		_draw_debug_bone(root_bone, root_color)


func _draw_debug_bones() -> void:
	if _debug_bone_names.is_empty():
		_build_debug_bone_cache()
	var count := _debug_bone_names.size()
	if count == 0:
		return
	var points := PackedVector2Array()
	points.resize(count * 4)
	var thickness: float = maxf(bones_thickness, 0.1)
	for i in range(count):
		var transform := _bone_local_transform(_debug_bone_names[i])
		var length: float = _debug_bone_lengths[i]
		if is_zero_approx(length):
			length = thickness * 2.0
		var vertex := i * 4
		points[vertex] = transform * Vector2(-thickness, 0)
		points[vertex + 1] = transform * Vector2(0, thickness)
		points[vertex + 2] = transform * Vector2(length, 0)
		points[vertex + 3] = transform * Vector2(0, -thickness)
	RenderingServer.canvas_item_add_triangle_array(
			get_canvas_item(), _debug_bone_indices, points, PackedColorArray([bones_color]))


func _build_debug_bone_cache() -> void:
	if _data == null:
		return
	for name in _data.get_bone_names():
		var info: Dictionary = _data.get_bone_data(name)
		if info.is_empty():
			continue
		_debug_bone_names.append(name)
		_debug_bone_lengths.append(float(info.get("length", 0.0)))
	_debug_bone_indices.resize(_debug_bone_names.size() * 6)
	for i in range(_debug_bone_names.size()):
		var vertex := i * 4
		var index := i * 6
		_debug_bone_indices[index] = vertex
		_debug_bone_indices[index + 1] = vertex + 1
		_debug_bone_indices[index + 2] = vertex + 2
		_debug_bone_indices[index + 3] = vertex
		_debug_bone_indices[index + 4] = vertex + 2
		_debug_bone_indices[index + 5] = vertex + 3


func _draw_debug_bone(bone: SpineBone, color: Color) -> void:
	var points := _debug_bone_points(bone, maxf(bones_thickness, 0.1))
	if not points.is_empty():
		draw_colored_polygon(points, color)


func _debug_bone_points(bone: SpineBone, thickness: float) -> PackedVector2Array:
	var data := bone.get_data()
	if data == null:
		return PackedVector2Array()
	var transform := _bone_local_transform(bone.get_name())
	var length: float = data.get_length()
	if is_zero_approx(length):
		length = thickness * 2.0
	# 与官方 SpineSprite::draw_bone 相同的菱形，沿骨骼自身方向绘制。
	return PackedVector2Array([
		transform * Vector2(-thickness, 0),
		transform * Vector2(0, thickness),
		transform * Vector2(length, 0),
		transform * Vector2(0, -thickness),
	])


## SB-13 修复轮：调试几何条目的附件类型（与 ABI SB_AttachmentKind 一致）。
const DEBUG_ATTACHMENT_REGION := 1
const DEBUG_ATTACHMENT_MESH := 2
const DEBUG_ATTACHMENT_BOUNDING_BOX := 3
const DEBUG_ATTACHMENT_PATH := 4
const DEBUG_ATTACHMENT_CLIPPING := 5


## SB-13 修复轮（SB13-R1/R2）：按当前 Debug 开关把几何通道条目分类为绘制
## 原语，_draw_debug 提交这些原语，定向测试直接断言分类结果。
## 元素为：
##   {"type": "polyline", "points": PackedVector2Array, "color": Color, "width": float}
##   {"type": "multiline", "points": PackedVector2Array, "color": Color, "width": float}
##   {"type": "line", "from": Vector2, "to": Vector2, "color": Color, "width": float}
## 仅编辑器内且有几何数据时返回非空；导出运行不进入该路径。
func _debug_draw_ops() -> Array[Dictionary]:
	var ops: Array[Dictionary] = []
	if not Engine.is_editor_hint() or _instance_handle == 0 or _data == null:
		return ops
	if not (regions or meshes or bounding_boxes or paths or clipping):
		return ops
	if _data.has_debug_geometry_capability():
		for item in _data.get_debug_geometry(_instance_handle):
			_append_debug_geometry_ops(ops, item)
	else:
		# 旧 provider（无 v1.16 通道）回退：渲染帧“四顶点六索引”近似判定。
		_append_legacy_debug_ops(ops)
	return ops


## SB-13 修复轮：显式附件类型分派（SB13-R1：区域不再依赖顶点数量猜测）。
func _append_debug_geometry_ops(ops: Array[Dictionary], item: Dictionary) -> void:
	var vertices: PackedVector2Array = item.get("vertices", PackedVector2Array())
	if vertices.size() < 2:
		return
	match int(item.get("kind", 0)):
		DEBUG_ATTACHMENT_REGION:
			if regions:
				var indices: PackedInt32Array = item.get("indices", PackedInt32Array())
				_append_mesh_edges(ops, vertices, indices, regions_color)
				_append_polyline_op(ops, vertices, regions_color, true, 2.0)
		DEBUG_ATTACHMENT_MESH:
			if meshes:
				var indices: PackedInt32Array = item.get("indices", PackedInt32Array())
				_append_mesh_edges(ops, vertices, indices, meshes_color)
		DEBUG_ATTACHMENT_BOUNDING_BOX:
			if bounding_boxes:
				_append_polyline_op(ops, vertices, bounding_boxes_color, true, 2.0)
		DEBUG_ATTACHMENT_PATH:
			if paths:
				_append_polyline_op(ops, vertices, paths_color, bool(item.get("closed", false)))
		DEBUG_ATTACHMENT_CLIPPING:
			if clipping:
				_append_polyline_op(ops, vertices, paths_clipping, true, 2.0)


## 轮廓线：绘制多边形边界，闭合时补回起点（draw_polyline 不自动闭合）。
func _append_polyline_op(ops: Array[Dictionary], points: PackedVector2Array,
		color: Color, closed: bool, width: float = 1.0) -> void:
	if points.size() < 2:
		return
	var outline := points
	if closed and points[0] != points[points.size() - 1]:
		outline = points.duplicate()
		outline.append(points[0])
	ops.append({"type": "polyline", "points": outline, "color": color, "width": width})


func _append_line_op(ops: Array[Dictionary], from: Vector2, to: Vector2, color: Color) -> void:
	ops.append({"type": "line", "from": from, "to": to, "color": color, "width": 1.0})


func _append_mesh_edges(ops: Array[Dictionary], vertices: PackedVector2Array,
		indices: PackedInt32Array, color: Color) -> void:
	var segments := PackedVector2Array()
	for i in range(0, indices.size() - 2, 3):
		var a := indices[i]
		var b := indices[i + 1]
		var c := indices[i + 2]
		if a < 0 or b < 0 or c < 0 or a >= vertices.size() \
				or b >= vertices.size() or c >= vertices.size():
			continue
		segments.append(vertices[a])
		segments.append(vertices[b])
		segments.append(vertices[b])
		segments.append(vertices[c])
		segments.append(vertices[c])
		segments.append(vertices[a])
	if not segments.is_empty():
		ops.append({"type": "multiline", "points": segments, "color": color, "width": 1.0})


## SB13-R1 回退路径：旧 provider 的渲染帧没有附件类型，只能按“四顶点 + 六
## 索引”判定区域（原实现把顶点数写成 float 数量 8，区域永远不命中）。
func _append_legacy_debug_ops(ops: Array[Dictionary]) -> void:
	for command in _data.get_render_commands(_instance_handle):
		var positions: PackedVector2Array = command.get("positions", PackedVector2Array())
		var indices: PackedInt32Array = command.get("indices", PackedInt32Array())
		if positions.size() < 3 or indices.is_empty():
			continue
		var is_region := positions.size() == 4 and indices.size() == 6
		if regions and is_region:
			_append_polyline_op(ops, positions, regions_color, true)
		elif meshes and not is_region:
			_append_mesh_edges(ops, positions, indices, meshes_color)


## SB-10 v2 批量路径：逐 draw 提交内部 MeshInstance2D 并按 blend/has_dark
## 选择内置 premult 变体材质（§12.8）。screen（编号 3，保留未支持）回退
## normal 绘制，不静默丢 draw。
## SB-23D（D2）：本函数降为 Dictionary 回退路径（原生消费失败/禁用/旧
## provider 时使用）；主路径见 _try_draw_v2_native。
func _draw_v2_batch(commands: Array) -> void:
	_sync_v2_mesh_pool(_draw_meshes, commands.size())
	for i in range(commands.size()):
		_submit_v2_command(_draw_meshes[i], commands[i])


## SB-23D（D2）：原生渲染消费路径（v2 批量）。消费者由资源层创建
## （Bridge C++ 读 provider v2 帧并把网格数据提交到其内部 ArrayMesh 池，
## 无逐 draw Dictionary/PackedArray 装配与 GDScript 逐顶点循环）；本节点
## 仅保留材质选择与池节点管理。返回 false 表示本帧需回退 Dictionary 路径。
## 回退不变式：任何一帧走 _draw_v2_batch（GDScript 重建网格）时
## _v2_consumer 必为 null——否则消费者跨回退帧的缓存状态会与 RS 侧内容
## 错位（三个 false 分支都丢弃消费者，重新启用后全量重建）。
func _try_draw_v2_native() -> bool:
	if _v2_native_render_disabled:
		_v2_consumer = null
		return false
	if _v2_native_unavailable:
		return false
	if _v2_consumer == null:
		_v2_consumer = _data.create_render_consumer(_instance_handle)
		if _v2_consumer == null:
			# 无 v2 能力（旧 provider）或资源未就绪：本次加载周期内不再
			# 逐帧重试；_release/_load_from_resource 复位。
			_v2_native_unavailable = true
			return false
		# SB-23D（D3）：新消费者的逐 draw 变化掩码无上帧基准（全脏）；
		# 递增输入代数使材质缓存整体失效。
		_v2_material_state_gen += 1
	var info: Dictionary = _v2_consumer.consume_frame()
	if not bool(info.get("ok", false)):
		# v2 读取/校验失败：丢弃消费者（其网格仍被池节点引用，回退路径
		# 会在同批网格上重建表面）；下一帧重新探测创建，避免新旧状态混用。
		_v2_consumer = null
		return false
	_v2_last_native_info = info
	_sync_v2_mesh_pool(_draw_meshes, int(info["draw_count"]))
	_v2_consumer.sync_nodes(_draw_meshes)
	_apply_v2_materials(info)
	return true


## SB-23D（D2）：原生路径的逐 draw 材质选择（纹理/可见性已由消费者
## sync_nodes 提交）。输入为 consume_frame 返回的紧凑提交信息；材质
## 选择顺序与 _select_v2_material（Dictionary 路径）完全一致（§12.8）。
## SB-23D（D3）：变化标记——无插槽节点时仅对输入变化（consume_frame 的
## changed 掩码）或缓存失效后的 draw 重选材质，其余沿用上次结果；选择
## 顺序与逐帧全量重选完全一致。插槽节点在场时保持逐帧全量选择（插槽
## 材质可由用户随时修改，无失效信号）。用户整节点 material 无法在脚本
## 拦截（SB11-R1），在重绘帧内轮询比较并令缓存失效（静态角色另由
## _sync_v2_self_modulate 的树级轮询兜底）。
func _apply_v2_materials(info: Dictionary) -> void:
	var user_mat: Material = material if material != _auto_page_material else null
	if user_mat != _v2_user_material:
		_v2_user_material = user_mat
		_v2_material_state_gen += 1
	var count := int(info["draw_count"])
	if count <= 0 or count > _draw_meshes.size():
		count = minf(count, _draw_meshes.size())
	var blends: PackedInt32Array = info["blends"]
	var flags: PackedByteArray = info["flags"]
	var lights: PackedColorArray = info["lights"]
	var darks: PackedColorArray = info["darks"]
	var pages: PackedInt32Array = info["pages"]
	var page_normals: Array = info["page_normals"]
	var slot_indices: PackedInt32Array = info["slot_indices"]
	var slot_names: Array = info["slot_names"]
	var use_slot_materials := not _slot_nodes.is_empty()
	if _v2_material_cache.size() != count:
		_v2_material_cache.resize(count)
	if not use_slot_materials and _v2_material_cache_gen == _v2_material_state_gen:
		# 快路径：仅重选输入变化或池重建后未赋值的 draw。
		var changed: PackedByteArray = info["changed"]
		for i in range(count):
			if i >= _v2_material_applied_size or changed[i] != 0:
				_v2_select_and_apply_material(i, blends, flags, lights, darks,
						pages, page_normals, slot_indices, slot_names)
		_v2_material_applied_size = count
		return
	for i in range(count):
		_v2_select_and_apply_material(i, blends, flags, lights, darks,
				pages, page_normals, slot_indices, slot_names)
	_v2_material_cache_gen = _v2_material_state_gen
	_v2_material_applied_size = count


## SB-23D（D3）：按提交信息选择并赋值第 i 个 draw 的材质（缓存路径与
## 全量路径共用；选择结果写入逐 draw 缓存）。
func _v2_select_and_apply_material(i: int, blends: PackedInt32Array,
		flags: PackedByteArray, lights: PackedColorArray, darks: PackedColorArray,
		pages: PackedInt32Array, page_normals: Array,
		slot_indices: PackedInt32Array, slot_names: Array) -> void:
	var blend := blends[i]
	var flag := flags[i]
	var page_index := pages[i]
	var normal_tex: Texture2D = null
	if page_index >= 0 and page_index < page_normals.size():
		normal_tex = page_normals[page_index]
	var slot_name := ""
	if not _slot_nodes.is_empty():
		var slot_index := slot_indices[i]
		if slot_index >= 0 and slot_index < slot_names.size():
			slot_name = str(slot_names[slot_index])
	var selected: Material = _select_v2_material_for(blend,
			(flag & 2) != 0, (flag & 1) != 0, lights[i], darks[i],
			normal_tex, slot_name)
	_draw_meshes[i].material = selected
	_v2_material_cache[i] = selected


## 调整内部 mesh 池到 target 数量（新增节点挂到内部子节点最前，普通子节点
## 保持在骨架之上；use_parent_material=false——v2 draw 不继承整节点材质）。
## SB10-R1：每帧对全池显式归位 v2 模式——池内可能残留另一路径预建的节点
## （use_parent_material=true 会忽略逐 draw 材质）。SB10-R2：镜像角色
## self_modulate——子节点只继承 modulate、不继承自身调制；镜像后内部网格
## 合成调制 = modulate（继承）× self_modulate，与 v1 批量 draw_mesh 施加于
## 节点自身画布一致；普通挂件不是内部网格，不受镜像影响。
func _sync_v2_mesh_pool(pool: Array[MeshInstance2D], target: int,
		normalize: bool = false) -> void:
	var created := false
	while pool.size() < target:
		var mesh := MeshInstance2D.new()
		# SB-23D（D3）：v2 模式属性在创建时设置（原每帧全池归位循环改为
		# 变化标记；批量池节点仅由本函数创建，逐槽池另走 normalize 分支）。
		mesh.use_parent_material = false
		mesh.modulate = self_modulate
		mesh.light_mask = light_mask
		mesh.show_behind_parent = _debug_meshes_behind_parent
		add_child(mesh, false, Node.INTERNAL_MODE_FRONT)
		pool.append(mesh)
		created = true
	while pool.size() > target:
		pool.pop_back().free()
	if created:
		# 新节点 material 为 null，需重新赋值：递增材质选择输入代数使
		# 批量路径的逐 draw 材质缓存整体失效（逐槽路径的递增只是多余
		# 失效，不改变行为）。
		_v2_material_state_gen += 1
	if normalize:
		# 逐槽池可能残留 v1 路径预建节点（use_parent_material=true、白色
		# 调制），保持每帧全量归位（SB10-R1 语义；该池规模随插槽节点数，
		# 非每帧热路径）。
		for mesh in pool:
			mesh.use_parent_material = false
			mesh.modulate = self_modulate
			# SB-11：v2 内部网格是独立画布项，默认 light_mask=1 不会跟随本
			# 节点；转发 light_mask 使 2D 灯光工作流可操作（对齐官方
			# update_meshes 逐帧设置 mesh light_mask，SpineSprite.cpp:1079）。
			mesh.light_mask = light_mask
	elif self_modulate != _v2_self_modulate or light_mask != _v2_light_mask:
		# 变化帧镜像调制/掩码（缓存与 _sync_v2_self_modulate 共享；静态
		# 角色由树级轮询兜底，变化帧仍与本函数原行为同帧生效）。
		var modulate_changed := self_modulate != _v2_self_modulate
		var mask_changed := light_mask != _v2_light_mask
		_v2_self_modulate = self_modulate
		_v2_light_mask = light_mask
		for mesh in pool:
			if modulate_changed:
				mesh.modulate = self_modulate
			if mask_changed:
				mesh.light_mask = light_mask


## SB10-R2：把 self_modulate 的运行时变化同步到 v2 内部网格。重绘帧已由
## _sync_v2_mesh_pool 镜像；本函数覆盖不再重绘的静态角色——画布项调制是
## RenderingServer 属性，修改后无需重绘即生效。挂接点为 SceneTree.process_frame
## （_enter_tree 连接、_exit_tree 断开）：树级信号不随节点暂停停止，暂停期间
## 修改/修改后立即暂停均在下一渲染帧同步，且不推进暂停中的骨架动画（不依赖
## 角色的 _process/_physics_process 运行）；v1 批量路径调制作用于自身画布项，
## 无需镜像。
## SB-11：light_mask 同样不经父子画布级联，逐帧同步到 v2 内部网格（对齐官方
## update_meshes 每帧设置 mesh light_mask，SpineSprite.cpp:1079）。
## SB11-R1：用户整节点材质变化触发重绘（v2 逐 draw 材质在重绘时经
## _select_v2_material 重选；material setter 无法在脚本拦截，走同一轮询通道）。
## SB-23D（D3）：材质变化同时递增材质选择输入代数——本函数先于重绘运行，
## 若不递增，_apply_v2_materials 的重绘帧内轮询会因缓存已同步而漏判变化。
func _sync_v2_self_modulate() -> void:
	var mask_changed := light_mask != _v2_light_mask
	var user_mat := material if material != _auto_page_material else null
	var material_changed := user_mat != _v2_user_material
	if self_modulate == _v2_self_modulate and not mask_changed and not material_changed:
		return
	_v2_self_modulate = self_modulate
	for mesh in _draw_meshes:
		mesh.modulate = self_modulate
	if _slot_meshes_v2:
		for mesh in _slot_meshes:
			mesh.modulate = self_modulate
	if mask_changed:
		_v2_light_mask = light_mask
		for mesh in _draw_meshes:
			mesh.light_mask = light_mask
		if _slot_meshes_v2:
			for mesh in _slot_meshes:
				mesh.light_mask = light_mask
	if material_changed:
		_v2_user_material = user_mat
		_v2_material_state_gen += 1
		queue_redraw()


## 提交单条 v2 指令：网格 + 纹理（含法线页 CanvasTexture）+ 逐 draw 材质；
## 缺贴图/空索引时隐藏该项。
func _submit_v2_command(mesh: MeshInstance2D, command: Dictionary) -> void:
	var texture: Texture2D = _page_texture_for_lighting(int(command["page_index"]))
	var indices: PackedInt32Array = command["indices"]
	if texture == null or indices.is_empty():
		mesh.visible = false
		return
	mesh.visible = true
	mesh.texture = texture
	_update_v2_mesh(mesh, command)
	mesh.material = _select_v2_material(command)


## SB-11：取该页参与渲染的纹理。页面带法线贴图时返回页级 CanvasTexture
## （diffuse + normal，Godot 2D 灯光管线经内建 NORMAL_TEXTURE 通道消费，
## 自定义材质与内置材质均生效）；无法线页直接返回 diffuse（无行为变化）。
## 缓存按 page_index 复用；_release 时清空。
func _page_texture_for_lighting(page_index: int) -> Texture2D:
	var diffuse: Texture2D = _data.get_page_texture(page_index)
	if diffuse == null:
		return null
	var normal: Texture2D = _data.get_page_normal_texture(page_index)
	if normal == null:
		return diffuse
	if not _v2_page_canvas_textures.has(page_index):
		var canvas := CanvasTexture.new()
		canvas.diffuse_texture = diffuse
		canvas.normal_texture = normal
		_v2_page_canvas_textures[page_index] = canvas
	return _v2_page_canvas_textures[page_index]


## v2 网格：无 dark draw 顶点色保持 light（straight，与 v1 相同结构，COLOR =
## light×M）；has_dark draw 顶点色留白（COLOR = 纯 M），light/dark 由材质
## uniform 携带，保证 light=0 时 dark 仍受节点调制（§12.8）。
## SB-23D（D1，对齐官方 SpineMesh2D::update_mesh 动态更新路径）：
## - 重建触发：无快路径状态、网格对象（RID）变更、顶点数/索引数变化、
##   索引内容变化、has_dark 标记变化（布局/索引/裁剪几何/双色格式变化
##   均落在这些条件内——裁剪输出改变顶点/索引计数，双色格式变化以
##   has_dark 触发保守重建）。重建时清面并以
##   ARRAY_FLAG_USE_DYNAMIC_UPDATE 重新加面（该 flag 成为表面 format 的
##   一部分，GLES 侧选择动态缓冲，RD 渲染器无副作用）。
## - 稳定帧：只更新顶点区域（positions.to_byte_array()，要求 VERTEX
##   单独占用 8 字节步长的布局，创建后已验证）；COLOR/UV 变化时按
##   各自偏移改写属性字节并整体提交属性区域（RS 无部分区域提交）。两者
##   分别检测：mono draw 颜色变化写 COLOR 字节，UV 变化写 UV 字节；
##   has_dark draw 的 COLOR 恒为白，不参与属性重写。
## - 每帧同步 custom AABB（对齐官方 mesh_set_custom_aabb）并 queue_redraw
##   重加画布命令，剔除矩形（Item::rect 缓存）随命令重分配刷新。
## 所有权：ArrayMesh 归池节点，表面数据归其 RID，跨帧状态缓存在节点 meta
## （随节点释放销毁）；渲染直接消费 RS 侧当前缓冲，不依赖网格对象重建。
## 颜色→RGBA8 量化与 Godot 表面打包一致（clamp 后截断），快路径与重建
## 路径逐字节一致。绘制命令引用 mesh RID，区域更新后无需重建网格对象。
func _update_v2_mesh(node: MeshInstance2D, command: Dictionary) -> void:
	var mesh := node.mesh as ArrayMesh
	if mesh == null:
		mesh = ArrayMesh.new()
		node.mesh = mesh
	var positions: PackedVector2Array = command["positions"]
	var uvs: PackedVector2Array = command["uvs"]
	var colors: PackedColorArray = command["colors"]
	var indices: PackedInt32Array = command["indices"]
	var has_dark := bool(command.get("has_dark", false))
	var state: Dictionary = node.get_meta("_spine_v2_mesh_state", {})
	var rebuild: bool = not state.get("fast", false) \
			or state.get("rid", RID()) != mesh.get_rid() \
			or state.get("nv", -1) != positions.size() \
			or state.get("ni", -1) != indices.size() \
			or state.get("has_dark", false) != has_dark \
			or state.get("idx", PackedInt32Array()) != indices
	if rebuild:
		mesh.clear_surfaces()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = positions
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		if has_dark:
			# SB-23C 修复：Dictionary.get() 缺键返回 null，不能直接赋给强类型
			# PackedColorArray（函数中断导致 has_dark draw 丢失）；先 has() 判断。
			var size := colors.size()
			var white: PackedColorArray
			if _v2_white_arrays.has(size):
				white = _v2_white_arrays[size]
			else:
				white = PackedColorArray()
				white.resize(size)
				white.fill(Color.WHITE)
				_v2_white_arrays[size] = white
			arrays[Mesh.ARRAY_COLOR] = white
		else:
			arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {},
				Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
		state = _capture_v2_mesh_state(node, mesh, positions, uvs, colors, indices,
				has_dark)
	else:
		var rid: RID = state["rid"]
		# 顶点区域：VERTEX 单独占用 8 字节步长（创建时已验证），
		# positions.to_byte_array() 即该区域的完整内容。
		RenderingServer.mesh_surface_update_vertex_region(rid, 0, 0,
				positions.to_byte_array())
		var uvs_changed: bool = uvs != state["uvs"]
		var colors_changed: bool = not has_dark and colors != state["colors"]
		if uvs_changed or colors_changed:
			var ab: PackedByteArray = state["ab"]
			var astride: int = state["astride"]
			if uvs_changed:
				var uoff: int = state["uoff"]
				for i in uvs.size():
					var uv := uvs[i]
					var o := i * astride + uoff
					ab.encode_float(o, uv.x)
					ab.encode_float(o + 4, uv.y)
			if colors_changed:
				var coff: int = state["coff"]
				for i in colors.size():
					var c := colors[i]
					var o := i * astride + coff
					ab.encode_u8(o, int(clampf(c.r * 255.0, 0.0, 255.0)))
					ab.encode_u8(o + 1, int(clampf(c.g * 255.0, 0.0, 255.0)))
					ab.encode_u8(o + 2, int(clampf(c.b * 255.0, 0.0, 255.0)))
					ab.encode_u8(o + 3, int(clampf(c.a * 255.0, 0.0, 255.0)))
			RenderingServer.mesh_surface_update_attribute_region(rid, 0, 0, ab)
			state["uvs"] = uvs
			state["colors"] = colors
	var rid: RID = state["rid"]
	RenderingServer.mesh_set_custom_aabb(rid, _positions_aabb(positions))
	# 官方同步项：每帧重加画布命令使剔除矩形与纹理/材质属性同步被消费。
	node.queue_redraw()


## SB-23D（D1）：重建后捕获表面布局与跨帧状态，写入节点 meta。快路径仅在
## 顶点流为纯 VERTEX（8 字节步长、偏移 0）且属性流含 COLOR+TEX_UV 数据
## 时成立；布局不符则保持逐帧重建（正确性与 SB-23C 步骤 3 相同）。
func _capture_v2_mesh_state(node: MeshInstance2D, mesh: ArrayMesh,
		positions: PackedVector2Array, uvs: PackedVector2Array,
		colors: PackedColorArray, indices: PackedInt32Array,
		has_dark: bool) -> Dictionary:
	var rid := mesh.get_rid()
	var surface := RenderingServer.mesh_get_surface(rid, 0)
	var fmt := int(surface["format"])
	var vstride := int(RenderingServer.mesh_surface_get_format_vertex_stride(
			fmt, positions.size()))
	var astride := int(RenderingServer.mesh_surface_get_format_attribute_stride(
			fmt, positions.size()))
	var voff := int(RenderingServer.mesh_surface_get_format_offset(
			fmt, positions.size(), Mesh.ARRAY_VERTEX))
	var coff := int(RenderingServer.mesh_surface_get_format_offset(
			fmt, positions.size(), Mesh.ARRAY_COLOR))
	var uoff := int(RenderingServer.mesh_surface_get_format_offset(
			fmt, positions.size(), Mesh.ARRAY_TEX_UV))
	var fast: bool = surface.has("attribute_data") and vstride == 8 and voff == 0 \
			and coff >= 0 and uoff >= coff + 4 and uoff + 8 <= astride
	var state := {
		"rid": rid,
		"nv": positions.size(),
		"ni": indices.size(),
		"idx": indices,
		"has_dark": has_dark,
		"uvs": uvs,
		"colors": colors,
		"ab": surface["attribute_data"],
		"astride": astride,
		"coff": coff,
		"uoff": uoff,
		"fast": fast,
	}
	node.set_meta("_spine_v2_mesh_state", state)
	return state


## SB-23D（D1）：从当前顶点求最小包围盒，同步 mesh custom AABB（对齐官方
## update_mesh 的逐帧 mesh_set_custom_aabb；用于画布剔除矩形，不影响渲染）。
func _positions_aabb(positions: PackedVector2Array) -> AABB:
	if positions.is_empty():
		return AABB()
	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF
	for v in positions:
		var x := v.x
		var y := v.y
		if x < min_x:
			min_x = x
		if x > max_x:
			max_x = x
		if y < min_y:
			min_y = y
		if y > max_y:
			max_y = y
	return AABB(Vector3(min_x, min_y, 0.0),
			Vector3(max_x - min_x, max_y - min_y, 0.0))


## SB-25B：v2 逐 draw 材质选择（§12.8 冻结顺序 + SB11-R1 插入级，五级）：
## 1. 插槽节点材质（SpineSlotNode，按该 draw 的 blend 选择，撤销=null 回落）；
## 2. sprite 级覆盖（本节点 normal/additive/multiply_material）；
## 3. 用户整节点自定义材质（SB11-R1，§11.4 "slot override > 角色显式 material
##    > 内建默认"：material 非空且非 _apply_page_material 自动分配的 premult
##    时参与 v2 绘制，混合模式由用户材质自身决定；清空即回落内置）；
## 4. has_dark → 内置双色 premult 材质；
## 5. 内置单色 premult 变体（v2 默认）。
## screen（编号 3，保留未支持）回退 normal 绘制，不静默丢 draw。
## 覆盖材质经 §12.6 straight COLOR 契约消费（has_dark draw 的 COLOR 为纯调制）。
## SB11-R2：内置单色/双色材质按页携带法线纹理（无法线页 null，shader 内
## u_has_normal=false 行为不变）。
## SB-23D（D2）：_select_v2_material_for 为参数化实现（原生路径与
## Dictionary 回退路径共用，保证两路径选择顺序/结果一致）。
func _select_v2_material(command: Dictionary) -> Material:
	var colors: PackedColorArray = command["colors"]
	var light := colors[0] if colors.size() > 0 else Color.WHITE
	var dark: Color = command.get("dark_color", Color.BLACK)
	return _select_v2_material_for(int(command.get("blend_mode", 0)),
			bool(command.get("page_pma", false)),
			bool(command.get("has_dark", false)), light, dark,
			_data.get_page_normal_texture(int(command["page_index"])),
			str(command.get("slot_name", "")))


## 参数化材质选择（SB-23D D2）：light/dark 为 straight 常量（原生路径取
## DrawExt，Dictionary 路径取 colors[0]/dark_color；两者按 §12.2 契约一致）。
func _select_v2_material_for(blend: int, pma: bool, has_dark: bool,
		light: Color, dark: Color, normal_tex: Texture2D,
		slot_name: String) -> Material:
	if blend < 0 or blend > 2:
		blend = 0 # SCREEN（3）保留未支持，回退 normal。
	if not slot_name.is_empty():
		var node := _find_slot_node(slot_name)
		if node != null:
			var node_material: Material = node.get_material_for_blend(blend)
			if node_material != null:
				return node_material
	var sprite_material := _sprite_material_for_blend(blend)
	if sprite_material != null:
		return sprite_material
	if material != null and material != _auto_page_material:
		return material
	if normal_tex != null and _data != null and _v2_normal_material_cache == null:
		_v2_normal_material_cache = _render_shaders.get_normal_cache(_data)
	if not has_dark:
		return _render_shaders.make_mono_material(blend, pma, normal_tex, _v2_normal_material_cache)
	# SB-25B HDR-2D（§12.8，对齐官方 tint_to_render_colors）：HDR-2D 视口且
	# RD 渲染器时，light/dark 经 srgb_to_linear——Godot 只自动转换 ARRAY_COLOR，
	# uniform 携带的颜色不会（单色变体的 light 在顶点色内，无需处理）。
	if _v2_hdr_2d:
		light = light.srgb_to_linear()
		dark = dark.srgb_to_linear()
	return _render_shaders.make_dual_material(blend, pma, light, dark, normal_tex, _v2_normal_material_cache)


## SB-25B：按 blend 选择 sprite 级覆盖材质；未设置返回 null。
func _sprite_material_for_blend(blend: int) -> Material:
	match blend:
		1:
			return additive_material
		2:
			return multiply_material
		_:
			return normal_material


## SB-25B：按名称查找已登记的插槽节点；未登记/已释放返回 null。
func _find_slot_node(slot_name: String) -> Node2D:
	_prune_slot_nodes()
	for node in _slot_nodes:
		if node.slot_name == slot_name:
			return node
	return null


## SB-25B：刷新 HDR-2D 判定（每次重绘求值一次；对齐官方
## SpineSprite::tint_to_render_colors 的两个条件）。
## SB-23D（D3）：判定翻转时递增材质选择输入代数（双色材质的
## light/dark uniform 转换依赖该判定）。
func _refresh_v2_hdr_2d() -> void:
	var vp := get_viewport()
	var hdr_2d := vp != null and vp.is_using_hdr_2d() \
			and RenderingServer.get_rendering_device() != null
	if hdr_2d != _v2_hdr_2d:
		_v2_hdr_2d = hdr_2d
		_v2_material_state_gen += 1


## 释放 v2 批量 mesh 池（幂等）。
func _clear_draw_meshes() -> void:
	for mesh in _draw_meshes:
		mesh.free()
	_draw_meshes.clear()


func _make_mesh(command: Dictionary) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = command["positions"]
	arrays[Mesh.ARRAY_TEX_UV] = command["uvs"]
	arrays[Mesh.ARRAY_COLOR] = command["colors"]
	arrays[Mesh.ARRAY_INDEX] = command["indices"]
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## 登记插槽子节点；无效节点拒绝登记（节点离树时经 _exit_tree 解登记，
## 角色自身也保持清单无悬空引用，见 _prune_slot_nodes）。
func _register_slot_node(node: Node2D) -> void:
	if not is_instance_valid(node) or _slot_nodes.has(node):
		return
	_slot_nodes.append(node)
	queue_redraw()


## 普通 CanvasItem 排在完整骨架序列之后。
func _apply_ordinary_slot_render_children(draw_index: int) -> int:
	for child in get_children():
		if not child is CanvasItem:
			continue
		if child is Node2D and _slot_nodes.has(child):
			continue
		if child is MeshInstance2D and _slot_meshes.has(child):
			continue
		RenderingServer.canvas_item_set_draw_index(child.get_canvas_item(), draw_index)
		draw_index += 1
	return draw_index


## 清理持有已释放对象的登记项（按索引倒序移除；typed Array 的 erase()
## 对已释放对象无效）。
func _prune_slot_nodes() -> void:
	var i := _slot_nodes.size() - 1
	while i >= 0:
		if not is_instance_valid(_slot_nodes[i]):
			_slot_nodes.remove_at(i)
		i -= 1


func _unregister_slot_node(node: Node2D) -> void:
	# typed Array 对已释放节点的 erase() 无效；先按有效性清理残留，再按索引移除。
	_prune_slot_nodes()
	if is_instance_valid(node):
		var idx := _slot_nodes.find(node)
		if idx >= 0:
			_slot_nodes.remove_at(idx)
	queue_redraw()


## Return the current render row for a mounted slot without waiting for _draw().
## The row supplies activity/bone identity; the node reads the just-updated global
## bone transform, so callers can use the mount immediately after world update.
func _get_slot_render_row(slot_name: String) -> Dictionary:
	if _data == null or _instance_handle == 0:
		return {}
	for row in _data.get_slot_render_commands(_instance_handle):
		if row.get("slot_name", "") == slot_name:
			return row
	return {}


func _clear_slot_meshes() -> void:
	for mesh in _slot_meshes:
		if is_instance_valid(mesh):
			mesh.free()
	_slot_meshes.clear()
	_slot_meshes_v2 = false


func _draw_slots() -> void:
	_clear_draw_meshes() # v2 批量池与逐槽池互斥
	_slot_frame += 1
	var frame := _slot_frame
	var rows: Array = _data.get_slot_render_commands(_instance_handle)
	for node in _slot_nodes:
		if is_instance_valid(node):
			node._sync_slot({})
	# SB-10 v2：行带 "commands"（该行全部 draw）时走 v2 逐槽路径。SB10-R1：
	# v2 帧每行必含该键（空槽/裁剪槽为空数组），版本识别不依赖首行是否可绘制；
	# 判定必须先于 v1 池（v1 池以 use_parent_material=true 预建节点，会忽略
	# 逐 draw 材质）；v1 行保持原逐行逻辑（每行首个 draw、继承整节点材质）不变。
	if rows.size() > 0 and rows[0].has("commands"):
		_slot_meshes_v2 = true
		_draw_slots_v2(rows)
		_apply_slot_order_v2.call_deferred(rows, frame)
		return
	_slot_meshes_v2 = false
	while _slot_meshes.size() < rows.size():
		var mesh := MeshInstance2D.new()
		mesh.use_parent_material = true
		mesh.show_behind_parent = _debug_meshes_behind_parent
		add_child(mesh, false, Node.INTERNAL_MODE_FRONT)
		_slot_meshes.append(mesh)
	while _slot_meshes.size() > rows.size():
		_slot_meshes.pop_back().free()
	for i in range(rows.size()):
		var row: Dictionary = rows[i]
		var mesh := _slot_meshes[i]
		# SB10-R1：池内可能残留另一路径预建的节点，每帧显式归位 v1 模式
		# （继承整节点材质、不镜像自身调制）。
		mesh.use_parent_material = true
		mesh.modulate = Color.WHITE
		mesh.visible = row.has("command")
		if row.has("command"):
			var command: Dictionary = row["command"]
			var texture: Texture2D = _data.get_page_texture(command["page_index"])
			var indices: PackedInt32Array = command["indices"]
			if texture == null or indices.is_empty():
				# 缺贴图时隐藏内部 mesh 但仍保留插槽行（插入点不变），
				# 与批量路径跳过缺贴图指令的行为一致。
				mesh.visible = false
				continue
			mesh.texture = texture
			mesh.mesh = _make_mesh(command)
	# Newly added CanvasItems defer their tree-order update. Apply the interleaved
	# order afterwards. The frame number identifies which draw produced the rows:
	# if a redraw or resource reload happens before the deferred call, reject it.
	_apply_slot_order.call_deferred(rows, frame)


## SB-10 v2 逐槽路径：mesh 池按 draw 展开（一行可含多个 draw，§12.8 修复
## “仅取首个”），逐 draw 材质/网格/纹理；空行不占 mesh。
func _draw_slots_v2(rows: Array) -> void:
	var total := 0
	for row in rows:
		total += (row.get("commands", []) as Array).size()
	_sync_v2_mesh_pool(_slot_meshes, total, true)
	var mesh_index := 0
	for row in rows:
		for command in row.get("commands", []):
			_submit_v2_command(_slot_meshes[mesh_index], command)
			mesh_index += 1


## v2 逐槽排序：每行的全部 draw 依次取绘制序号，行后接该行插槽挂件；
## 普通子节点保持在骨架之上。过期 rows 由帧号拒绝（同 _apply_slot_order）。
func _apply_slot_order_v2(rows: Array, frame: int) -> void:
	var total := 0
	for row in rows:
		total += (row.get("commands", []) as Array).size()
	if not is_inside_tree() or frame != _slot_frame or total != _slot_meshes.size():
		return
	_prune_slot_nodes()
	var draw_index := 0
	var mesh_index := 0
	for i in range(rows.size()):
		var row: Dictionary = rows[i]
		for command in row.get("commands", []):
			if mesh_index < _slot_meshes.size():
				RenderingServer.canvas_item_set_draw_index(
						_slot_meshes[mesh_index].get_canvas_item(), draw_index)
				mesh_index += 1
				draw_index += 1
		for node in _slot_nodes:
			if node.slot_name == row["slot_name"]:
				node._sync_slot(row)
				RenderingServer.canvas_item_set_draw_index(node.get_canvas_item(), draw_index)
				draw_index += 1
	# Ordinary children keep their relative order above the complete skeleton.
	draw_index = _apply_ordinary_slot_render_children(draw_index)


func _apply_slot_order(rows: Array, frame: int) -> void:
	if not is_inside_tree() or frame != _slot_frame or rows.size() != _slot_meshes.size():
		return
	_prune_slot_nodes()
	var draw_index := 0
	for i in range(rows.size()):
		var row: Dictionary = rows[i]
		var mesh := _slot_meshes[i]
		RenderingServer.canvas_item_set_draw_index(mesh.get_canvas_item(), draw_index)
		draw_index += 1
		for node in _slot_nodes:
			if node.slot_name == row["slot_name"]:
				node._sync_slot(row)
				RenderingServer.canvas_item_set_draw_index(node.get_canvas_item(), draw_index)
				draw_index += 1
	# Ordinary children keep their relative order above the complete skeleton.
	draw_index = _apply_ordinary_slot_render_children(draw_index)


## 从骨架数据资源建立实例；失败时写 last_error 并发出 load_failed。
func _load_from_resource(data: SpineSkeletonDataResource) -> bool:
	_release()
	last_error = ""
	_data = data
	_data.changed.connect(_on_data_changed)

	# 确保解析完成（不创建实例；失败时资源内部已记录错误）。
	if not data.ensure_loaded():
		last_error = data.get_last_error()
		if last_error.is_empty():
			last_error = "骨架数据资源不可用：检查资源内容与 Bridge 状态。"
		load_failed.emit(last_error)
		notify_property_list_changed()
		return false

	_instance_handle = data.create_instance()
	if _instance_handle == 0:
		last_error = data.get_last_error()
		if last_error.is_empty():
			last_error = "骨架数据资源不可用：检查资源内容与 Bridge 状态。"
		load_failed.emit(last_error)
		notify_property_list_changed()
		return false

	# SpineSprite 在创建实例前已开启动画事件回调；此处注册确保自动播放或
	# 直接从 AnimationState 设置条目时，都能在当前调用返回前投递。
	_sync_animation_event_callback()
	_apply_page_material(data)

	# 编辑器内静态预览（setup 姿态）；运行时按需自动播放。
	if not Engine.is_editor_hint() and auto_play:
		_apply_animation()
	if fit_to_viewport:
		_fit_to_viewport()
	# SB-13：重建后重新应用预览（编辑器）；运行时由 auto_play 走原路径。
	_preview_dirty = true
	if Engine.is_editor_hint():
		_apply_editor_preview()
	notify_property_list_changed() # 动画名下拉列表现在可用
	queue_redraw()
	return true


func _on_data_changed() -> void:
	# 由节点持有并释放旧实例，再用同一资源重建；不要先清零句柄，
	# 否则 _release() 无法履行节点自身的实例所有权。
	var changed_data := _data
	_load_from_resource(changed_data)


## 全部图集页为 PMA 时切换预乘 alpha 混合材质（半透明边缘不发暗）。
## 混合模式作用于整个画布项，要求所有页的 PMA 标记一致（Spine 导出
## 的常态）；混合页集的支持留给实际出现该资源时再处理。
## SB-11：材质优先级固定为"用户材质优先"——自动 premult 材质仅在当前
## material 为空或即上次自动分配时写入；用户设置的整节点自定义材质在
## load/reload 后保持不变（官方 SpineSprite 不改写自身 material，对齐）。
## 用户清空 material（置 null）后，下次加载恢复自动 premult。
func _apply_page_material(data: SpineSkeletonDataResource) -> void:
	var page_count := data.get_page_count()
	var all_pma := page_count > 0
	for i in range(page_count):
		all_pma = all_pma and data.is_page_pma(i)
	if all_pma:
		var premult := CanvasItemMaterial.new()
		premult.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
		if material == null or material == _auto_page_material:
			material = premult
		_auto_page_material = premult
	else:
		if material == null or material == _auto_page_material:
			material = null
		_auto_page_material = null


## 应用 animation_name（加载前后均可调用）。
func _apply_animation() -> void:
	if _applying_animation or _instance_handle == 0 or _data == null:
		return
	_applying_animation = true
	if animation_name.is_empty():
		var names := get_animation_names()
		if names.is_empty():
			_applying_animation = false
			return
		animation_name = names[0]
	if Engine.is_editor_hint():
		# 编辑器内静态预览：应用所选动画的第 0 帧姿态，不持续播放。
		if _data.set_animation(_instance_handle, 0, animation_name, true):
			_data.advance_instance(_instance_handle, 0.0)
			queue_redraw()
	else:
		# 赋值触发的 setter 已被 _applying_animation 挡住，这里实际起播。
		play(animation_name)
	_applying_animation = false


## 防止 play → setter → _apply_animation 的递归。
var _applying_animation := false


## 按视口尺寸与角色包围盒适配缩放和位置。
## 包围盒为 Y 向下世界坐标（spine-cpp yDown 默认 true），与画布一致。
func _fit_to_viewport() -> void:
	var bounds := get_bounds()
	var viewport_size := get_viewport_rect().size
	if bounds.is_empty() or float(bounds.get("width", 0)) <= 0 or float(bounds.get("height", 0)) <= 0:
		return
	var fit := 0.7 * minf(
			viewport_size.x / float(bounds["width"]),
			viewport_size.y / float(bounds["height"]))
	character_scale = fit
	position = viewport_size * 0.5 - Vector2(
			(float(bounds["x"]) + float(bounds["width"]) * 0.5) * fit,
			(float(bounds["y"]) + float(bounds["height"]) * 0.5) * fit)


## 释放实例（保留资源与解析结果；资源析构时统一释放）。
func _release_instance() -> void:
	is_playing = false
	if _data != null and _instance_handle != 0:
		# 先断开资源中的 Callable，避免销毁路径保留指向离树节点的接收器。
		_data.clear_immediate_event_callback(_instance_handle)
		_data.destroy_instance(_instance_handle)
	_instance_handle = 0


## 释放实例与临时资源引用（幂等）。
func _release() -> void:
	_release_instance()
	_clear_slot_meshes()
	_clear_draw_meshes()
	_prune_slot_nodes()
	for node in _slot_nodes:
		node._sync_slot({})
	if _data != null and _data.changed.is_connected(_on_data_changed):
		_data.changed.disconnect(_on_data_changed)
	_data = null
	_temp_data = null
	# SB-09 收口：骨架包装缓存随实例释放清空（旧包装经 is_valid() 失效）。
	_skeleton_object = null
	_debug_bone_names.clear()
	_debug_bone_lengths.clear()
	_debug_bone_indices.clear()
	_mesh_pool.clear()
	# SB-11：整节点材质与 v2 材质/法线页引用同样不被释放/重载覆盖——
	# 自动 premult 材质随 _load_from_resource 的 _apply_page_material 重算；
	# 用户自定义材质（material / normal_material 等覆盖属性）原样保留。
	if material == _auto_page_material:
		material = null
	_auto_page_material = null
	_v2_page_canvas_textures.clear()
	_v2_normal_material_cache = null
	_v2_white_arrays.clear()
	# SB-23D（D2）：原生消费者与不可用标记随实例释放复位（网格/纹理缓存
	# 归消费者，随引用释放）。
	_v2_consumer = null
	_v2_native_unavailable = false
	_v2_last_native_info = {}
	# SB-23D（D3）：逐 draw 材质选择缓存随实例释放复位。
	_v2_material_cache = []
	_v2_material_cache_gen = -1
	_v2_material_applied_size = 0
	notify_property_list_changed()
	queue_redraw()
