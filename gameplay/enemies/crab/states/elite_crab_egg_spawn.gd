class_name EliteCrabEggSpawn
extends EnemyState

@export_range(0.1, 3.0, 0.05, "suffix:s") var duration: float = 0.6


func _enter() -> void:
	enemy.stop_movement()
	enemy._stop_contact_damage()
	enemy.end_active_attack()
	enemy.play_directional_animation(&"idle", true)
	var crab := enemy as EliteCrab
	if crab != null:
		crab.launch_eggs()
	timer = duration


func _update(delta: float) -> void:
	enemy.stop_movement(delta)
	if update_timer(delta):
		request_state(&"patrol")
