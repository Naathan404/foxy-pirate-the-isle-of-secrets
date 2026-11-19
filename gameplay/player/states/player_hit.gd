extends PlayerState

@export_range(0.0, 30.0, 0.1) var hop_speed: float = 3.2
@export var knockback_speed: float = 8.0
@export var knockback_deceleration: float = 16.0
@export_group("Spiral Knockback")
@export_range(0.0, 25.0, 0.5) var spiral_tangential_speed: float = 9.0
@export_range(0.0, 20.0, 0.5) var spiral_radial_speed: float = 5.5
@export_range(0.0, 25.0, 0.5, "suffix:rad/s") var spiral_angular_speed: float = 11.0
@export_range(1.0, 40.0, 0.5) var spiral_deceleration: float = 10.5

var _spiral_active: bool = false


# Hit recovery is governed by the stun timer, independently of animation length.
func _enter() -> void:
	timer = player.pending_hit_duration
	player.dash_buffer_remaining = 0.0

	var knockback := player.pending_hit_knockback_multiplier
	var spiral_strength := player.pending_hit_spiral_strength
	var tangent := player.pending_hit_tangent_direction
	player.pending_hit_spiral_strength = 0.0
	player.pending_hit_tangent_direction = Vector3.ZERO
	_spiral_active = spiral_strength > 0.0

	if _spiral_active:
		var radial := Vector3(player.pending_hit_direction.x, 0.0, player.pending_hit_direction.z)
		radial = radial.normalized() if not radial.is_zero_approx() else Vector3.BACK
		var tan_dir := Vector3(tangent.x, 0.0, tangent.z)
		tan_dir = (
			tan_dir.normalized() if not tan_dir.is_zero_approx() else Vector3.UP.cross(radial)
		)
		var push := (
			(tan_dir * spiral_tangential_speed + radial * spiral_radial_speed)
			* clampf(knockback * spiral_strength, 0.5, 2.0)
		)
		player.set_horizontal_velocity(push)
		player.apply_dizzy(player.WHIRLWIND_DIZZY_SECONDS)
	else:
		player.set_horizontal_velocity(player.pending_hit_direction * knockback_speed * knockback)

	if hop_speed > 0.0 and knockback > 0.0:
		player.velocity.y = maxf(player.velocity.y, hop_speed * knockback)

	player.cancel_attack()
	player.play_directional_animation("hit", true)


func _update(delta: float) -> void:
	if player.dead:
		_spiral_active = false
		return
	var step := maxf(0.0, delta)
	var horizontal_velocity := Vector3(player.velocity.x, 0.0, player.velocity.z)
	if _spiral_active:
		horizontal_velocity = horizontal_velocity.rotated(
			Vector3.UP, spiral_angular_speed * minf(step, 0.1)
		)
		horizontal_velocity = horizontal_velocity.move_toward(
			Vector3.ZERO, spiral_deceleration * step
		)
	else:
		horizontal_velocity = horizontal_velocity.move_toward(
			Vector3.ZERO, knockback_deceleration * step
		)
	player.set_horizontal_velocity(horizontal_velocity)
	if update_timer(delta):
		_spiral_active = false
		return_to_locomotion()
