class_name ProcCharmEffect
extends CharmEffect
## Base cho Passive có proc, không chia sẻ RNG state giữa các Charm.

var _proc_roller := CharmProcRoller.new()


func set_proc_seed(value: int) -> void:
	_proc_roller.set_seed(value)


func _roll_proc() -> bool:
	return definition != null and _proc_roller.roll(definition.proc_chance)
