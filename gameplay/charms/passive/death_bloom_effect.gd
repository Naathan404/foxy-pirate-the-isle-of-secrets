extends DelayedBlastCharm


func on_target_defeated(target: Node, damage: DamageContext) -> void:
	if damage.source == actor and damage.is_normal_attack() and target is Node3D:
		_plant(target.global_position, Color("cb467d"), false)
