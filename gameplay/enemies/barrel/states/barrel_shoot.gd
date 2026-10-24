class_name BarrelShoot
extends EnemyState

@export_range(0.0, 5.0, 0.01, "suffix:s") var fire_delay: float = 0.3
@export_range(0.01, 10.0, 0.01, "suffix:s") var shot_interval: float = 0.2
@export_range(0.0, 30.0, 0.01, "suffix:s") var burst_cooldown: float = 3.0

var shots_in_burst: int = 0
var _shots_fired: int = 0
var _shot_remaining: float = 0.0
var _fire_delay_remaining: float = 0.0
var _is_firing: bool = false


func _enter() -> void:
	enemy._set_horizontal_velocity(Vector3.ZERO)
	_start_burst()


func _update(delta: float) -> void:
	enemy._set_horizontal_velocity(Vector3.ZERO)
	if not _is_firing:
		_update_fire_delay(delta)
		return
	if _shots_fired < shots_in_burst:
		_shot_remaining -= maxf(0.0, delta)
		while _shot_remaining <= 0.0 and _shots_fired < shots_in_burst:
			_fire_next_shot()


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
	_fire_delay_remaining = fire_delay
	_is_firing = false
	enemy.play_directional_animation(&"shoot", true)


func _update_fire_delay(delta: float) -> void:
	if not enemy.has_target():
		return_to_behavior()
		return
	_fire_delay_remaining = maxf(0.0, _fire_delay_remaining - maxf(0.0, delta))
	if _fire_delay_remaining > 0.0:
		return
	_is_firing = true
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
		return_to_behavior()
