extends PlayerState

@export_range(0.0, 30.0, 0.1) var hop_speed: float = 3.2
@export var knockback_speed: float = 8.0
@export var knockback_deceleration: float = 16.0


# Hit recovery is governed by the stun timer, independently of animation length.
func _enter() -> void:
	timer = player.pending_hit_duration
	player.dash_buffer_remaining = 0.0

	player.set_horizontal_velocity(player.pending_hit_direction * knockback_speed)
	if hop_speed > 0.0:
		player.velocity.y = maxf(player.velocity.y, hop_speed)

	player.cancel_attack()
	player.play_directional_animation("hit", true)


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
