extends PlayerState

@export_group("Forward Step")
@export_range(0.0, 1.0, 0.01) var step_distance: float = 0.28
@export_range(0.03, 0.4, 0.01) var step_duration: float = 0.12

var accepted: bool = false
var finished: bool = false

var controller: Node
var animation_prefix: String
var _step_direction: Vector3 = Vector3.ZERO
var _step_elapsed: float = 0.0


# Controller nhận đòn rồi mới phát animation
func _enter() -> void:
	accepted = false
	finished = false
	_step_direction = Vector3.ZERO
	_step_elapsed = 0.0
	controller = player.weapon_controller
	animation_prefix = player.attack_animation_prefix
	player.set_horizontal_velocity(Vector3.ZERO)
	if player.dead:
		return
	if (
		not is_instance_valid(controller)
		or not controller.has_method("try_attack")
		or not controller.has_method("cancel")
		or not controller.has_signal("attack_finished")
	):
		player.action_rejected.emit(&"normal_attack")
		return_to_locomotion()
		return

	if not controller is WeaponController and not player.has_attack_animation(animation_prefix):
		push_warning("PlayerAttack: mất hướng animation: " + animation_prefix)
		player.action_rejected.emit(&"normal_attack")
		return_to_locomotion()
		return

	controller.connect("attack_finished", _on_attack_finished)
	player.update_facing()
	var context := player.build_attack_context()
	accepted = bool(controller.call("try_attack", context))

	if not accepted:
		player.action_rejected.emit(&"normal_attack")
		return_to_locomotion()
		return

	if player.dead or finished or not is_instance_valid(controller):
		return

	player.last_facing_direction = context.direction

	if controller is WeaponController:
		var weapon_controller = controller as WeaponController
		animation_prefix = weapon_controller.get_attack_animation_prefix()
		player.play_directional_animation(animation_prefix, true)
		if not player.visual.fit_animation_duration(weapon_controller.get_attack_duration()):
			controller.call("cancel")
			return_to_locomotion()
			return
	else:
		player.play_directional_animation(animation_prefix, true)
	if context.action == &"normal" and player.is_on_floor():
		_step_direction = Vector3(context.direction.x, 0.0, context.direction.z).normalized()


func _update(delta: float) -> void:
	player.set_horizontal_velocity(Vector3.ZERO)
	if player.dead:
		return
	if accepted and (finished or not is_instance_valid(controller)):
		return_to_locomotion()
		return
	if accepted and player.is_on_floor():
		_apply_forward_step(delta)
	else:
		_step_direction = Vector3.ZERO


# Thoát state thì trả tốc độ animation và hủy đòn còn lại
func _exit() -> void:
	accepted = false
	_step_direction = Vector3.ZERO
	_step_elapsed = 0.0
	player.set_horizontal_velocity(Vector3.ZERO)
	if is_instance_valid(player.visual):
		player.visual.reset_animation_speed()
	#player.end_hitbox_attack()
	if is_instance_valid(controller):
		if controller.is_connected("attack_finished", _on_attack_finished):
			controller.disconnect("attack_finished", _on_attack_finished)
		if controller.has_method("cancel"):
			controller.call("cancel")
	controller = null


func _on_attack_finished(_attack_id: int = 0, _interrupted: bool = false) -> void:
	finished = true


func _apply_forward_step(delta: float) -> void:
	if (
		delta <= 0.0
		or step_duration <= 0.0
		or step_distance <= 0.0
		or _step_elapsed >= step_duration
		or _step_direction.is_zero_approx()
	):
		return
	var before := clampf(_step_elapsed / step_duration, 0.0, 1.0)
	_step_elapsed = minf(_step_elapsed + delta, step_duration)
	var after := _step_elapsed / step_duration
	# Ease out, integrating only the remaining distance even on a long physics frame.
	var fraction := (1.0 - before) * (1.0 - before) - (1.0 - after) * (1.0 - after)
	player.set_horizontal_velocity(_step_direction * step_distance * fraction / delta)
