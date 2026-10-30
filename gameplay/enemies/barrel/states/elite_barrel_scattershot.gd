class_name EliteBarrelScattershot
extends EnemyState

enum AttackPhase { TELEGRAPH, RELEASE }

@export_range(0.05, 3.0, 0.01, "suffix:s") var telegraph_duration: float = 0.65
@export_range(0.05, 2.0, 0.01, "suffix:s") var release_duration: float = 0.2
@export_range(0.0, 10.0, 0.01, "suffix:s") var cooldown: float = 3.0

var _phase: AttackPhase = AttackPhase.TELEGRAPH


func _enter() -> void:
	var barrel := enemy as Barrel
	if barrel == null or not barrel.aim_at_target():
		request_state(&"idle")
		return
	_phase = AttackPhase.TELEGRAPH
	timer = telegraph_duration
	enemy.stop_movement()
	enemy.play_directional_animation(&"idle", true)
	_get_feedback().begin_telegraph()


func _exit() -> void:
	_get_feedback().end_telegraph()


func _update(delta: float) -> void:
	enemy.stop_movement(delta)
	if _phase == AttackPhase.TELEGRAPH:
		if _timer_finished(delta):
			_release()
		return
	if _timer_finished(delta):
		request_state(&"idle")


func _release() -> void:
	var barrel := enemy as Barrel
	if barrel == null:
		request_state(&"idle")
		return
	if enemy.has_target():
		barrel.aim_at_target()
	var elite_barrel := barrel as EliteBarrel
	if elite_barrel == null:
		request_state(&"idle")
		return
	barrel.fire_fan_volley(
		elite_barrel.scattershot_bullet_count, elite_barrel.scattershot_arc_degrees
	)
	barrel.start_attack_cooldown(cooldown)
	_phase = AttackPhase.RELEASE
	timer = release_duration
	enemy.play_directional_animation(&"shoot", true)
	_get_feedback().end_telegraph()


func _timer_finished(delta: float) -> bool:
	return timer <= 0.0 or update_timer(delta)


func _get_feedback() -> EliteFeedback:
	return enemy.get_node_or_null("EliteFeedback") as EliteFeedback
