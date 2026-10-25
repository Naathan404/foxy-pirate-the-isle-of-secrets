class_name BarrelShoot
extends EnemyState

enum AttackPhase { CHARGE, FIRE }

@export_group("Attack Cycle")
## Thời gian charge trước khi bắn.
@export_range(0.0, 5.0, 0.01, "suffix:s") var fire_delay: float = 0.3
## Thời gian giữa các viên đạn trong một đợt.
@export_range(0.01, 10.0, 0.01, "suffix:s") var shot_interval: float = 0.2
## Thời gian nghỉ sau mỗi đợt bắn.
@export_range(0.0, 30.0, 0.01, "suffix:s") var burst_cooldown: float = 3.0

@export_group("Charge Feedback")
## Tỉ lệ kích thước tối đa khi charge; 1.08 là phình thêm 8%.
@export_range(1.0, 2.0, 0.01) var charge_scale: float = 1.08
## Khoảng lệch sang mỗi bên khi rung.
@export_range(0.0, 1.0, 0.01, "suffix:m") var shake_distance: float = 0.03
## Thời gian di chuyển giữa hai vị trí rung.
@export_range(0.01, 1.0, 0.01, "suffix:s") var shake_interval: float = 0.05
## Thời gian thu về kích thước ban đầu khi bắt đầu bắn.
@export_range(0.01, 1.0, 0.01, "suffix:s") var release_duration: float = 0.12

var shots_in_burst: int = 0
var _shots_fired: int = 0
var _shot_remaining: float = 0.0
var _phase_remaining: float = 0.0
var _phase: AttackPhase = AttackPhase.CHARGE
var _visual_scale: Vector3 = Vector3.ONE
var _visual_position: Vector3 = Vector3.ZERO
var _scale_tween: Tween
var _shake_tween: Tween


func _enter() -> void:
	enemy._set_horizontal_velocity(Vector3.ZERO)
	if is_instance_valid(enemy.visual):
		_visual_scale = enemy.visual.scale
		_visual_position = enemy.visual.position
	_start_burst()


func _exit() -> void:
	_stop_feedback()
	if is_instance_valid(enemy.visual):
		enemy.visual.scale = _visual_scale
		enemy.visual.position = _visual_position


func _update(delta: float) -> void:
	enemy._set_horizontal_velocity(Vector3.ZERO)
	if _phase == AttackPhase.CHARGE:
		_update_charge(delta)
		return
	_phase_remaining = maxf(0.0, _phase_remaining - maxf(0.0, delta))
	if _shots_fired < shots_in_burst:
		_shot_remaining -= maxf(0.0, delta)
		while _shot_remaining <= 0.0 and _shots_fired < shots_in_burst:
			_fire_next_shot()
	if _shots_fired >= shots_in_burst and _phase_remaining <= 0.0:
		return_to_behavior()


func _start_burst() -> void:
	var barrel := enemy as Barrel
	if barrel == null:
		return_to_behavior()
		return
	if not barrel.aim_at_target():
		return_to_behavior()
		return
	shots_in_burst = barrel.get_bullet_count()
	_shots_fired = 0
	_shot_remaining = 0.0
	_phase = AttackPhase.CHARGE
	_phase_remaining = fire_delay
	enemy.play_directional_animation(&"idle", true)
	_start_charge_feedback()


func _update_charge(delta: float) -> void:
	if not enemy.has_target():
		return_to_behavior()
		return
	_phase_remaining = maxf(0.0, _phase_remaining - maxf(0.0, delta))
	if _phase_remaining > 0.0:
		return
	_begin_firing()


func _begin_firing() -> void:
	_phase = AttackPhase.FIRE
	_stop_feedback()
	_phase_remaining = release_duration
	if is_instance_valid(enemy.visual):
		enemy.visual.position = _visual_position
		_scale_tween = create_tween()
		_scale_tween.tween_property(enemy.visual, "scale", _visual_scale, release_duration)
	if enemy.play_directional_animation(&"shoot", true) and is_instance_valid(enemy.visual):
		var player := enemy.visual.animation_player
		var animation := player.get_animation(player.assigned_animation)
		if animation != null:
			_phase_remaining = maxf(_phase_remaining, animation.length)
	_fire_next_shot()


func _fire_next_shot() -> void:
	var barrel := enemy as Barrel
	if barrel == null:
		return_to_behavior()
		return
	if enemy.has_target():
		barrel.aim_at_target()
	barrel.fire()
	_shots_fired += 1
	_shot_remaining += shot_interval
	if _shots_fired >= shots_in_burst:
		barrel.start_attack_cooldown(burst_cooldown)


func _start_charge_feedback() -> void:
	if not is_instance_valid(enemy.visual):
		return
	_scale_tween = create_tween()
	_scale_tween.tween_property(
		enemy.visual, "scale", _visual_scale * charge_scale, maxf(fire_delay, 0.01)
	)
	if shake_distance <= 0.0:
		return
	_shake_tween = create_tween().set_loops()
	_shake_tween.tween_property(
		enemy.visual, "position:x", _visual_position.x + shake_distance, shake_interval
	)
	_shake_tween.tween_property(
		enemy.visual, "position:x", _visual_position.x - shake_distance, shake_interval
	)


func _stop_feedback() -> void:
	if _scale_tween != null:
		_scale_tween.kill()
		_scale_tween = null
	if _shake_tween != null:
		_shake_tween.kill()
		_shake_tween = null
