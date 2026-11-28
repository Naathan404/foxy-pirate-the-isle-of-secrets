extends DelayedBlastCharm

const COLOR := Color("e0457f")
const WORD := "BLOOM"


func on_target_defeated(target: Node, damage: DamageContext) -> void:
	if damage.source == actor and damage.is_normal_attack() and target is Node3D:
		_plant((target as Node3D).global_position, CharmBlastVfx.Kind.BLOOM, COLOR, WORD)
