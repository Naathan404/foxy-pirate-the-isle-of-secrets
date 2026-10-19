extends PlayerState

var accepted: bool = false
var finished: bool = false

var controller: Node
var animation_prefix: String


# Controller nhận đòn rồi mới phát animation
func _enter() -> void:
	accepted = false
	finished = false
	controller = player.attack_controller
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
	else:
		player.play_directional_animation(animation_prefix, true)


func _update(_delta: float) -> void:
	player.set_horizontal_velocity(Vector3.ZERO)
	if player.dead:
		return
	if accepted and (finished or not is_instance_valid(controller)):
		return_to_locomotion()


# Thoát state thì trả tốc độ animation và hủy đòn còn lại
func _exit() -> void:
	accepted = false
	if is_instance_valid(player.visual):
		player.visual.reset_animation_speed()
	player.end_hitbox_attack()
	if is_instance_valid(controller):
		if controller.is_connected("attack_finished", _on_attack_finished):
			controller.disconnect("attack_finished", _on_attack_finished)
		if controller.has_method("cancel"):
			controller.call("cancel")
	controller = null


func _on_attack_finished(_attack_id: int = 0, _interrupted: bool = false) -> void:
	finished = true
