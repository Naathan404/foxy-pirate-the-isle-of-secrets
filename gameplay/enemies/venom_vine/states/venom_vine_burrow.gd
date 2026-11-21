class_name VenomVineBurrow
extends EnemyState
## Cây ẩn trong gốc, rồi trồi lên bằng các khung hình cố định.

enum Phase { RETREAT, HIDDEN, EMERGE }

const FRAME_COUNT := 4

var _phase: Phase = Phase.HIDDEN
var _remaining_seconds: float = 0.0
var _initial_hide: bool = false
var _ambush_delay_seconds: float = -1.0
var _redirecting: bool = false


func _enter() -> void:
	var vine := enemy as VenomVine
	if vine == null:
		return
	_redirecting = false
	if vine.is_awake and not vine.is_burrowed:
		_redirecting = true
		request_state(&"stalk")
		return
	_initial_hide = not vine.is_awake
	_ambush_delay_seconds = -1.0
	vine._begin_burrow()
	enemy._set_horizontal_velocity(Vector3.ZERO)
	if _initial_hide:
		_phase = Phase.HIDDEN
		vine._show_burrow_frame(FRAME_COUNT - 1)
	else:
		_phase = Phase.RETREAT
		_remaining_seconds = vine.burrow_transition_seconds
		vine._show_burrow_frame(0)


func _update(delta: float) -> void:
	var vine := enemy as VenomVine
	if vine == null or vine.dead or _redirecting:
		return
	enemy._set_horizontal_velocity(Vector3.ZERO)
	var step := maxf(0.0, delta)
	match _phase:
		Phase.RETREAT:
			_remaining_seconds = maxf(0.0, _remaining_seconds - step)
			var progress := 1.0 - _remaining_seconds / vine.burrow_transition_seconds
			vine._show_burrow_frame(mini(FRAME_COUNT - 1, int(progress * FRAME_COUNT)))
			if _remaining_seconds <= 0.0:
				_phase = Phase.HIDDEN
				_remaining_seconds = vine.burrow_duration_seconds
				if vine.get_current_zone() == VenomVineAI.Zone.OUT_OF_RANGE:
					_initial_hide = true
					vine.set_awake(false)
		Phase.HIDDEN:
			_update_hidden(vine, step)
		Phase.EMERGE:
			_remaining_seconds = maxf(0.0, _remaining_seconds - step)
			var progress := 1.0 - _remaining_seconds / vine.burrow_transition_seconds
			vine._show_burrow_frame(maxi(0, FRAME_COUNT - 1 - int(progress * FRAME_COUNT)))
			if _remaining_seconds <= 0.0:
				vine._end_burrow()
				vine.set_awake(true)
				vine.attack_cooldown_remaining = maxf(
					vine.attack_cooldown_remaining, vine.wake_attack_delay_seconds
				)
				request_state(&"stalk" if vine.has_target() else &"vigilant")


func _exit() -> void:
	var vine := enemy as VenomVine
	if vine != null:
		vine._end_burrow()


func _update_hidden(vine: VenomVine, step: float) -> void:
	vine._show_burrow_frame(FRAME_COUNT - 1)
	if _initial_hide:
		if not vine.has_target() or vine._distance_to_target() > vine.outer_detection_radius_meters:
			_ambush_delay_seconds = -1.0
			return
		if _ambush_delay_seconds < 0.0:
			_ambush_delay_seconds = vine.ai.roll_ambush_hold(
				vine._distance_to_target(),
				vine.ambush_wake_distance_meters,
				vine.ambush_delay_min_seconds,
				vine.ambush_delay_max_seconds,
				vine.get_target_velocity().length()
			)
		_ambush_delay_seconds = maxf(0.0, _ambush_delay_seconds - step)
		if _ambush_delay_seconds > 0.0:
			return
	else:
		if vine.get_current_zone() == VenomVineAI.Zone.OUT_OF_RANGE:
			_initial_hide = true
			vine.set_awake(false)
			return
		_remaining_seconds = maxf(0.0, _remaining_seconds - step)
		if _remaining_seconds > 0.0:
			return
	_phase = Phase.EMERGE
	_remaining_seconds = vine.burrow_transition_seconds
