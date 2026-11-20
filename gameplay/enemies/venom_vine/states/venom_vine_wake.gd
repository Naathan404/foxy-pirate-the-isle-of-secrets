class_name VenomVineWake
extends EnemyState
## Trạng thái thức tỉnh: tách nụ hoa khỏi ngụy trang, xoay ngắm và mở giao tranh công bằng.

const AMBUSHED_ATTACK_DELAY_SECONDS := 0.18

var _remaining_seconds: float = 0.0


func _enter() -> void:
	var vine := enemy as VenomVine
	if vine == null:
		return
	enemy._set_horizontal_velocity(Vector3.ZERO)
	vine.set_awake(true)
	vine.set_sprite_sheet_mode(true)
	vine.face_target()
	_remaining_seconds = vine.wake_duration_seconds
	if vine.ambushed_wake or vine.has_pending_counter():
		vine.ambushed_wake = false
		_remaining_seconds = minf(_remaining_seconds, 0.18)
		vine.attack_cooldown_remaining = (
			0.0
			if vine.has_pending_counter()
			else minf(vine.attack_cooldown_remaining, AMBUSHED_ATTACK_DELAY_SECONDS)
		)
	else:
		vine.attack_cooldown_remaining = maxf(
			vine.attack_cooldown_remaining, vine.wake_attack_delay_seconds
		)
	if is_instance_valid(vine.visual):
		vine.visual.play_animation(&"wake", true)


func _update(delta: float) -> void:
	var vine := enemy as VenomVine
	if vine == null or vine.dead:
		return
	enemy._set_horizontal_velocity(Vector3.ZERO)
	if vine.has_target():
		vine.face_target()
	_remaining_seconds = maxf(0.0, _remaining_seconds - maxf(0.0, delta))
	if _remaining_seconds <= 0.0:
		vine.set_sprite_sheet_mode(false)
		if vine.has_target():
			request_state(&"stalk")
		else:
			request_state(&"vigilant")
