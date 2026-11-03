extends Node

@export_range(0.001, 0.1, 0.001) var stop_scale: float = 0.01
@export_range(0.01, 0.3, 0.01) var maximum_duration: float = 0.12

var _active: bool = false
var _previous_scale: float = 1.0
var _end_at_msec: int = 0
var _local_stops: Dictionary = {}
var _slow_motion_sources: Dictionary[int, Dictionary] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


func request(duration: float = 0.06) -> void:
	if duration <= 0.0:
		return

	if not _active:
		if _slow_motion_sources.is_empty():
			_previous_scale = Engine.time_scale
		_active = true

	var milisec = int(clampf(duration, 0.0, maximum_duration) * 1000.0)

	_end_at_msec = maxi(_end_at_msec, Time.get_ticks_msec() + milisec)

	_apply_time_scale()
	set_process(true)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	var had_global_modifier: bool = _active or not _slow_motion_sources.is_empty()
	for id: int in _local_stops.keys():
		if now >= int(_local_stops[id].end_at) or get_tree().paused:
			_restore_local(id)
	if _active and now >= _end_at_msec:
		_active = false
	for id: int in _slow_motion_sources.keys():
		var source: WeakRef = _slow_motion_sources[id].source
		if not is_instance_valid(source.get_ref()):
			_slow_motion_sources.erase(id)
	if had_global_modifier:
		_apply_time_scale()
	set_process(_active or not _local_stops.is_empty() or not _slow_motion_sources.is_empty())


## Coordinates held UI slow motion with brief combat hitstop; sources release independently.
func begin_slow_motion(source: Node, time_scale: float) -> void:
	if not is_instance_valid(source) or not is_finite(time_scale) or time_scale <= 0.0:
		return
	if not _active and _slow_motion_sources.is_empty():
		_previous_scale = Engine.time_scale
	_slow_motion_sources[source.get_instance_id()] = {
		"source": weakref(source), "scale": minf(time_scale, 1.0)
	}
	_apply_time_scale()
	set_process(true)


func end_slow_motion(source: Node) -> void:
	if not is_instance_valid(source):
		return
	if _slow_motion_sources.erase(source.get_instance_id()):
		_apply_time_scale()
	set_process(_active or not _local_stops.is_empty() or not _slow_motion_sources.is_empty())


func _apply_time_scale() -> void:
	var scale_value: float = _previous_scale
	for settings: Dictionary in _slow_motion_sources.values():
		scale_value = minf(scale_value, float(settings.scale))
	if _active:
		scale_value = minf(scale_value, stop_scale)
	Engine.time_scale = scale_value


## Melee freezes only combat actors/animations; UI, audio and other actors keep running.
func request_local(source: Node3D, target: Node3D, duration: float) -> void:
	if duration <= 0.0 or get_tree().paused:
		return
	for actor: Node3D in [source, target]:
		if not is_instance_valid(actor):
			continue
		var id := actor.get_instance_id()
		# Do not extend an existing freeze when a swing catches several targets.
		if _local_stops.has(id):
			continue
		var animation := actor.get_node_or_null("Visual/AnimationPlayer") as AnimationPlayer
		_local_stops[id] = {
			"actor": weakref(actor),
			"animation": weakref(animation) if animation != null else null,
			"speed": animation.speed_scale if animation != null else 1.0,
			"end_at": Time.get_ticks_msec() + int(minf(duration, maximum_duration) * 1000.0),
		}
		if animation != null:
			animation.speed_scale = 0.0
	set_process(true)


func is_frozen(actor: Node) -> bool:
	return is_instance_valid(actor) and _local_stops.has(actor.get_instance_id())


func _restore_local(id: int) -> void:
	var snapshot: Dictionary = _local_stops[id]
	var animation_ref: WeakRef = snapshot.animation
	if animation_ref != null:
		var animation := animation_ref.get_ref() as AnimationPlayer
		if is_instance_valid(animation) and is_zero_approx(animation.speed_scale):
			animation.speed_scale = snapshot.speed
	_local_stops.erase(id)


func cancel() -> void:
	if _active or not _slow_motion_sources.is_empty():
		Engine.time_scale = _previous_scale
	_active = false
	_slow_motion_sources.clear()
	for id: int in _local_stops.keys():
		_restore_local(id)
	set_process(false)


func _exit_tree() -> void:
	cancel()
