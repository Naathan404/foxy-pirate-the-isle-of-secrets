class_name RuntimeSpineBridge
extends RefCounted
## Spine Bridge 的 GDScript 产品层薄包装。
## Client / Creator / Runtime 只通过本脚本访问 Spine 能力；
## 原生扩展未构建时也能安全查询状态与版本清单。


## Spine provider 版本清单（providers.json）在项目内的路径。
const MANIFEST_PATH := "res://addons/spine_bridge/providers.json"

## 原生扩展注册到 ClassDB 的类名。
const NATIVE_CLASS_NAME := "SpineBridge"

## Bridge 状态。
## 数值与原生扩展 SpineBridge.Status 枚举保持一致；
## MISSING_EXTENSION 是扩展缺失时由包装层使用的附加状态。
enum Status {
	MISSING_EXTENSION = -1,
	UNINITIALIZED = 0,
	READY = 1,
	PROVIDER_NOT_LINKED = 2,
	ERROR = 3,
}


## 原生 SpineBridge 实例；扩展未加载或未初始化时为 null。
var _bridge = null

## 包装层维护的最新状态。
var _status: Status = Status.UNINITIALIZED

## 包装层维护的最新错误信息。
var _last_error: String = ""

## provider 清单是否已尝试加载。
var _manifest_loaded := false

## providers.json 中校验通过的 provider 记录。
var _manifest_entries: Array[Dictionary] = []

## providers.json 中登记的默认 provider 标识。
var _default_provider_id: String = ""


## 原生 SpineBridge 扩展当前是否已加载并注册。
static func is_extension_available() -> bool:
	return ClassDB.class_exists(NATIVE_CLASS_NAME)


## 初始化 Bridge。
## 返回 true 表示初始化完成、状态可查询（READY 或 PROVIDER_NOT_LINKED）；
## 返回 false 表示原生扩展缺失或初始化失败。
func initialize() -> bool:
	if _bridge != null:
		return _status == Status.READY or _status == Status.PROVIDER_NOT_LINKED

	if not is_extension_available():
		_status = Status.MISSING_EXTENSION
		_last_error = "原生扩展 SpineBridge 未加载：请按 Runtime/native/spine_bridge/README.md 构建后重试。"
		return false

	_bridge = ClassDB.instantiate(NATIVE_CLASS_NAME)
	if _bridge == null:
		_status = Status.ERROR
		_last_error = "原生扩展 SpineBridge 实例化失败。"
		return false

	if not _bridge.initialize():
		_status = Status.ERROR
		_last_error = _bridge.get_last_error()
		return false

	_status = _bridge.get_status()
	return _status == Status.READY or _status == Status.PROVIDER_NOT_LINKED


## 当前 provider 标识，例如 "spine-4.3"；不可用时为空字符串。
func get_provider_id() -> String:
	if _bridge == null:
		return ""
	return _bridge.get_provider_id()


## 当前 provider 面向的 Spine 运行库版本，例如 "4.3"；不可用时为空字符串。
func get_runtime_version() -> String:
	if _bridge == null:
		return ""
	return _bridge.get_runtime_version()


## 当前 Bridge 状态。
func get_status() -> Status:
	return _status


## Bridge 是否已就绪（provider 链接了真实 spine-cpp）。
func is_ready() -> bool:
	return _status == Status.READY


## 状态的人类可读名称，用于日志与界面显示。
func get_status_name() -> String:
	match _status:
		Status.MISSING_EXTENSION:
			return "扩展未加载（MISSING_EXTENSION）"

		Status.UNINITIALIZED:
			return "未初始化（UNINITIALIZED）"

		Status.READY:
			return "就绪（READY）"

		Status.PROVIDER_NOT_LINKED:
			return "Provider 未链接（PROVIDER_NOT_LINKED）"

		Status.ERROR:
			return "错误（ERROR）"

		_:
			return "未知状态（UNKNOWN）"


## 最近一次错误或不可用原因；无错误时为空字符串。
func get_last_error() -> String:
	if _bridge != null:
		var native_error: String = _bridge.get_last_error()
		if not native_error.is_empty():
			return native_error
	return _last_error


## providers.json 中登记的全部 provider 标识。
## 清单读取不依赖原生扩展，扩展缺失时仍可使用。
func get_available_providers() -> PackedStringArray:
	var ids := PackedStringArray()
	for entry in _get_manifest_entries():
		ids.append(str(entry.get("id", "")))
	return ids


## providers.json 中登记的默认 provider 标识。
## 原生扩展可用时直接使用原生注册表校验后的默认 ID（与 initialize() 实际
## 选取的默认项一致，含无效 default_provider 回退与清单解析）；扩展缺失时
## 回退本地清单解析（清单缺失时为空字符串）。
func get_default_provider_id() -> String:
	if _bridge != null:
		return _bridge.get_default_provider_id()
	if not _manifest_loaded:
		_load_manifest()
	return _default_provider_id


## 最小加载路径：读取 atlas 与骨架文件并加载为骨架句柄。
## atlas_path 是 .atlas 文本文件；skeleton_path 是骨架文件，
## 扩展名为 json 时按 JSON 文本解析，其余（如 skel）按二进制解析。
## SB-05：加载前按骨架字节有界探测导出版本并路由到对应 provider
##（探测失败回退默认 provider，由 provider 给出精确错误）。
## 路径支持 res:// 与绝对路径；导出构建中这些文件需随包分发。
## 加载失败返回 0，原因见 get_last_error()；成功后句柄用于
## 查询动画与皮肤，并由 unload_skeleton() 释放。
func load_skeleton(atlas_path: String, skeleton_path: String) -> int:
	if _bridge == null:
		_last_error = "原生扩展 SpineBridge 未加载，无法加载骨架。"
		return 0

	var atlas_bytes := FileAccess.get_file_as_bytes(atlas_path)
	if FileAccess.get_open_error() != OK:
		_last_error = "无法读取 atlas 文件：%s（错误码 %d）。" % [atlas_path, FileAccess.get_open_error()]
		return 0

	var skeleton_bytes := FileAccess.get_file_as_bytes(skeleton_path)
	if FileAccess.get_open_error() != OK:
		_last_error = "无法读取骨架文件：%s（错误码 %d）。" % [skeleton_path, FileAccess.get_open_error()]
		return 0

	var is_binary := skeleton_path.get_extension().to_lower() not in ["json", "spine-json"]
	if not _route_provider_for_bytes(skeleton_bytes, is_binary):
		return 0
	return _bridge.load_skeleton(atlas_bytes, skeleton_bytes, is_binary)


## SB-05：按字节探测版本并路由 provider。
## 探测成功且 manifest 有匹配 provider → 绑定该 provider（返回 true）。
## 探测成功但无 provider 支持该版本 → 写错误并返回 false。
## 探测失败（垃圾/截断数据）→ 显式绑定默认 provider（返回 true），
## 由其加载阶段给出精确错误；不沿用 Bridge 当前绑定的 provider，
## 避免多版本场景下由无关 provider 报版本语境错误的错误。
func _route_provider_for_bytes(skeleton_bytes: PackedByteArray, is_binary: bool) -> bool:
	var detected: Dictionary = _bridge.detect_skeleton_version(skeleton_bytes, is_binary)
	if not detected.get("ok", false):
		var default_id := get_default_provider_id()
		if not default_id.is_empty():
			return initialize_for_provider(default_id)
		if _bridge.get_status() == Status.UNINITIALIZED:
			_bridge.initialize()
		return true
	var provider_id: String = _bridge.resolve_provider_for_version(
			int(detected.get("major", 0)), int(detected.get("minor", 0)))
	if provider_id.is_empty():
		_last_error = _bridge.get_last_error()
		return false
	if not _bridge.initialize_for_provider(provider_id):
		_last_error = _bridge.get_last_error()
		return false
	return true


## SB-05：有界探测骨架字节的导出版本；字段见原生
## SpineBridge.detect_skeleton_version（ok/version/major/minor/patch/error）。
func detect_skeleton_version(skeleton_bytes: PackedByteArray, is_binary: bool) -> Dictionary:
	if _bridge == null:
		return {"ok": false, "version": "", "major": 0, "minor": 0, "patch": 0,
				"error": "原生扩展 SpineBridge 未加载。"}
	return _bridge.detect_skeleton_version(skeleton_bytes, is_binary)


## SB-05：按 manifest 声明解析版本对应的 provider 标识；无匹配返回空串。
func resolve_provider_for_version(major: int, minor: int) -> String:
	if _bridge == null:
		return ""
	return _bridge.resolve_provider_for_version(major, minor)


## SB-05：初始化并绑定指定 provider（版本路由用）。
func initialize_for_provider(provider_id: String) -> bool:
	if _bridge == null and not initialize():
		return false
	if not _bridge.initialize_for_provider(provider_id):
		_status = Status.ERROR
		_last_error = _bridge.get_last_error()
		return false
	_status = _bridge.get_status()
	return _status == Status.READY or _status == Status.PROVIDER_NOT_LINKED


## SB-05：manifest + 实际装载状态的诊断列表（id/spine_version/
## supported_versions/source_commit/abi/capabilities/entry_symbol/loaded/load_error）。
func get_provider_diagnostics() -> Array:
	if _bridge == null:
		return []
	return _bridge.get_provider_diagnostics()


## 释放 load_skeleton() 返回的句柄；句柄无效或扩展未加载时返回 false。
func unload_skeleton(handle: int) -> bool:
	if _bridge == null:
		return false
	return _bridge.unload_skeleton(handle)


## 句柄对应的动画名称；句柄无效或扩展未加载时返回空数组。
func get_animation_names(handle: int) -> PackedStringArray:
	if _bridge == null:
		return PackedStringArray()
	return _bridge.get_animation_names(handle)


## 句柄对应的皮肤名称；句柄无效或扩展未加载时返回空数组。
func get_skin_names(handle: int) -> PackedStringArray:
	if _bridge == null:
		return PackedStringArray()
	return _bridge.get_skin_names(handle)


## 句柄对应的图集页文件名列表；顺序即渲染数据里 page_index 的取值。
## 句柄无效或扩展未加载时返回空数组。
func get_page_names(handle: int) -> PackedStringArray:
	if _bridge == null:
		return PackedStringArray()
	return _bridge.get_page_names(handle)


## 由骨架数据建立运行实例（骨架姿态 + 动画状态）。
## 失败返回 0，原因见 get_last_error()。
func create_instance(skeleton_handle: int) -> int:
	if _bridge == null:
		_last_error = "原生扩展 SpineBridge 未加载，无法创建实例。"
		return 0
	return _bridge.create_instance(skeleton_handle)


## 释放实例；句柄无效或扩展未加载时返回 false。
func destroy_instance(instance_handle: int) -> bool:
	if _bridge == null:
		return false
	return _bridge.destroy_instance(instance_handle)


## 在指定轨道上播放动画（从当前姿态混合过去）。
## 动画名不存在或句柄无效时返回 false。
func set_animation(instance_handle: int, track_index: int, animation_name: String, loop: bool) -> bool:
	if _bridge == null:
		return false
	return _bridge.set_animation(instance_handle, track_index, animation_name, loop)


## 切换皮肤；皮肤名不存在或句柄无效时返回 false。
func set_skin(instance_handle: int, skin_name: String) -> bool:
	if _bridge == null:
		return false
	return _bridge.set_skin(instance_handle, skin_name)


## 推进动画并更新骨架世界变换；句柄无效或扩展未加载时返回 false。
func advance_instance(instance_handle: int, delta: float) -> bool:
	if _bridge == null:
		return false
	return _bridge.advance_instance(instance_handle, delta)


## 输出当前帧的渲染指令列表。
## 每条指令是一个 Dictionary：page_index（图集页索引）、
## positions / uvs / colors（顶点数据）与 indices（三角形索引）。
## 句柄无效或扩展未加载时返回空数组。
func get_render_commands(instance_handle: int) -> Array:
	if _bridge == null:
		return []
	return _bridge.get_render_commands(instance_handle)


## 实例的当前包围盒（世界坐标）：x / y / width / height。
## 句柄无效时返回空字典。
func get_instance_bounds(instance_handle: int) -> Dictionary:
	if _bridge == null:
		return {}
	return _bridge.get_instance_bounds(instance_handle)


## Animation operations use instance handles. Drain events regularly when
## controlling instances directly; SpineSprite drains them automatically.

func add_animation(instance_handle: int, track_index: int, animation_name: String, loop: bool, delay: float) -> bool:
	if _bridge == null:
		return false
	return _bridge.add_animation(instance_handle, track_index, animation_name, loop, delay)

func clear_track(instance_handle: int, track_index: int) -> bool:
	if _bridge == null:
		return false
	return _bridge.clear_track(instance_handle, track_index)

func clear_tracks(instance_handle: int) -> bool:
	if _bridge == null:
		return false
	return _bridge.clear_tracks(instance_handle)

func set_empty_animation(instance_handle: int, track_index: int, mix_duration: float) -> bool:
	if _bridge == null:
		return false
	return _bridge.set_empty_animation(instance_handle, track_index, mix_duration)

func add_empty_animation(instance_handle: int, track_index: int, mix_duration: float, delay: float) -> bool:
	if _bridge == null:
		return false
	return _bridge.add_empty_animation(instance_handle, track_index, mix_duration, delay)

func set_default_mix(instance_handle: int, duration: float) -> bool:
	if _bridge == null:
		return false
	return _bridge.set_default_mix(instance_handle, duration)

func set_mix(instance_handle: int, from: String, to: String, duration: float) -> bool:
	if _bridge == null:
		return false
	return _bridge.set_mix(instance_handle, from, to, duration)

func get_current(instance_handle: int, track_index: int) -> Dictionary:
	if _bridge == null:
		return {}
	return _bridge.get_current(instance_handle, track_index)

func drain_events(instance_handle: int) -> Array:
	if _bridge == null:
		return []
	return _bridge.drain_events(instance_handle)


## --- M2 骨骼／插槽／附件／皮肤／TrackEntry（转发到原生 Bridge） ---

## 骨架数据包含的骨骼名列表；句柄无效或扩展未加载时为空。
func get_bone_names(handle: int) -> PackedStringArray:
	if _bridge == null:
		return PackedStringArray()
	return _bridge.get_bone_names(handle)


## 骨架数据包含的插槽名列表。
func get_slot_names(handle: int) -> PackedStringArray:
	if _bridge == null:
		return PackedStringArray()
	return _bridge.get_slot_names(handle)


## 骨骼 setup 数据快照（parent/length/x/y/rotation/scale_x/scale_y/shear_x/shear_y）；
## 骨骼不存在返回空字典。
func get_bone_data(handle: int, name: String) -> Dictionary:
	if _bridge == null:
		return {}
	return _bridge.get_bone_data(handle, name)


## 插槽 setup 数据快照（bone/attachment/color/blend_mode）；插槽不存在返回空字典。
func get_slot_data(handle: int, name: String) -> Dictionary:
	if _bridge == null:
		return {}
	return _bridge.get_slot_data(handle, name)


## 指定插槽在全部皮肤中出现过的附件名列表（换装可选项）。
func get_attachment_names(handle: int, slot_name: String) -> PackedStringArray:
	if _bridge == null:
		return PackedStringArray()
	return _bridge.get_attachment_names(handle, slot_name)


## 实例上骨骼的当前局部姿态快照（x/y/rotation/scale_x/scale_y/shear_x/shear_y）。
func get_bone_pose(instance_handle: int, name: String) -> Dictionary:
	if _bridge == null:
		return {}
	return _bridge.get_bone_pose(instance_handle, name)


## 修改实例上骨骼的局部姿态；pose 中出现的键才写入。失败返回 false。
func set_bone_pose(instance_handle: int, name: String, pose: Dictionary) -> bool:
	if _bridge == null:
		return false
	return _bridge.set_bone_pose(instance_handle, name, pose)


## 实例上骨骼的当前世界变换快照（a/b/c/d/x/y 与 rotation_deg/scale_x/scale_y）。
func get_bone_world_transform(instance_handle: int, name: String) -> Dictionary:
	if _bridge == null:
		return {}
	return _bridge.get_bone_world_transform(instance_handle, name)


## 直接写入实例上骨骼的世界变换（world 须含全部键 a/b/c/d/x/y）。
func set_bone_world_transform(instance_handle: int, name: String, world: Dictionary) -> bool:
	if _bridge == null:
		return false
	return _bridge.set_bone_world_transform(instance_handle, name, world)


## 实例上插槽当前显示的附件名；无附件为空字符串。
func get_slot_attachment(instance_handle: int, slot_name: String) -> String:
	if _bridge == null:
		return ""
	return _bridge.get_slot_attachment(instance_handle, slot_name)


## 替换插槽附件（在当前皮肤与默认皮肤中查找；空名清空插槽）。
func set_attachment(instance_handle: int, slot_name: String, attachment_name: String) -> bool:
	if _bridge == null:
		return false
	return _bridge.set_attachment(instance_handle, slot_name, attachment_name)


## 皮肤组合：按顺序叠加多个皮肤并应用（后者覆盖前者）。
func set_combined_skin(instance_handle: int, skin_names: PackedStringArray) -> bool:
	if _bridge == null:
		return false
	return _bridge.set_combined_skin(instance_handle, skin_names)


## 实例整体颜色；句柄无效时返回白色。
func get_skeleton_color(instance_handle: int) -> Color:
	if _bridge == null:
		return Color.WHITE
	return _bridge.get_skeleton_color(instance_handle)


## 设置实例整体颜色（各分量 0–1）。
func set_skeleton_color(instance_handle: int, color: Color) -> bool:
	if _bridge == null:
		return false
	return _bridge.set_skeleton_color(instance_handle, color)


## 实例骨架空间状态（x/y/scale_x/scale_y/time）。
func get_skeleton_state(instance_handle: int) -> Dictionary:
	if _bridge == null:
		return {}
	return _bridge.get_skeleton_state(instance_handle)


## 修改实例骨架空间状态；state 中出现且有限的键才写入（scale 不允许 0）。
func set_skeleton_state(instance_handle: int, state: Dictionary) -> bool:
	if _bridge == null:
		return false
	return _bridge.set_skeleton_state(instance_handle, state)


func set_track_loop(instance_handle: int, track: int, loop: bool) -> bool:
	if _bridge == null:
		return false
	return _bridge.set_track_loop(instance_handle, track, loop)


func set_track_time_scale(instance_handle: int, track: int, value: float) -> bool:
	if _bridge == null:
		return false
	return _bridge.set_track_time_scale(instance_handle, track, value)


func set_track_alpha(instance_handle: int, track: int, value: float) -> bool:
	if _bridge == null:
		return false
	return _bridge.set_track_alpha(instance_handle, track, value)


func set_track_delay(instance_handle: int, track: int, value: float) -> bool:
	if _bridge == null:
		return false
	return _bridge.set_track_delay(instance_handle, track, value)


func set_track_time(instance_handle: int, track: int, value: float) -> bool:
	if _bridge == null:
		return false
	return _bridge.set_track_time(instance_handle, track, value)


func set_track_mix_duration(instance_handle: int, track: int, value: float) -> bool:
	if _bridge == null:
		return false
	return _bridge.set_track_mix_duration(instance_handle, track, value)



func update_animation_state(instance_handle: int, delta: float) -> bool:
	if _bridge == null:
		return false
	return _bridge.update_animation_state(instance_handle, delta)

func apply_animation_state(instance_handle: int) -> bool:
	if _bridge == null:
		return false
	return _bridge.apply_animation_state(instance_handle)

func update_world_transform(instance_handle: int, delta: float) -> bool:
	if _bridge == null:
		return false
	return _bridge.update_world_transform(instance_handle, delta)


## Ordered slot rows: slot_name, bone_name, bone_active and optional command.
func get_slot_render_commands(instance_handle: int) -> Array:
	if _bridge == null:
		return []
	return _bridge.get_slot_render_commands(instance_handle)


func _get_manifest_entries() -> Array[Dictionary]:
	if not _manifest_loaded:
		_load_manifest()
	return _manifest_entries


## 读取并解析 providers.json；文件缺失或格式错误时保持空清单并输出警告。
func _load_manifest() -> void:
	_manifest_loaded = true
	_manifest_entries = []
	_default_provider_id = ""

	var manifest: Dictionary = _read_manifest_file()
	if manifest.is_empty():
		return

	var providers = manifest.get("providers", [])
	if providers is Array:
		for entry in providers:
			if entry is Dictionary and not str(entry.get("id", "")).is_empty():
				_manifest_entries.append(entry)

	# 本地解析仅覆盖“原生扩展缺失”时的只读查询路径；原生扩展可用时
	# get_default_provider_id() 直接使用原生注册表校验后的默认 ID，避免两层
	# 各自推导默认项导致分歧。此处同样将缺省/未登记的 default_provider
	# 回退到首个合法条目，保持查询结果与原生语义一致。
	_default_provider_id = str(manifest.get("default_provider", ""))
	if not _manifest_entries.is_empty():
		var registered := {}
		for entry in _manifest_entries:
			registered[str(entry.get("id", ""))] = true
		if _default_provider_id.is_empty() or not registered.has(_default_provider_id):
			_default_provider_id = str(_manifest_entries[0].get("id", ""))


## 读取 providers.json 并解析为字典；失败时返回空字典。
func _read_manifest_file() -> Dictionary:
	# 优先走资源系统（对导出构建同样有效）。
	if ResourceLoader.exists(MANIFEST_PATH):
		var resource: Resource = load(MANIFEST_PATH)
		if resource is JSON:
			var data: Variant = (resource as JSON).data
			if data is Dictionary:
				return data

	# 回退为直接读文件（编辑器环境或尚未导入时）。
	if FileAccess.file_exists(MANIFEST_PATH):
		var text := FileAccess.get_file_as_string(MANIFEST_PATH)
		var parsed: Variant = JSON.parse_string(text)
		if parsed is Dictionary:
			return parsed

	push_warning("无法读取 Spine provider 清单（Spine Provider Manifest）：" + MANIFEST_PATH)
	return {}
