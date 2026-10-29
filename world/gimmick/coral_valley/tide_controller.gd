class_name TideController
extends Node
## Controls the mean water height in world space; waves remain a visual shader effect.

signal state_changed(new_state: State)
signal water_level_changed(height: float)
signal rising_warned(seconds_remaining: float)

enum State { LOW, RISING, HIGH, FALLING }

@export_group("Water")
@export var water: Node3D
@export var low_height: float = 0.0
@export var high_height: float = 2.0

@export_group("Cycle Timing")
@export var autoplay: bool = true
@export_range(0.1, 120.0, 0.1) var low_duration: float = 12.0
@export_range(0.1, 30.0, 0.1) var rise_duration: float = 4.0
@export_range(0.1, 120.0, 0.1) var high_duration: float = 12.0
@export_range(0.1, 30.0, 0.1) var fall_duration: float = 4.0
@export_range(0.0, 20.0, 0.1) var warning_seconds: float = 3.0

var state: State = State.LOW
var _elapsed: float = 0.0
var _running: bool = false
var _warned: bool = false


func _ready() -> void:
	# Inventory pauses the scene through GameManager; tide must pause with it.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_process(false)
	if autoplay:
		start()


func _process(delta: float) -> void:
	if not _running or delta <= 0.0:
		return
	if not is_instance_valid(water):
		stop()
		return
	var budget := delta
	# Carry excess time across phases so a slow frame does not delay the cycle.
	while budget > 0.0 and _running:
		var duration := _phase_duration()
		var step := minf(budget, maxf(0.0, duration - _elapsed))
		_elapsed += step
		budget -= step
		_apply_height()
		_check_warning()
		if not _running:
			return
		if _elapsed >= duration:
			_enter_state((int(state) + 1) % State.size() as State)


## Starts a fresh cycle at low tide. stop() leaves the current height in place.
func start() -> bool:
	stop()
	if not is_instance_valid(water) or not water.is_inside_tree():
		push_warning("TideController: assign a Water node inside the scene.")
		return false
	if not is_finite(low_height) or not is_finite(high_height) or high_height <= low_height:
		push_warning("TideController: High Height must be greater than Low Height.")
		return false
	_running = true
	set_process(true)
	_enter_state(State.LOW)
	return _running


func stop() -> void:
	_running = false
	set_process(false)


func is_running() -> bool:
	return _running


func get_water_height() -> float:
	return water.global_position.y if is_instance_valid(water) else low_height


func get_phase_time_remaining() -> float:
	return maxf(0.0, _phase_duration() - _elapsed)


func _enter_state(next_state: State) -> void:
	state = next_state
	_elapsed = 0.0
	if state == State.LOW:
		_warned = false
	_apply_height()
	state_changed.emit(state)
	_check_warning()


func _phase_duration() -> float:
	var duration: float
	match state:
		State.LOW:
			duration = low_duration
		State.RISING:
			duration = rise_duration
		State.HIGH:
			duration = high_duration
		State.FALLING:
			duration = fall_duration
	# Guard values assigned from code as well as the Inspector's minimum.
	return maxf(0.1, duration) if is_finite(duration) else 0.1


func _apply_height() -> void:
	if not is_instance_valid(water):
		return
	var height := low_height
	var weight := clampf(_elapsed / _phase_duration(), 0.0, 1.0)
	weight = weight * weight * (3.0 - 2.0 * weight)
	match state:
		State.RISING:
			height = lerpf(low_height, high_height, weight)
		State.HIGH:
			height = high_height
		State.FALLING:
			height = lerpf(high_height, low_height, weight)
	if is_equal_approx(water.global_position.y, height):
		return
	var position := water.global_position
	position.y = height
	water.global_position = position
	water_level_changed.emit(height)


func _check_warning() -> void:
	if not _running or state != State.LOW or _warned or warning_seconds <= 0.0:
		return
	var remaining := get_phase_time_remaining()
	if remaining <= warning_seconds:
		_warned = true
		rising_warned.emit(remaining)
