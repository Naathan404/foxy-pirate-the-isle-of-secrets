extends Node

## Rung Camera3D theo thời gian thực, độc lập với hitstop và chuyển động của nhân vật.
@export_range(0.0, 20.0, 0.5) var maximum_pixels: float = 8.0
@export_range(0.01, 1.0, 0.01) var maximum_duration: float = 0.3
@export_range(1.0, 60.0, 1.0) var frequency: float = 35.0
## Dùng khi camera không có cha Node3D làm mốc quy đổi pixel sang khoảng cách thế giới.
@export_range(0.1, 100.0, 0.1) var fallback_depth: float = 28.0

var _camera: Camera3D
var _base_offset: Vector2
var _strength: float = 0.0
var _duration: float = 0.0
var _end_at_usec: int = 0
var _noise := FastNoiseLite.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	_noise.frequency = 1.0
	_noise.seed = randi()
	set_process(false)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var active_camera := get_viewport().get_camera_3d()
	if get_tree().paused or now >= _end_at_usec or not is_instance_valid(active_camera):
		cancel()
		return
	_bind_camera(active_camera)
	var phase := float(now) / 1000000.0 * frequency
	var jitter := Vector2(_noise.get_noise_2d(phase, 17.0), _noise.get_noise_2d(53.0, phase))
	var displacement := jitter * _current_strength(now) * _world_units_per_pixel()
	# Chỉ đổi offset dựng hình; camera vẫn theo cha Foxy, HUD CanvasLayer không bị rung.
	_camera.h_offset = _base_offset.x + displacement.x
	_camera.v_offset = _base_offset.y + displacement.y


func _exit_tree() -> void:
	cancel()


func request(pixels: float = 3.0, duration: float = 0.14) -> void:
	if pixels <= 0.0 or duration <= 0.0 or get_tree().paused:
		return
	var active_camera := get_viewport().get_camera_3d()
	if not is_instance_valid(active_camera):
		return
	_bind_camera(active_camera)
	var now := Time.get_ticks_usec()
	var remaining := maxf(float(_end_at_usec - now) / 1000000.0, 0.0)
	# Lấy lực mạnh hơn thay vì cộng dồn để nhiều mục tiêu không làm rung quá mức.
	_strength = minf(maxf(_current_strength(now), pixels), maximum_pixels)
	_duration = maxf(remaining, minf(duration, maximum_duration))
	_end_at_usec = now + int(_duration * 1000000.0)
	set_process(true)


func cancel() -> void:
	_restore_camera()
	_camera = null
	_strength = 0.0
	_duration = 0.0
	_end_at_usec = 0
	set_process(false)


func _current_strength(now: int) -> float:
	if _duration <= 0.0:
		return 0.0
	var remaining := float(_end_at_usec - now) / 1000000.0
	var weight := clampf(remaining / _duration, 0.0, 1.0)
	return _strength * weight * weight


func _bind_camera(camera: Camera3D) -> void:
	if camera == _camera:
		return
	# Đổi scene/camera giữa lúc rung phải trả offset của camera cũ về đúng giá trị gốc.
	_restore_camera()
	_camera = camera
	_base_offset = Vector2(camera.h_offset, camera.v_offset)


func _restore_camera() -> void:
	if is_instance_valid(_camera):
		_camera.h_offset = _base_offset.x
		_camera.v_offset = _base_offset.y


func _world_units_per_pixel() -> float:
	var depth := fallback_depth
	var anchor := _camera.get_parent() as Node3D
	if is_instance_valid(anchor):
		depth = maxf(-_camera.to_local(anchor.global_position).z, _camera.near + 0.01)
	var center := _camera.get_viewport().get_visible_rect().size * 0.5
	# project_position hỗ trợ cả camera perspective và orthogonal.
	var origin := _camera.project_position(center, depth)
	return origin.distance_to(_camera.project_position(center + Vector2.DOWN, depth))
