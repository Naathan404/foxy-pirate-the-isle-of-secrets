extends PlayerState

@export var hop_speed: float = 15.0
@export var knockback_speed: float = 10.0

# Ngat don va dung di chuyen cho den khi het thoi gian choang.
func _enter() -> void:
	timer = player.pending_hit_duration
	player.dash_buffer_remaining = 0.0

	var vt: Vector2 = -obj.forward() * knockback_speed
	obj.velocity.x = vt.x 
	obj.velocity.z = vt.z
	obj.velocity.y = hop_speed

	player.cancel_attack()
	player.set_horizontal_velocity(Vector3.ZERO)
	player.play_directional_animation("hit", true)


func _update(delta: float) -> void:
	if player.dead:
		return
	player.set_horizontal_velocity(Vector3.ZERO)
	if update_timer(delta):
		return_to_locomotion()
