extends Node
## Coordinates short combat moments in real time with shared hitstop and camera follow.

const PRESETS := {
	&"bow_skill": {"scale": 0.52, "duration": 0.60, "zoom": 0.91, "priority": 1},
	&"harpoon_skill": {"scale": 0.55, "duration": 0.36, "zoom": 0.96, "priority": 1},
	&"near_dodge": {"scale": 0.40, "duration": 0.40, "zoom": 0.95, "priority": 2},
	&"parry": {"scale": 0.40, "duration": 0.40, "zoom": 0.95, "priority": 2},
	&"elite_defeat": {"scale": 0.35, "duration": 0.55, "zoom": 0.92, "priority": 3},
}

var _camera: Camera3D
var _base_zoom: float
var _priority: int = 0
var _started_at: int = 0
var _last_request_at: int = -100000
var _preset: Dictionary = {}
var _focus_nodes: Array[WeakRef] = []
var _focus_anchor: WeakRef
var _focus_direction := Vector3.ZERO
var _focus_offset := Vector3.ZERO
var _focus_goal := Vector3.ZERO
var _last_update_at: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


## Focus nodes are optional; the bow passes its live arrows and the shooter.
func request(
	moment: StringName,
	camera: Camera3D = null,
	focus_nodes: Array = [],
	anchor: Node3D = null,
	direction: Vector3 = Vector3.ZERO
) -> void:
	if get_tree().paused or not PRESETS.has(moment):
		return
	var preset: Dictionary = PRESETS[moment]
	var priority: int = preset.priority
	var now := Time.get_ticks_msec()
	if _started_at > 0 and priority <= _priority:
		return
	if _started_at == 0 and now - _last_request_at < 250 and priority <= _priority:
		return
	cancel()
	_priority = priority
	_last_request_at = now
	_started_at = maxi(now, 1)
	_last_update_at = now
	_preset = preset
	_camera = camera if is_instance_valid(camera) else get_viewport().get_camera_3d()
	if is_instance_valid(_camera):
		_base_zoom = (
			_camera.size if _camera.projection == Camera3D.PROJECTION_ORTHOGONAL else _camera.fov
		)
	for node in focus_nodes:
		if node is Node3D and is_instance_valid(node):
			_focus_nodes.append(weakref(node))
	_focus_anchor = weakref(anchor) if is_instance_valid(anchor) else null
	_focus_direction = direction.normalized()
	get_node("/root/HitstopController").begin_slow_motion(self, 1.0)
	set_process(true)


func _process(_delta: float) -> void:
	if (
		get_tree().paused
		or not is_instance_valid(_camera)
		or not _camera.is_inside_tree()
		or get_viewport().get_camera_3d() != _camera
	):
		cancel()
		return
	var elapsed := float(Time.get_ticks_msec() - _started_at) / 1000.0
	var duration: float = _preset.duration
	if elapsed >= duration:
		cancel()
		return
	# Smooth attack, a short hold, and a smooth return, all measured in real time.
	var fade_in := smoothstep(0.0, 0.13, elapsed)
	var fade_out := 1.0 - smoothstep(duration - 0.22, duration, elapsed)
	var weight := minf(fade_in, fade_out)
	var scale_value := lerpf(1.0, float(_preset.scale), weight)
	get_node("/root/HitstopController").begin_slow_motion(self, scale_value)
	var zoom := _base_zoom * lerpf(1.0, float(_preset.zoom), weight)
	if _camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		_camera.size = zoom
	else:
		_camera.fov = zoom
	var real_delta := clampf(float(Time.get_ticks_msec() - _last_update_at) / 1000.0, 0.0, 0.1)
	_last_update_at = Time.get_ticks_msec()
	_update_focus(weight, real_delta)


func _update_focus(weight: float, real_delta: float) -> void:
	if not _camera is BoundedFollowCamera3D or _focus_anchor == null:
		return
	var anchor := _focus_anchor.get_ref() as Node3D
	if not is_instance_valid(anchor):
		return
	var center := Vector3.ZERO
	var count := 0
	for reference in _focus_nodes:
		var arrow := reference.get_ref() as Node3D
		if (
			is_instance_valid(arrow)
			and arrow.is_inside_tree()
			and arrow.visible
			and not arrow.is_queued_for_deletion()
		):
			center += arrow.global_position
			count += 1
	if count > 0:
		center /= float(count)
		# Look slightly ahead of the moving fan, while keeping Foxy and the arena in view.
		var desired := center + _focus_direction * 1.0 - anchor.global_position
		desired.y = 0.0
		_focus_goal = desired.limit_length(2.5)
	_focus_offset = _focus_offset.lerp(_focus_goal, 1.0 - exp(-12.0 * real_delta))
	(_camera as BoundedFollowCamera3D).combat_focus_offset = _focus_offset * weight


func cancel() -> void:
	if is_instance_valid(_camera):
		if _camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
			_camera.size = _base_zoom
		else:
			_camera.fov = _base_zoom
		if _camera is BoundedFollowCamera3D:
			(_camera as BoundedFollowCamera3D).combat_focus_offset = Vector3.ZERO
	_camera = null
	_focus_nodes.clear()
	_focus_anchor = null
	_focus_offset = Vector3.ZERO
	_focus_goal = Vector3.ZERO
	_started_at = 0
	get_node("/root/HitstopController").end_slow_motion(self)
	set_process(false)


func _exit_tree() -> void:
	cancel()
