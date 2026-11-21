class_name VenomVineBurrow
extends EnemyState
## Cây chui nhanh xuống đất để né/chuyển chỗ, rồi luôn trồi lên lại mặt đất.

enum Phase { RETREAT, HIDDEN, RELOCATE_TELEGRAPH, EMERGE }

const FRAME_COUNT := 4

var _phase: Phase = Phase.RETREAT
var _remaining_seconds: float = 0.0
var _redirecting: bool = false
var _relocating: bool = false


func _enter() -> void:
	var vine := enemy as VenomVine
	if vine == null:
		return
	_redirecting = false
	_relocating = false
	vine._begin_burrow()
	enemy._set_horizontal_velocity(Vector3.ZERO)
	_phase = Phase.RETREAT
	_remaining_seconds = vine.burrow_transition_seconds
	vine._show_burrow_frame(0)
	vine._on_burrow_retreat_started()


func _update(delta: float) -> void:
	var vine := enemy as VenomVine
	if vine == null or vine.dead or _redirecting:
		return
	enemy._set_horizontal_velocity(Vector3.ZERO)
	var step := maxf(0.0, delta)
	match _phase:
		Phase.RETREAT:
			_remaining_seconds = maxf(0.0, _remaining_seconds - step)
			var progress := clampf(
				1.0 - _remaining_seconds / maxf(0.01, vine.burrow_transition_seconds), 0.0, 1.0
			)
			vine._show_burrow_frame(mini(FRAME_COUNT - 1, int(progress * FRAME_COUNT)))
			vine._update_burrow_retreat_visual(progress)
			if _remaining_seconds <= 0.0:
				_phase = Phase.HIDDEN
				_remaining_seconds = vine._get_burrow_hidden_duration()
				if is_instance_valid(vine.visual) and vine._should_always_relocate():
					vine.visual.visible = false
		Phase.HIDDEN:
			_update_hidden(vine, step)
		Phase.RELOCATE_TELEGRAPH:
			_remaining_seconds = maxf(0.0, _remaining_seconds - step)
			if is_instance_valid(vine.visual):
				vine.visual.visible = false
			if _remaining_seconds <= 0.0:
				_begin_emerge(vine)
		Phase.EMERGE:
			if is_instance_valid(vine.visual):
				vine.visual.visible = true
			_remaining_seconds = maxf(0.0, _remaining_seconds - step)
			var progress := clampf(
				1.0 - _remaining_seconds / maxf(0.01, vine.burrow_transition_seconds), 0.0, 1.0
			)
			vine._show_burrow_frame(maxi(0, FRAME_COUNT - 1 - int(progress * FRAME_COUNT)))
			vine._update_burrow_emerge_visual(progress, _relocating)
			if _remaining_seconds <= 0.0:
				var did_relocate := _relocating
				_relocating = false
				vine._reset_burrow_visual_state()
				vine._end_burrow()
				vine.attack_cooldown_remaining = maxf(
					vine.attack_cooldown_remaining, vine.post_emerge_attack_delay_seconds
				)
				if vine.has_target() and vine.get_current_zone() != VenomVineAI.Zone.OUT_OF_RANGE:
					vine.set_awake(true)
					if did_relocate and vine._on_relocate_emerged():
						return
					request_state(&"stalk")
				else:
					vine.set_awake(false)
					request_state(&"dormant")


func _exit() -> void:
	var vine := enemy as VenomVine
	if vine != null:
		vine._reset_burrow_visual_state()
		vine._clear_relocate_telegraph()
		vine._end_burrow()
	_redirecting = false
	_relocating = false


func _begin_emerge(vine: VenomVine) -> void:
	_phase = Phase.EMERGE
	_remaining_seconds = vine.burrow_transition_seconds
	if is_instance_valid(vine.visual):
		vine.visual.visible = true
	vine._show_burrow_frame(FRAME_COUNT - 1)
	vine._on_burrow_emerge_started(_relocating)


func _update_hidden(vine: VenomVine, step: float) -> void:
	vine._show_burrow_frame(FRAME_COUNT - 1)
	_remaining_seconds = maxf(0.0, _remaining_seconds - step)
	if _remaining_seconds > 0.0:
		return
	var relocate_target: Variant = vine._consume_relocate_target()
	if relocate_target is Vector3:
		var old_pos := vine.global_position
		var next_pos := relocate_target as Vector3
		var telegraph_seconds := maxf(0.25, vine._get_relocate_telegraph_seconds())
		vine.global_position = next_pos
		vine._spawn_relocate_telegraph(old_pos, next_pos, telegraph_seconds)
		_relocating = true
		_phase = Phase.RELOCATE_TELEGRAPH
		_remaining_seconds = telegraph_seconds
		return
	_begin_emerge(vine)
