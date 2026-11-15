extends Node
## Shared real-time combat presentation. Higher-priority moments replace weaker ones.

const PRESETS := {
	&"bow_skill": {"scale": 0.55, "duration": 0.16, "zoom": 0.96, "priority": 1},
	&"harpoon_skill": {"scale": 0.55, "duration": 0.16, "zoom": 0.96, "priority": 1},
	&"near_dodge": {"scale": 0.40, "duration": 0.20, "zoom": 0.95, "priority": 2},
	&"parry": {"scale": 0.40, "duration": 0.20, "zoom": 0.95, "priority": 2},
	&"elite_defeat": {"scale": 0.35, "duration": 0.35, "zoom": 0.92, "priority": 3},
}

var _camera: Camera3D
var _base_zoom: float
var _priority: int = 0
var _end_at: int = 0
var _last_request_at: int = -100000
var _tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


## Call only after the underlying action has been confirmed.
func request(moment: StringName, camera: Camera3D = null) -> void:
	if get_tree().paused or not PRESETS.has(moment):
		return
	var preset: Dictionary = PRESETS[moment]
	var priority: int = preset.priority
	var now := Time.get_ticks_msec()
	if _end_at > 0 and priority <= _priority:
		return
	if _end_at == 0 and now - _last_request_at < 250 and priority <= _priority:
		return
	cancel()
	_priority = priority
	_last_request_at = now
	_end_at = now + int(float(preset.duration) * 1000.0)
	get_node("/root/HitstopController").begin_slow_motion(self, float(preset.scale))
	_camera = camera if is_instance_valid(camera) else get_viewport().get_camera_3d()
	if is_instance_valid(_camera):
		_base_zoom = _camera.size if _camera.projection == Camera3D.PROJECTION_ORTHOGONAL else _camera.fov
		var property := "size" if _camera.projection == Camera3D.PROJECTION_ORTHOGONAL else "fov"
		_tween = create_tween().set_ignore_time_scale(true)
		_tween.tween_property(_camera, property, _base_zoom * float(preset.zoom), 0.07).set_trans(Tween.TRANS_SINE)
	set_process(true)


func _process(_delta: float) -> void:
	if get_tree().paused or not is_instance_valid(_camera) or not _camera.is_inside_tree():
		cancel()
	elif Time.get_ticks_msec() >= _end_at:
		_end_at = 0
		get_node("/root/HitstopController").end_slow_motion(self)
		if _tween != null and _tween.is_valid():
			_tween.kill()
		var property := "size" if _camera.projection == Camera3D.PROJECTION_ORTHOGONAL else "fov"
		_tween = create_tween().set_ignore_time_scale(true)
		_tween.tween_property(_camera, property, _base_zoom, 0.16).set_trans(Tween.TRANS_SINE)
		_tween.tween_callback(_finish_zoom)
		set_process(false)


func _finish_zoom() -> void:
	_camera = null


func cancel() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if is_instance_valid(_camera):
		if _camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
			_camera.size = _base_zoom
		else:
			_camera.fov = _base_zoom
	_camera = null
	_end_at = 0
	get_node("/root/HitstopController").end_slow_motion(self)
	set_process(false)


func _exit_tree() -> void:
	cancel()
