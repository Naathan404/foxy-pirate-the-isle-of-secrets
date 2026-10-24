extends PlayerState

@export_range(0.0, 30.0, 0.1) var hop_speed: float = 3.2
@export var knockback_speed: float = 8.0
@export var knockback_deceleration: float = 16.0

var _animation_finished: bool = true


# Wait for both the stun duration and the actual one-shot animation.
func _enter() -> void:
	timer = player.pending_hit_duration
	player.dash_buffer_remaining = 0.0

	player.set_horizontal_velocity(player.pending_hit_direction * knockback_speed)
	if hop_speed > 0.0:
		player.velocity.y = maxf(player.velocity.y, hop_speed)

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
	var horizontal_velocity := Vector3(player.velocity.x, 0.0, player.velocity.z)
	horizontal_velocity = horizontal_velocity.move_toward(
		Vector3.ZERO, knockback_deceleration * maxf(0.0, delta)
	)
	player.set_horizontal_velocity(horizontal_velocity)
	if update_timer(delta):
		return_to_locomotion()


func _exit() -> void:
	if is_instance_valid(player.visual):
		if player.visual.animation_finished.is_connected(_on_animation_finished):
			player.visual.animation_finished.disconnect(_on_animation_finished)


func _on_animation_finished(animation_name: StringName) -> void:
	if String(animation_name).begins_with("hit_"):
		_animation_finished = true
