class_name SilasRestockSchedule
extends RefCounted
## Decides when Silas's black-market stock goes stale: on the first visit to each area and after
## a random stretch of play time. The interval is never shown, so players cannot predict it.

var min_interval_seconds: float
var max_interval_seconds: float

var _visited_areas: Dictionary[StringName, bool] = {}
var _elapsed_seconds: float = 0.0
## Zero until armed by the next advance() call, which draws a fresh random length.
var _interval_seconds: float = 0.0


func _init(min_seconds: float, max_seconds: float) -> void:
	min_interval_seconds = minf(min_seconds, max_seconds)
	max_interval_seconds = maxf(min_seconds, max_seconds)


## Returns true when `delta_seconds` of play time completes the current interval.
func advance(delta_seconds: float, random: RandomNumberGenerator) -> bool:
	if _interval_seconds <= 0.0:
		_interval_seconds = random.randf_range(min_interval_seconds, max_interval_seconds)
	_elapsed_seconds += maxf(0.0, delta_seconds)
	if _elapsed_seconds < _interval_seconds:
		return false
	_elapsed_seconds = 0.0
	_interval_seconds = 0.0
	return true


## Returns true only the first time `area_id` is entered, so crossing back and forth between
## two areas cannot be used to farm rerolls.
func note_area_entered(area_id: StringName) -> bool:
	if area_id.is_empty() or _visited_areas.has(area_id):
		return false
	_visited_areas[area_id] = true
	return true


func reset() -> void:
	_visited_areas.clear()
	_elapsed_seconds = 0.0
	_interval_seconds = 0.0
