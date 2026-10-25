class_name CharmProcRoller
extends RefCounted
## RNG riêng cho từng Charm; seed có thể inject để test deterministic.

var _random := RandomNumberGenerator.new()


func _init() -> void:
	_random.randomize()


func set_seed(value: int) -> void:
	_random.seed = value


func roll(chance: float) -> bool:
	var clamped_chance := clampf(chance, 0.0, 1.0)
	if clamped_chance <= 0.0:
		return false
	if clamped_chance >= 1.0:
		return true
	return _random.randf() < clamped_chance
