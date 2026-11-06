@tool
class_name SpineAnimationTrack
extends Node

## SB-20：官方 spine-godot SpineAnimationTrack 的 GDScript 对等实现。
##
## 目标基线 f182572b `spine-godot/spine_godot/SpineAnimationTrack.{h,cpp}`，
## 技术路线见 `Docs/SpineBridge-模块集成方案.md` §3（纯 GDExtension + 脚本层，
## 不引入引擎模块）。本节点必须直接挂在 `SpineSprite`（2D）或 `SpineSprite3D`
## 下：为骨架的每个动画生成两条 value 轨剪辑（`<动画名>` = 不循环、
## `<动画名>_looped` = 循环）以及 `RESET` / `-- Empty --`，由内部子
## `AnimationPlayer` 播放或编辑器 scrub，属性写入真实 `SpineAnimationState`，
## 而不是只改字符串。
##
## 时间所有权按官方语义（模块集成方案 §3.3）：运行时 AnimationPlayer 决定
## 播放哪条剪辑与何时切轨，spine 时钟仍由外观节点推进；编辑器 scrub 用
## `timeScale = 0` + 手动 track time 采样，采样条目保持暂停。
##
## 官方标注该能力为 highly experimental，本实现保留同一实验性边界：3D 保真度
## 受 Godot 动画引擎对第三方插件开放程度限制。

const _STOP_SENTINEL := "[stop]"
const _EMPTY_ANIMATION_NAME := "<empty>"
## 官方用 FLT_MAX 让空动画条目不自动结束（SpineAnimationTrack.cpp:631）。
## provider 入口校验为 |v| > 3.402823466e38 拒绝，且绑定层 float 参数会把
## 3.402823466e38 重新舍入回 FLT_MAX，因此取 3.4e38（仍远大于任何实际轨道时长）。
const _TRACK_END_MAX := 3.4e38
## 官方对 0 时长动画取 0.5 s（SpineAnimationTrack.cpp:250-251）。
const _DEFAULT_CLIP_LENGTH := 0.5
const _EDITOR_DOCK_TYPES := {
	"AnimationPlayer": "AnimationPlayerEditor",
	"AnimationTree": "AnimationTreeEditor",
}

## 官方把 animation_name / loop 作为 STORAGE|INTERNAL|NOEDITOR 属性，由生成的
## 剪辑键控，不在检查器中直接编辑。GDScript 侧保持同一访问语义。
@export var animation_name: String = "":
	set(value):
		animation_name = value
		_animation_changed = true

@export var loop: bool = false:
	set(value):
		loop = value
		_animation_changed = true

## 官方 API-MODULE-003：-1 表示在 READY 时自动分配“同骨架其他轨道最大 index + 1”。
@export_range(-1, 256, 1) var track_index: int = -1
## 官方 API-MODULE-004：-1 表示使用 data 级 mix。
@export var mix_duration: float = -1.0
@export var additive: bool = false
@export var reverse: bool = false
@export var shortest_rotation: bool = false
@export var time_scale: float = 1.0
@export var alpha: float = 1.0
## 官方属性名为 attachment_threshold / draw_order_threshold，方法名为 mix_*。
@export var attachment_threshold: float = 0.0
@export var draw_order_threshold: float = 0.0
## 编辑器 AnimationTree 预览模式（官方 SpineAnimationTrack.cpp:408-465）。
@export var blend_tree_mode: bool = false
@export var debug: bool = false

var _sprite: Node = null
var _animation_player_dirty := true
var _animation_changed := false
## type_name -> Control 实例 ID；编辑器面板只用于反射定位，不做强引用。
var _editor_dock_cache: Dictionary = {}
## SB-20（SB20-R1）：最近一次成功 scrub 的输入指纹与结果时间。输入未变时
## 保持上次重放结果（暂停采样与编辑器帧间隔无关，也不重复推进物理时钟）。
var _editor_scrub_key: Dictionary = {}
var _editor_scrub_valid := false
## SB-20（SB20-R2）：上次采样对应的条目、条目句柄与冻结时间；条目被替换或
## 清除（含 Preview 重应用清空 track）后不再复用缓存。
var _editor_scrub_entry: SpineTrackEntry = null
var _editor_scrub_entry_handle := 0
var _editor_scrub_entry_time := 0.0


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_PARENTED:
			_set_sprite(get_parent())
		NOTIFICATION_READY:
			_sprite = _resolve_sprite(get_parent())
			_setup_animation_player()
		NOTIFICATION_UNPARENTED:
			_set_sprite(null)


## 官方内部属性不在检查器显示（STORAGE|INTERNAL|NOEDITOR）。
func _validate_property(property: Dictionary) -> void:
	if property.get("name", "") in ["animation_name", "loop"]:
		property["usage"] = PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_INTERNAL | PROPERTY_USAGE_NO_EDITOR


## 官方 API-MODULE-014：连接 before_animation_state_update，每帧把
## AnimationPlayer 的剪辑状态同步到 SpineAnimationState。
## 参数用于核对信号宿主，避免轨道被换父后仍向旧骨架写入。
func update_animation_state(spine_sprite: Variant = null) -> void:
	if _sprite == null:
		return
	if spine_sprite != null and spine_sprite != _sprite:
		return
	var data := _get_skeleton_data()
	if data == null or not data.is_skeleton_data_loaded():
		return
	if _animation_player_dirty:
		_setup_animation_player()
	if _sprite == null:
		return
	if track_index < 0:
		return
	var skeleton: SpineSkeleton = _sprite.get_skeleton()
	var state: SpineAnimationState = _sprite.get_animation_state()
	if skeleton == null or state == null:
		return
	if not animation_name.is_empty() and animation_name != _STOP_SENTINEL \
			and data.get_animation_object(animation_name) == null:
		return
	var player := _find_animation_player()
	if player == null:
		_setup_animation_player()
		player = _find_animation_player()
		if player == null:
			return
	if Engine.is_editor_hint():
		_update_in_editor(skeleton, state, player)
	else:
		_update_at_runtime(state, player)


## 官方 API-MODULE-014 的失效入口：资源重建或换父后必须重建剪辑。
func invalidate_animation_player() -> void:
	_animation_player_dirty = true
	_animation_changed = true
	_editor_scrub_valid = false
	_editor_scrub_entry = null


# ---- 官方 API-MODULE-001..013 的显式方法入口（GDScript 属性之外的兼容口径） ----

func set_animation_name(value: String) -> void:
	animation_name = value


func get_animation_name() -> String:
	return animation_name


func set_loop(value: bool) -> void:
	loop = value


func get_loop() -> bool:
	return loop


func set_track_index(value: int) -> void:
	track_index = value


func get_track_index() -> int:
	return track_index


func set_mix_duration(value: float) -> void:
	mix_duration = value


func get_mix_duration() -> float:
	return mix_duration


func set_additive(value: bool) -> void:
	additive = value


func get_additive() -> bool:
	return additive


func set_reverse(value: bool) -> void:
	reverse = value


func get_reverse() -> bool:
	return reverse


func set_shortest_rotation(value: bool) -> void:
	shortest_rotation = value


func get_shortest_rotation() -> bool:
	return shortest_rotation


func set_time_scale(value: float) -> void:
	time_scale = value


func get_time_scale() -> float:
	return time_scale


func set_alpha(value: float) -> void:
	alpha = value


func get_alpha() -> float:
	return alpha


func set_mix_attachment_threshold(value: float) -> void:
	attachment_threshold = value


func get_mix_attachment_threshold() -> float:
	return attachment_threshold


func set_mix_draw_order_threshold(value: float) -> void:
	draw_order_threshold = value


func get_mix_draw_order_threshold() -> float:
	return draw_order_threshold


func set_blend_tree_mode(value: bool) -> void:
	blend_tree_mode = value


func get_blend_tree_mode() -> bool:
	return blend_tree_mode


func set_debug(value: bool) -> void:
	debug = value


func get_debug() -> bool:
	return debug


# ---- 宿主连接与剪辑生成 ----

func _set_sprite(node: Node) -> void:
	if _sprite != null:
		if _sprite.is_connected("before_animation_state_update", update_animation_state):
			_sprite.disconnect("before_animation_state_update", update_animation_state)
		if _sprite.is_connected("_internal_spine_objects_invalidated", invalidate_animation_player):
			_sprite.disconnect("_internal_spine_objects_invalidated", invalidate_animation_player)
	_sprite = null
	var target := _resolve_sprite(node)
	if target != null:
		target.connect("before_animation_state_update", update_animation_state)
		target.connect("_internal_spine_objects_invalidated", invalidate_animation_player)
		_sprite = target
	invalidate_animation_player()


func _resolve_sprite(node: Node) -> Node:
	if node != null and (node is SpineSprite or node is SpineSprite3D):
		return node
	return null


func _get_skeleton_data() -> SpineSkeletonDataResource:
	if _sprite is SpineSprite:
		return (_sprite as SpineSprite).skeleton_data_res
	if _sprite is SpineSprite3D:
		return (_sprite as SpineSprite3D).skeleton_data_res
	return null


func _find_animation_player() -> AnimationPlayer:
	for child in get_children():
		if child is AnimationPlayer:
			return child
	return null


## 官方 setup_animation_player（cpp:201-246）：自动编号、查找/创建子播放器、
## 重建剪辑库。资源未加载时不创建剪辑，等资源可用后由 dirty 标记重建。
func _setup_animation_player() -> void:
	if _sprite == null:
		return
	var data := _get_skeleton_data()
	if data == null or not data.is_skeleton_data_loaded():
		return
	_animation_player_dirty = false
	var player := _find_animation_player()
	if track_index < 0:
		var highest := -1
		for sibling in _sprite.get_children():
			if sibling is SpineAnimationTrack and sibling != self:
				highest = maxi(highest, (sibling as SpineAnimationTrack).track_index)
		track_index = highest + 1
	if player == null:
		player = AnimationPlayer.new()
		player.name = "%s Track %d" % [_sprite.name, track_index]
		add_child(player)
		# 与官方一致：交给场景所有者保存，重开场景时复用并在 READY 重建剪辑。
		var player_owner: Node = _sprite.owner
		if player_owner == null:
			player_owner = owner
		if player_owner == null and Engine.is_editor_hint():
			player_owner = get_tree().edited_scene_root
		if player_owner != null and player_owner.is_ancestor_of(player):
			player.owner = player_owner
	else:
		for library_name in player.get_animation_library_list():
			player.remove_animation_library(library_name)
	var library := AnimationLibrary.new()
	player.add_animation_library("", library)
	for name in data.get_animation_names():
		var animation := data.get_animation_object(name)
		if animation == null:
			continue
		var duration := float(animation.get_duration())
		var looped_clip := _create_clip(name, duration, true)
		library.add_animation(looped_clip.resource_name, looped_clip)
		var clip := _create_clip(name, duration, false)
		library.add_animation(clip.resource_name, clip)
	var reset_clip := _create_empty_clip()
	library.add_animation("RESET", reset_clip)
	library.add_animation("-- Empty --", reset_clip)


## 官方 create_animation（cpp:248-277）：clip_looped 决定剪辑名后缀与 loop 键值；
## 两条离散 value 轨指向本节点的 animation_name / loop 属性。
func _create_clip(animation_value: String, duration: float, clip_looped: bool) -> Animation:
	var clip := Animation.new()
	clip.resource_name = animation_value + ("_looped" if clip_looped else "")
	clip.length = duration if duration != 0.0 else _DEFAULT_CLIP_LENGTH
	_add_value_tracks(clip, animation_value, clip_looped)
	return clip


func _create_empty_clip() -> Animation:
	var clip := Animation.new()
	clip.resource_name = "RESET"
	clip.length = _DEFAULT_CLIP_LENGTH
	_add_value_tracks(clip, "", false)
	return clip


func _add_value_tracks(clip: Animation, animation_value: String, clip_looped: bool) -> void:
	clip.add_track(Animation.TYPE_VALUE)
	clip.track_set_path(0, ".:animation_name")
	clip.track_insert_key(0, 0.0, animation_value)
	clip.add_track(Animation.TYPE_VALUE)
	clip.track_set_path(1, ".:loop")
	clip.track_insert_key(1, 0.0, clip_looped)
	clip.value_track_set_update_mode(0, Animation.UPDATE_DISCRETE)
	clip.value_track_set_update_mode(1, Animation.UPDATE_DISCRETE)


# ---- 运行时写入（官方 cpp:586-631） ----

func _update_at_runtime(state: SpineAnimationState, player: AnimationPlayer) -> void:
	# 官方门控：未播放的 AnimationPlayer 不写状态（暂停/停止即停止选片）。
	if not player.is_playing():
		return
	var current := state.get_track(track_index)
	var should_set_mix := mix_duration >= 0.0
	var other_name := _entry_animation_name(current)
	var should_set_animation := current == null or animation_name != other_name \
			or current.get_loop() != loop or _animation_changed
	_animation_changed = false
	if not should_set_animation:
		return
	if not animation_name.is_empty():
		var entry := state.set_animation(animation_name, loop, track_index)
		if entry == null:
			return
		if should_set_mix:
			entry.set_mix_duration(mix_duration)
		entry.set_additive(additive)
		entry.set_reverse(reverse)
		entry.set_shortest_rotation(shortest_rotation)
		entry.set_time_scale(time_scale)
		entry.set_alpha(alpha)
		entry.set_mix_attachment_threshold(attachment_threshold)
		entry.set_mix_draw_order_threshold(draw_order_threshold)
		if debug:
			print("Setting animation %s with mix_duration %s on track %d on %s"
					% [animation_name, mix_duration, track_index, _sprite.name])
	else:
		if current == null or other_name != _EMPTY_ANIMATION_NAME:
			var entry := state.set_empty_animation(track_index, mix_duration if should_set_mix else 0.0)
			if entry != null:
				entry.set_track_end(_TRACK_END_MAX)
			if debug:
				print("Setting empty animation with mix_duration %s on track %d on %s"
						% [mix_duration, track_index, _sprite.name])


# ---- 编辑器写入（官方 cpp:408-578） ----

func _update_in_editor(skeleton: SpineSkeleton, state: SpineAnimationState,
		player: AnimationPlayer) -> void:
	if blend_tree_mode:
		_editor_scrub_valid = false
		_update_for_animation_tree(state)
		return
	var editing_player := _get_editing_animation_player()
	var edited_animation: Animation = null
	if editing_player != null and editing_player.has_animation(editing_player.assigned_animation):
		edited_animation = editing_player.get_animation(editing_player.assigned_animation)
	if edited_animation == null:
		_editor_scrub_valid = false
		_reset_editor_state_time_scale(state)
		return
	var root_node := editing_player.get_node_or_null(editing_player.root_node)
	if root_node == null:
		_editor_scrub_valid = false
		_reset_editor_state_time_scale(state)
		return
	var player_path := root_node.get_path_to(player)
	var found_track := -1
	for i in edited_animation.get_track_count():
		if edited_animation.track_get_path(i) == player_path:
			found_track = i
			break
	if found_track == -1:
		_editor_scrub_valid = false
		_reset_editor_state_time_scale(state)
		return
	var key_count := edited_animation.track_get_key_count(found_track)
	var playback_position := editing_player.current_animation_position
	var key_index := -1
	for i in key_count:
		var key_time := edited_animation.track_get_key_time(found_track, i)
		if key_time <= playback_position:
			key_index = i
		else:
			# 播放时间不精确，官方用动画 step 做 epsilon 比较。
			if absf(key_time - playback_position) < edited_animation.step:
				key_index = i
			break
	var key_value := ""
	if key_index != -1:
		key_value = str(edited_animation.track_get_key_value(found_track, key_index))
	var track_time := 0.0
	var can_replay := not animation_name.is_empty() and animation_name != _STOP_SENTINEL \
			and key_index != -1 and key_value != _STOP_SENTINEL \
			and player.has_animation(key_value)
	if can_replay:
		track_time = maxf((playback_position
				- edited_animation.track_get_key_time(found_track, key_index)) * time_scale, 0.0)
		var scrub_key := {
			"player": editing_player.get_instance_id(),
			"animation": edited_animation.get_instance_id(),
			"track": found_track,
			"key": key_index,
			"target": track_time,
			"name": animation_name,
			"loop": loop,
			"index": track_index,
			"mix": mix_duration,
			"additive": additive,
			"reverse": reverse,
			"shortest": shortest_rotation,
			"speed": time_scale,
			"alpha": alpha,
			"attachment": attachment_threshold,
			"draw_order": draw_order_threshold,
		}
		if _editor_scrub_valid and scrub_key == _editor_scrub_key \
				and _editor_scrub_still_active(state):
			# SB-20（SB20-R1）：输入未变（暂停 scrub/重复 seek）时不重放，
			# 直接保持上一次采样结果；本帧仅零增量收尾，因此采样与编辑器
			# 帧间隔无关，也不会持续推进骨架/物理时钟。
			# SB-20（SB20-R2）：仅当上次采样条目仍有效且仍是当前冻结条目时
			# 才复用；Preview 重应用/条目被替换或清除后走下方完整重建。
			_sprite.hold_editor_scrub_time()
			return
		_editor_scrub_key = scrub_key
	# track_index == 0 为采样轨：setup pose + 停住状态时钟，逐帧手动采样。
	if track_index == 0:
		skeleton.set_to_setup_pose()
		state.set_time_scale(0.0)
	state.clear_track(track_index)
	if animation_name.is_empty() or animation_name == _STOP_SENTINEL:
		_editor_scrub_valid = false
		return
	if key_count == 0 or key_index == -1:
		_editor_scrub_valid = false
		return
	if key_value == _STOP_SENTINEL or not player.has_animation(key_value):
		_editor_scrub_valid = false
		return
	var entry := state.set_animation(animation_name, loop, track_index)
	if entry == null:
		_editor_scrub_valid = false
		return
	entry.set_mix_duration(0.0)
	entry.set_additive(additive)
	entry.set_reverse(reverse)
	entry.set_shortest_rotation(shortest_rotation)
	entry.set_alpha(alpha)
	entry.set_mix_attachment_threshold(attachment_threshold)
	entry.set_mix_draw_order_threshold(draw_order_threshold)
	# SB-20（SB20-R1）：与 Preview 固定帧共用同一定步重放入口。含物理约束时
	# 从基准状态重放到目标时间；无物理约束时等价 set_track_time。重放后条目
	# 保持暂停，且本帧后续阶段零增量收尾，基准/上限策略见 SpineSprite。
	_sprite.replay_editor_scrub_time(entry, state, track_time)
	_editor_scrub_entry = entry
	_editor_scrub_entry_handle = entry.get_entry_handle()
	_editor_scrub_entry_time = entry.get_track_time()
	_editor_scrub_valid = true


## SB-20（SB20-R2）：缓存复用前核对上次采样条目仍有效且仍是当前条目。
## `get_track` 每次返回新包装，名称/时间/冻结状态无法区分同名同时间的外部
## 替换（旧条目还可能只作为 mixing_from 存活），因此必须比对 provider 条目
## 句柄；旧条目已释放而句柄被复用时，上面的有效性检查按代际拒绝。任一不满足
## 都在时间线输入不变时重建采样，不依赖拖动时间线或切换面板。
func _editor_scrub_still_active(state: SpineAnimationState) -> bool:
	if _editor_scrub_entry == null or not _editor_scrub_entry.is_valid():
		return false
	var current := state.get_track(track_index)
	if current == null or not current.is_valid():
		return false
	if current.get_entry_handle() != _editor_scrub_entry_handle:
		return false
	if not is_equal_approx(current.get_track_time(), _editor_scrub_entry_time):
		return false
	return is_equal_approx(current.get_time_scale(), 0.0)


## 官方 blend_tree_mode 分支（cpp:412-465）：AnimationTree 面板可见时接管采样轨，
## 恢复状态时钟并把条目时间缩放交回轨道设置；不可见时保留 sprite 预览动画。
func _update_for_animation_tree(state: SpineAnimationState) -> void:
	if not _is_animation_tree_editor_visible():
		return
	if track_index == 0:
		state.set_time_scale(1.0)
	var current := state.get_track(track_index)
	if current != null and current.is_valid():
		current.set_time_scale(time_scale)
	var should_set_mix := mix_duration >= 0.0
	var other_name := _entry_animation_name(current)
	var should_set_animation := current == null or animation_name != other_name \
			or current.get_loop() != loop
	if not should_set_animation:
		return
	if not animation_name.is_empty():
		var entry := state.set_animation(animation_name, loop, track_index)
		if entry == null:
			return
		if should_set_mix:
			entry.set_mix_duration(mix_duration)
		entry.set_additive(additive)
		entry.set_reverse(reverse)
		entry.set_shortest_rotation(shortest_rotation)
		entry.set_time_scale(time_scale)
		entry.set_alpha(alpha)
		entry.set_mix_attachment_threshold(attachment_threshold)
		entry.set_mix_draw_order_threshold(draw_order_threshold)
	else:
		if current == null or other_name != _EMPTY_ANIMATION_NAME:
			var entry := state.set_empty_animation(track_index, mix_duration if should_set_mix else 0.0)
			if entry != null:
				entry.set_track_end(_TRACK_END_MAX)


func _reset_editor_state_time_scale(state: SpineAnimationState) -> void:
	if track_index == 0:
		state.set_time_scale(1.0)


func _entry_animation_name(entry: SpineTrackEntry) -> String:
	if entry == null or not entry.is_valid():
		return ""
	var animation := entry.get_animation()
	if animation == null:
		return ""
	return animation.get_name()


# ---- 编辑器面板反射定位（官方 GDExtension 分支的做法，见模块集成方案 §3.1） ----

func _get_editing_animation_player() -> AnimationPlayer:
	var dock := _find_editor_dock("AnimationPlayer")
	if dock == null or not dock.is_visible_in_tree():
		return null
	for connection in dock.get_incoming_connections():
		var incoming: Signal = connection["signal"]
		if incoming.get_name() == &"current_animation_changed":
			return incoming.get_object() as AnimationPlayer
	return null


func _is_animation_tree_editor_visible() -> bool:
	var dock := _find_editor_dock("AnimationTree")
	return dock != null and dock.is_visible_in_tree()


func _find_editor_dock(kind: String) -> Control:
	if not Engine.is_editor_hint():
		return null
	var cached_id: int = _editor_dock_cache.get(kind, 0)
	if cached_id != 0:
		var cached := instance_from_id(cached_id)
		if cached != null and is_instance_valid(cached):
			return cached as Control
	var base := EditorInterface.get_base_control()
	if base == null:
		return null
	var matches := base.find_children("*", _EDITOR_DOCK_TYPES[kind], true, false)
	if matches.is_empty():
		return null
	var dock := matches[0] as Control
	if dock != null:
		_editor_dock_cache[kind] = dock.get_instance_id()
	return dock
