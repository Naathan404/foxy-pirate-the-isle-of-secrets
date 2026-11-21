class_name MushroomAI
extends RefCounted
## Tactical RNG helper for the normal footless mushroom's ambush, leap, and spore rolls.

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


func roll_approach_leap(
	distance_meters: float, trigger_distance_meters: float, chance: float
) -> bool:
	if distance_meters < trigger_distance_meters:
		return false
	return _rng.randf() < clampf(chance, 0.0, 1.0)


func compute_hp_pressure(current_hp: float, max_hp: float) -> float:
	if max_hp <= 0.0:
		return 0.0
	return clampf(1.0 - current_hp / max_hp, 0.0, 1.0)


func compute_attack_cadence(
	base_cooldown: float,
	base_charge: float,
	base_chase_interval: float,
	base_chase_chance: float,
	hp_pressure: float,
	cooldown_reduction_max: float,
	charge_speedup_max: float,
	chase_chance_bonus: float
) -> Dictionary:
	var pressure := clampf(hp_pressure, 0.0, 1.0)
	var cd_scale := 1.0 - pressure * clampf(cooldown_reduction_max, 0.0, 0.6)
	var charge_scale := 1.0 - pressure * clampf(charge_speedup_max, 0.0, 0.4)
	var interval_scale := 1.0 - pressure * 0.32
	return {
		"cooldown": maxf(minf(base_cooldown, 1.4), base_cooldown * cd_scale),
		"charge": maxf(minf(base_charge, 0.95), base_charge * charge_scale),
		"chase_interval":
		maxf(minf(base_chase_interval, 0.9), base_chase_interval * interval_scale),
		"chase_chance": clampf(base_chase_chance + pressure * chase_chance_bonus, 0.0, 0.85),
	}
