class_name ShuttleDirector
extends Node
## Runs the raid shuttle. A shore lever calls the platform from its Center stop to that shore;
## once Foxy stands on it, it carries him to the opposite shore, waits until he steps off and
## returns to Center. Levers are ignored for the whole trip, so the platform is never a
## shortcut while it is busy.

## West is the platform's Start marker, east its End marker.
enum Side { WEST, EAST }

@export var platform: MovingPlatform
## Area over the platform deck that detects Foxy's body.
@export var boarding_area: Area3D
@export var west_lever: ShuttleCallLever
@export var east_lever: ShuttleCallLever
## How long Foxy must stand on the deck before the platform leaves.
@export_range(0.0, 3.0, 0.05, "suffix:s") var boarding_dwell_seconds: float = 0.5
## The platform goes back to Center if nobody boards within this time.
@export_range(1.0, 30.0, 0.5, "suffix:s") var boarding_timeout_seconds: float = 8.0
@export_range(0.0, 3.0, 0.05, "suffix:s") var departure_pause_seconds: float = 0.5

var _busy: bool = false


func _ready() -> void:
	if platform == null or boarding_area == null or west_lever == null or east_lever == null:
		push_error("ShuttleDirector: assign the platform, boarding area and both levers.")
		return
	west_lever.called.connect(_run_trip.bind(Side.WEST))
	east_lever.called.connect(_run_trip.bind(Side.EAST))


func is_busy() -> bool:
	return _busy


func _run_trip(shore: Side) -> void:
	if _busy:
		return
	_busy = true
	_suspend_levers(true)
	var from_east := shore == Side.EAST
	platform.request_destination(from_east)
	await platform.destination_reached
	if await _wait_for_boarding():
		platform.request_destination(not from_east)
		await platform.destination_reached
		await _wait_until_deck_clear()
	if not is_inside_tree():
		return
	await create_tween().tween_interval(departure_pause_seconds).finished
	platform.request_center()
	await platform.center_reached
	_suspend_levers(false)
	_busy = false


func _wait_for_boarding() -> bool:
	var waited_seconds := 0.0
	var aboard_seconds := 0.0
	while waited_seconds < boarding_timeout_seconds and is_inside_tree():
		await get_tree().physics_frame
		var step_seconds := get_physics_process_delta_time()
		waited_seconds += step_seconds
		aboard_seconds = aboard_seconds + step_seconds if _is_player_aboard() else 0.0
		if aboard_seconds >= boarding_dwell_seconds:
			return true
	return false


## Leaving with Foxy still aboard would strand him over the water.
func _wait_until_deck_clear() -> void:
	while is_inside_tree() and _is_player_aboard():
		await get_tree().physics_frame


func _is_player_aboard() -> bool:
	for body in boarding_area.get_overlapping_bodies():
		if body is Player and not (body as Player).dead:
			return true
	return false


func _suspend_levers(suspended: bool) -> void:
	west_lever.set_suspended(suspended)
	east_lever.set_suspended(suspended)
