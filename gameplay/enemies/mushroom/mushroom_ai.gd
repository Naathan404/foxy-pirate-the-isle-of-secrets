class_name MushroomAI
extends RefCounted
## Tactical RNG helper for the normal footless mushroom's ambush and spore rolls.

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


func roll_ambush_hold(
	distance_meters: float, wake_distance: float, min_delay: float, max_delay: float
) -> float:
	if distance_meters <= wake_distance:
		return 0.0
	var low := minf(min_delay, max_delay)
	var high := maxf(min_delay, max_delay)
	if high <= 0.0:
		return 0.0
	return _rng.randf_range(low, high)


func roll_knockback_spore(
	base_chance: float, was_charging: bool, mushroom_in_poison: bool, counter_bonus: float
) -> bool:
	if mushroom_in_poison:
		return false
	var effective_chance := clampf(base_chance + (counter_bonus if was_charging else 0.0), 0.0, 1.0)
	if effective_chance <= 0.0:
		return false
	return _rng.randf() < effective_chance


func roll_chase_spore(chance: float) -> bool:
	if chance <= 0.0:
		return false
	if chance >= 1.0:
		return true
	return _rng.randf() < chance
