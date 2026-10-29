extends Node

@export_range(0.001, 0.1, 0.001) var stop_scale: float = 0.01
@export_range(0.01, 0.3, 0.01) var maximum_duration: float = 0.12

var _active: bool = false
var _previous_scale: float = 1.0
var _end_at_msec: int = 0
var _local_stops: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


func request(duration: float = 0.06) -> void:
	if duration <= 0.0:
		return

	if not _active:
		_previous_scale = Engine.time_scale
		_active = true

	var milisec = int(clampf(duration, 0.0, maximum_duration) * 1000.0)

	_end_at_msec = maxi(_end_at_msec, Time.get_ticks_msec() + milisec)

	Engine.time_scale = minf(_previous_scale, stop_scale)
	set_process(true)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	for id: int in _local_stops.keys():
		if now >= int(_local_stops[id].end_at) or get_tree().paused:
			_restore_local(id)
	if _active and now >= _end_at_msec:
		Engine.time_scale = _previous_scale
		_active = false
	set_process(_active or not _local_stops.is_empty())


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
	if _active:
		Engine.time_scale = _previous_scale
	_active = false
	for id: int in _local_stops.keys():
		_restore_local(id)
	set_process(false)


func _exit_tree() -> void:
	cancel()
