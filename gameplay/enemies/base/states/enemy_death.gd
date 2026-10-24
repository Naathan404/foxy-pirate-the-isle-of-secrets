extends EnemyState

var _death_animation: StringName = &""


func _init() -> void:
	is_terminal = true


func _enter() -> void:
	enemy._set_horizontal_velocity(Vector3.ZERO)
	enemy.end_active_attack()
	enemy._stop_contact_damage()
	enemy._disable_combat_collision()
	var animation_started := enemy.play_directional_animation(&"death", true)
	if not enemy.destroy_on_death:
		return
	if not animation_started or not is_instance_valid(enemy.visual):
		enemy.queue_free()
		return
	_death_animation = enemy.visual.animation_player.assigned_animation
	enemy.visual.animation_finished.connect(_on_death_animation_finished, CONNECT_ONE_SHOT)


func _on_death_animation_finished(animation_name: StringName) -> void:
	if animation_name != _death_animation:
		return
	if not enemy.dead or not enemy.destroy_on_death:
		return
	if not enemy.visual.play_death_feedback():
		enemy.queue_free()
		return
	enemy.visual.death_feedback_finished.connect(_on_death_feedback_finished, CONNECT_ONE_SHOT)


func _on_death_feedback_finished() -> void:
	if enemy.dead and enemy.destroy_on_death:
		enemy.queue_free()
