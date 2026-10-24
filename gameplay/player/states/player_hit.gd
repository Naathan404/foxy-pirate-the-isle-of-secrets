extends PlayerState

@export var hop_speed: float = 5.0
@export var knockback_speed: float = 10.0

var _animation_finished: bool = true


# Wait for both the stun duration and the actual one-shot animation.
func _enter() -> void:
	timer = player.pending_hit_duration
	player.dash_buffer_remaining = 0.0

	var facing := Vector3(player.last_facing_direction.x, 0.0, player.last_facing_direction.z)
	player.set_horizontal_velocity(-facing.normalized() * knockback_speed)
	player.velocity.y = hop_speed

	player.cancel_attack()
	player.play_directional_animation("hit", true)
	_animation_finished = true
	if is_instance_valid(player.visual) and is_instance_valid(player.visual.animation_player):
		var animator := player.visual.animation_player
		var animation_name := animator.assigned_animation
		if String(animation_name).begins_with("hit_") and animator.has_animation(animation_name):
			var animation := animator.get_animation(animation_name)
			if animation.loop_mode == Animation.LOOP_NONE and animator.is_playing():
				_animation_finished = false
				player.visual.animation_finished.connect(_on_animation_finished)


func _update(delta: float) -> void:
	if player.dead:
		return
	player.update_movement(delta, false)
	update_timer(delta)
	if timer <= 0.0 and _animation_finished:
		return_to_locomotion()


func _exit() -> void:
	if is_instance_valid(player.visual):
		if player.visual.animation_finished.is_connected(_on_animation_finished):
			player.visual.animation_finished.disconnect(_on_animation_finished)


func _on_animation_finished(animation_name: StringName) -> void:
	if String(animation_name).begins_with("hit_"):
		_animation_finished = true
