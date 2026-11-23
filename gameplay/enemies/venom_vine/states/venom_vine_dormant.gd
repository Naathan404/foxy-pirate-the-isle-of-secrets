class_name VenomVineDormant
extends EnemyState
## Trạng thái ngụy trang thành bụi cây bình thường: đung đưa nhẹ và chờ thời điểm phục kích.

var _ambush_hold_remaining: float = -1.0


func _enter() -> void:
	var vine := enemy as VenomVine
	if vine == null:
		return
	enemy._set_horizontal_velocity(Vector3.ZERO)
	if vine.is_awake:
		request_state(&"stalk")
		return
	_ambush_hold_remaining = -1.0
	vine.set_sprite_sheet_mode(true)
	if is_instance_valid(vine.visual):
		vine.visual.play_animation(&"dormant_sway")


func _update(delta: float) -> void:
	var vine := enemy as VenomVine
	if vine == null or vine.dead:
		return
	enemy._set_horizontal_velocity(Vector3.ZERO)
	if vine.ambushed_wake:
		request_state(&"wake")
		return
	if not vine.has_target():
		_ambush_hold_remaining = -1.0
		return

	var dist := vine._distance_to_target()
	if dist > vine.outer_detection_radius_meters:
		_ambush_hold_remaining = -1.0
		return

	if _ambush_hold_remaining < 0.0:
		if vine.ai != null:
			var target_speed := vine.get_target_velocity().length()
			_ambush_hold_remaining = vine.ai.roll_ambush_hold(
				dist,
				vine.ambush_wake_distance_meters,
				vine.ambush_delay_min_seconds,
				vine.ambush_delay_max_seconds,
				target_speed
			)
		else:
			_ambush_hold_remaining = 0.0

	if dist <= vine.ambush_wake_distance_meters or _ambush_hold_remaining <= 0.0:
		request_state(&"wake")
		return
	_ambush_hold_remaining = maxf(0.0, _ambush_hold_remaining - maxf(0.0, delta))
