class_name VenomVineAttack
extends EnemyState
## Thực thi đợt tấn công: gồng báo hiệu (telegraph), khóa góc bắn, phóng loạt đạn và hồi thế.

enum Phase {
	CHARGE,
	FIRE,
	RECOVER,
}

const CHARGE_TINT := Color(1.18, 1.35, 0.85, 1.0)
const COUNTER_TINT := Color(1.45, 0.72, 0.52, 1.0)
const AIM_LOCK_WINDOW_SECONDS := 0.24

var _pending_plan: Dictionary = {}
var _phase: Phase = Phase.CHARGE
var _phase_remaining_seconds: float = 0.0
var _charge_total_seconds: float = 0.75
var _shot_interval_seconds: float = 0.2
var _shot_cooldown_seconds: float = 0.0
var _shots_fired: int = 0
var _aim_positions: Array[Vector3] = []
var _aim_locked: bool = false
var _base_sprite_modulate: Color = Color.WHITE


func set_pending_plan(plan: Dictionary) -> void:
	_pending_plan = plan.duplicate(true)


func is_charging() -> bool:
	return _phase == Phase.CHARGE


func _enter() -> void:
	var vine := enemy as VenomVine
	if vine == null:
		return
	enemy._set_horizontal_velocity(Vector3.ZERO)
	vine.set_sprite_sheet_mode(false)
	if is_instance_valid(vine.visual) and is_instance_valid(vine.visual.sprite):
		_base_sprite_modulate = vine.visual.sprite.modulate

	if _pending_plan.is_empty():
		_pending_plan = vine.build_attack_plan()

	var mode := int(_pending_plan.get("mode", VenomVineAI.AttackMode.NONE))
	if mode == VenomVineAI.AttackMode.NONE:
		request_state(&"stalk")
		return

	if mode == VenomVineAI.AttackMode.SPECIAL:
		vine.execute_special_attack(_pending_plan)
		_pending_plan.clear()
		request_state(&"stalk")
		return

	_aim_positions.clear()
	var raw_aims: Array = _pending_plan.get("aim_positions", [])
	for pos in raw_aims:
		if pos is Vector3:
			_aim_positions.append(pos as Vector3)

	if _aim_positions.is_empty():
		_pending_plan.clear()
		request_state(&"stalk")
		return

	_phase = Phase.CHARGE
	_charge_total_seconds = maxf(0.15, float(_pending_plan.get("charge_seconds", 0.75)))
	_phase_remaining_seconds = _charge_total_seconds
	_shot_interval_seconds = maxf(0.05, float(_pending_plan.get("shot_interval_seconds", 0.2)))
	_shot_cooldown_seconds = 0.0
	_shots_fired = 0
	_aim_locked = false
	vine.face_target()
	vine.play_directional_animation(&"charge", true)


func _exit() -> void:
	_restore_visual_feedback()
	_pending_plan.clear()


func _update(delta: float) -> void:
	var vine := enemy as VenomVine
	if vine == null or vine.dead:
		return
	enemy._set_horizontal_velocity(Vector3.ZERO)
	var step := maxf(0.0, delta)

	match _phase:
		Phase.CHARGE:
			_update_charge(vine, step)
		Phase.FIRE:
			_update_fire(vine, step)
		Phase.RECOVER:
			_update_recover(vine, step)


func _update_charge(vine: VenomVine, step: float) -> void:
	_phase_remaining_seconds = maxf(0.0, _phase_remaining_seconds - step)
	var progress := 1.0 - (_phase_remaining_seconds / maxf(0.01, _charge_total_seconds))
	_apply_charge_feedback(vine, progress)

	if not _aim_locked and _phase_remaining_seconds <= AIM_LOCK_WINDOW_SECONDS:
		_aim_locked = true
	elif not _aim_locked and vine.has_target():
		vine.face_target()

	if _phase_remaining_seconds <= 0.0:
		_begin_fire(vine)


func _begin_fire(vine: VenomVine) -> void:
	_restore_visual_feedback()
	_phase = Phase.FIRE
	_shots_fired = 0
	_shot_cooldown_seconds = 0.0
	vine.play_directional_animation(&"shoot", true)
	_fire_pending_shots(vine, 0.0)


func _update_fire(vine: VenomVine, step: float) -> void:
	_fire_pending_shots(vine, step)
	if _shots_fired >= _aim_positions.size():
		_begin_recover(vine)


func _fire_pending_shots(vine: VenomVine, step: float) -> void:
	_shot_cooldown_seconds -= step
	var raw_cfg: Variant = _pending_plan.get("pool_config", {})
	var custom_cfg: Dictionary = raw_cfg if raw_cfg is Dictionary else {}
	while _shot_cooldown_seconds <= 0.0 and _shots_fired < _aim_positions.size():
		var target_spot := _aim_positions[_shots_fired]
		vine.face_direction(target_spot - vine.global_position)
		vine.play_directional_animation(&"shoot", true)
		vine.fire_shot_at(target_spot, custom_cfg)
		_shots_fired += 1
		_shot_cooldown_seconds += _shot_interval_seconds


func _begin_recover(vine: VenomVine) -> void:
	_phase = Phase.RECOVER
	_phase_remaining_seconds = maxf(0.1, float(_pending_plan.get("recover_seconds", 0.45)))
	vine.attack_cooldown_remaining = maxf(
		0.4, float(_pending_plan.get("cooldown_seconds", vine.outer_cooldown_seconds))
	)
	vine.play_directional_animation(&"idle")


func _update_recover(vine: VenomVine, step: float) -> void:
	_phase_remaining_seconds = maxf(0.0, _phase_remaining_seconds - step)
	if _phase_remaining_seconds > 0.0:
		return
	if vine.get_current_zone() == VenomVineAI.Zone.OUT_OF_RANGE:
		request_state(&"vigilant")
	else:
		request_state(&"stalk")


func _apply_charge_feedback(vine: VenomVine, progress: float) -> void:
	if not is_instance_valid(vine.visual) or not is_instance_valid(vine.visual.sprite):
		return
	var is_counter := bool(_pending_plan.get("is_counter", false))
	var freq := 5.0 if is_counter else 3.0
	var tint := COUNTER_TINT if is_counter else CHARGE_TINT
	var pulse := 0.5 + 0.5 * sin(progress * TAU * freq)
	vine.visual.sprite.modulate = _base_sprite_modulate.lerp(tint, progress * pulse)


func _restore_visual_feedback() -> void:
	var vine := enemy as VenomVine
	if vine == null or not is_instance_valid(vine.visual):
		return
	if is_instance_valid(vine.visual.sprite):
		vine.visual.sprite.modulate = _base_sprite_modulate
