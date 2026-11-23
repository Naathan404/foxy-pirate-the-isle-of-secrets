extends CharmEffect

var _armed := false


func on_equipped() -> void:
	var controller := actor.get("weapon_controller") as WeaponController
	if is_instance_valid(controller):
		controller.attack_released.connect(_on_attack_released)


func on_unequipped() -> void:
	var controller := actor.get("weapon_controller") as WeaponController
	if (
		is_instance_valid(controller)
		and controller.attack_released.is_connected(_on_attack_released)
	):
		controller.attack_released.disconnect(_on_attack_released)
	cancel_active()


func on_dash_finished(interrupted: bool) -> void:
	if not interrupted:
		_armed = true
		runtime.proc_triggered.emit("MOMENTUM", CharmVfx.TIDE)


func _on_attack_released(attack: AttackContext) -> void:
	if _armed and attack.action == &"normal":
		_armed = false
		attack.damage_hp *= definition.get_param_float(&"damage_multiplier")
		CharmVfx.streak(
			actor.get_parent(),
			attack.origin + Vector3.UP * 0.6,
			attack.origin + Vector3.UP * 0.6 + attack.direction * 1.7,
			CharmVfx.TIDE
		)


func cancel_active() -> void:
	_armed = false
