class_name EliteBarrelScattershot
extends EnemyState
## One elite turn: a warning, then several fans at Foxy (normal) or several 360° rings
## (special). Once the warning starts the turn always plays out, even if Foxy leaves range.

enum AttackPhase { TELEGRAPH, RELEASE }

@export_range(0.05, 3.0, 0.01, "suffix:s") var telegraph_duration: float = 0.65
## Cảnh báo dài hơn cho lượt 360°, kèm vòng đất màu `charged_color` của Elite.
@export_range(0.05, 3.0, 0.01, "suffix:s") var special_telegraph_duration: float = 1.0
@export_range(0.05, 2.0, 0.01, "suffix:s") var release_duration: float = 0.2
@export_range(0.0, 10.0, 0.01, "suffix:s") var cooldown: float = 3.0
## Thời gian Elite đỏ rực (đã tích đủ) trước khi vào cảnh báo lượt 360°.
@export_range(0.0, 10.0, 0.01, "suffix:s") var charged_cooldown: float = 1.0

var shots_in_burst: int = 0
var _shots_fired: int = 0
var _shot_remaining: float = 0.0
var _phase: AttackPhase = AttackPhase.TELEGRAPH
var _special_attack: bool = false


func _enter() -> void:
	var barrel := enemy as EliteBarrel
	if barrel == null:
		request_state(&"idle")
		return
	_special_attack = barrel.special_ready()
	if not _special_attack and not barrel.can_trigger_attack():
		request_state(&"idle")
		return
	if barrel.should_aim_at_target() and enemy.has_target():
		barrel.aim_at_target()
	_phase = AttackPhase.TELEGRAPH
	timer = special_telegraph_duration if _special_attack else telegraph_duration
	enemy.stop_movement()
	# Spine barrels open their lid while charging; the sprite sheet has no charge clip.
	if not enemy.play_directional_animation(&"charge", true):
		enemy.play_directional_animation(&"idle", true)
	var feedback := _get_feedback()
	if feedback == null:
		return
	if _special_attack:
		feedback.begin_telegraph(barrel.charged_color)
	else:
		feedback.begin_telegraph()


func _exit() -> void:
	var feedback := _get_feedback()
	if feedback != null:
		feedback.end_telegraph()


func _update(delta: float) -> void:
	enemy.stop_movement(delta)
	if _phase == AttackPhase.TELEGRAPH:
		if _timer_finished(delta):
			_release()
		return
	if _shots_fired < shots_in_burst:
		_shot_remaining -= maxf(0.0, delta)
		while _shot_remaining <= 0.0 and _shots_fired < shots_in_burst:
			_fire_next_shot()
	if _shots_fired >= shots_in_burst and _timer_finished(delta):
		request_state(&"idle")


func _release() -> void:
	var barrel := enemy as EliteBarrel
	if barrel == null:
		request_state(&"idle")
		return
	var feedback := _get_feedback()
	if feedback != null:
		feedback.end_telegraph()
	_phase = AttackPhase.RELEASE
	shots_in_burst = (
		maxi(1, barrel.special_volley_count)
		if _special_attack else maxi(1, barrel.normal_volley_count)
	)
	_shots_fired = 0
	_shot_remaining = 0.0
	timer = release_duration
	# Rings line their first ray up with Foxy once, at the end of the warning.
	if barrel.should_aim_at_target():
		barrel.aim_at_target()
	_fire_next_shot()


func _fire_next_shot() -> void:
	var barrel := enemy as EliteBarrel
	if barrel == null:
		request_state(&"idle")
		return
	enemy.play_directional_animation(&"shoot", true)
	if _special_attack:
		barrel.fire_radial_volley(barrel.special_bullets_per_volley, _shots_fired)
	else:
		# Fans follow Foxy while she stays in range, else keep the last aim.
		if _shots_fired > 0 and barrel.should_aim_at_target():
			barrel.aim_at_target()
		barrel.fire_normal_volley(_shots_fired)
	_shots_fired += 1
	var current_interval := (
		barrel.special_volley_interval if _special_attack else barrel.normal_volley_interval
	)
	_shot_remaining += current_interval
	timer = release_duration
	if _shots_fired < shots_in_burst:
		return
	if _special_attack:
		barrel.complete_special_attack()
	else:
		barrel.complete_normal_attack()
	barrel.start_attack_cooldown(charged_cooldown if barrel.special_ready() else cooldown)


func _timer_finished(delta: float) -> bool:
	return timer <= 0.0 or update_timer(delta)


func _get_feedback() -> EliteFeedback:
	return enemy.get_node_or_null("EliteFeedback") as EliteFeedback
