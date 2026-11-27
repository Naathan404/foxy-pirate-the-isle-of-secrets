class_name EliteBarrelIdle
extends BarrelIdle


## A charged elite fires its 360° turn as soon as the cooldown ends, with or without Foxy in
## range; the normal turn still waits for a target.
func _update(delta: float) -> void:
	enemy._set_horizontal_velocity(Vector3.ZERO)
	var barrel := enemy as EliteBarrel
	if barrel == null or not barrel.update_attack_cooldown(delta):
		return
	if not barrel.special_ready() and not barrel.can_trigger_attack():
		return
	if barrel.should_aim_at_target() and enemy.has_target():
		barrel.aim_at_target()
	request_state(&"scattershot")
