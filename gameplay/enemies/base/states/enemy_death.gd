extends EnemyState

var _death_animation: StringName = &""
var _recoiling: bool = false


func _init() -> void:
	is_terminal = true


func _enter() -> void:
	enemy.end_active_attack()
	enemy._stop_contact_damage()
	enemy._disable_combat_collision()
	# Keep world collision during the fatal recoil without interacting with actors.
	enemy.collision_mask = CombatLayers.WORLD
	enemy.play_directional_animation(&"hit", true)
	if is_instance_valid(enemy.visual):
		enemy.visual.play_hit_feedback()
	enemy._set_horizontal_velocity(enemy.consume_hit_knockback_velocity())
	timer = enemy.data.hit_duration if enemy.data != null else 0.0
	_recoiling = true


func _update(delta: float) -> void:
	if not _recoiling:
		return
	if not enemy.is_on_floor():
		enemy.velocity += enemy.get_gravity() * delta
	elif enemy.velocity.y < 0.0:
		enemy.velocity.y = 0.0
	if enemy.data != null:
		enemy._damp_horizontal_velocity(delta, enemy.data.hit_deceleration)
	enemy.move_and_slide()
	if timer <= 0.0 or update_timer(delta):
		_begin_death_animation()


func _begin_death_animation() -> void:
	_recoiling = false
	enemy.velocity = Vector3.ZERO
	enemy.collision_mask = 0
	var animation_started := enemy.play_directional_animation(&"death", true)
	if not enemy.destroy_on_death:
		return
	if not animation_started or not is_instance_valid(enemy.visual):
		enemy.queue_free()
		return
	_death_animation = enemy.visual.animation_player.assigned_animation
	enemy.visual.animation_finished.connect(_on_death_animation_finished)


func _on_death_animation_finished(animation_name: StringName) -> void:
	if animation_name != _death_animation:
		return
	enemy.visual.animation_finished.disconnect(_on_death_animation_finished)
	if not enemy.dead or not enemy.destroy_on_death:
		return
	if not enemy.visual.play_death_feedback():
		enemy.queue_free()
		return
	enemy.visual.death_feedback_finished.connect(_on_death_feedback_finished, CONNECT_ONE_SHOT)


func _on_death_feedback_finished() -> void:
	if enemy.dead and enemy.destroy_on_death:
		enemy.queue_free()
