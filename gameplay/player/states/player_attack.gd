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
var _combo_step: MeleeComboStep
var _step_time_scale: float = 1.0


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
	if controller is WeaponController:
		controller.attack_started.connect(_on_attack_started)
	player.update_facing()
	var context := player.build_attack_context()
	player._consume_attack_input()
	accepted = bool(controller.call("try_attack", context))

	if not accepted:
		player.action_rejected.emit(&"normal_attack")
		return_to_locomotion()
		return

	if player.dead or finished or not is_instance_valid(controller):
		return

	player.last_facing_direction = context.direction

	if not controller is WeaponController:
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
	if accepted and controller is WeaponController:
		if not player.is_on_floor():
			controller.cancel()
			return_to_locomotion()
			return
		if player.dash_buffer_remaining > 0.0 and controller.can_dash_cancel():
			if (
				is_instance_valid(player.stamina)
				and player.stamina.can_consume(player.data.dash_cost)
			):
				player.update_facing()
				request_state("dash", 10)
				return
		if player.attack_requested:
			var request := player.build_attack_context()
			controller.queue_attack(request)
			player._consume_attack_input()
		if _combo_step != null:
			player.set_horizontal_velocity(
				player.move_direction * player._get_move_speed() * _combo_step.movement_multiplier
			)
	if accepted and player.is_on_floor():
		_apply_forward_step(delta)
	else:
		_step_direction = Vector3.ZERO


# Thoát state thì trả tốc độ animation và hủy đòn còn lại
func _exit() -> void:
	accepted = false
	_step_direction = Vector3.ZERO
	_step_elapsed = 0.0
	_combo_step = null
	player.set_horizontal_velocity(Vector3.ZERO)
	if is_instance_valid(player.visual):
		player.visual.reset_animation_speed()
	#player.end_hitbox_attack()
	if is_instance_valid(controller):
		if (
			controller is WeaponController
			and controller.attack_started.is_connected(_on_attack_started)
		):
			controller.attack_started.disconnect(_on_attack_started)
		if controller.is_connected("attack_finished", _on_attack_finished):
			controller.disconnect("attack_finished", _on_attack_finished)
		if (
			controller.has_method("cancel")
			and (not controller is WeaponController or controller.busy)
		):
			controller.call("cancel")
	controller = null


func _on_attack_finished(_attack_id: int = 0, _interrupted: bool = false) -> void:
	finished = true


func _on_attack_started(context: AttackContext) -> void:
	finished = false
	_combo_step = context.combo_step
	_step_time_scale = 1.0
	if _combo_step != null:
		var authored_duration := _combo_step.windup_seconds + _combo_step.active_seconds
		authored_duration += _combo_step.recovery_seconds
		_step_time_scale = controller.get_attack_duration() / authored_duration
	_step_elapsed = 0.0
	_step_direction = context.direction if context.action == &"normal" else Vector3.ZERO
	player.last_facing_direction = context.direction
	animation_prefix = controller.get_attack_animation_prefix()
	player.play_directional_animation(animation_prefix, true)
	if not player.visual.fit_animation_duration(controller.get_attack_duration()):
		controller.cancel()


func _apply_forward_step(delta: float) -> void:
	var distance := _combo_step.step_distance if _combo_step != null else step_distance
	var duration := (
		_combo_step.step_duration * _step_time_scale if _combo_step != null else step_duration
	)
	if (
		delta <= 0.0
		or duration <= 0.0
		or distance <= 0.0
		or _step_elapsed >= duration
		or _step_direction.is_zero_approx()
	):
		return
	var before := clampf(_step_elapsed / duration, 0.0, 1.0)
	_step_elapsed = minf(_step_elapsed + delta, duration)
	var after := _step_elapsed / duration
	# Ease out, integrating only the remaining distance even on a long physics frame.
	var fraction := (1.0 - before) * (1.0 - before) - (1.0 - after) * (1.0 - after)
	var movement := Vector3(player.velocity.x, 0.0, player.velocity.z)
	player.set_horizontal_velocity(movement + _step_direction * distance * fraction / delta)
