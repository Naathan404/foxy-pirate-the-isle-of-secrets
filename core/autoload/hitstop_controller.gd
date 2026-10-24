extends Node

@export_range(0.001, 0.1, 0.001) var stop_scale: float = 0.01
@export_range(0.01, 0.3, 0.01) var maximum_duration: float = 0.12

var _active: bool = false
var _previous_scale: float = 1.0
var _end_at_msec: int = 0


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
	if Time.get_ticks_msec() >= _end_at_msec:
		cancel()


func cancel() -> void:
	if _active:
		Engine.time_scale = _previous_scale
	_active = false
	set_process(false)


func _exit_tree() -> void:
	cancel()
