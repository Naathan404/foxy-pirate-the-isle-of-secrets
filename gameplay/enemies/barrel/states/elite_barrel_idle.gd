class_name EliteBarrelIdle
extends BarrelIdle


func _update(delta: float) -> void:
	enemy._set_horizontal_velocity(Vector3.ZERO)
	var barrel := enemy as Barrel
	if barrel == null or not barrel.update_attack_cooldown(delta):
		return
	if not enemy.has_target():
		return
	barrel.aim_at_target()
	request_state(&"scattershot")
