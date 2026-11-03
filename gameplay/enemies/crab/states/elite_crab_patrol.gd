class_name EliteCrabPatrol
extends CrabPatrol

@export_range(0.0, 10.0, 0.01, "suffix:s") var charge_cooldown: float = 2.4
@export_range(0.0, 10.0, 0.01, "suffix:s") var unreachable_target_cooldown: float = 2.0

var _charge_cooldown_remaining: float = 0.0


func _update(delta: float) -> void:
	_charge_cooldown_remaining = maxf(0.0, _charge_cooldown_remaining - maxf(0.0, delta))
	if _charge_cooldown_remaining <= 0.0 and enemy.has_target():
		request_state(&"charge")
		return
	super(delta)


func start_charge_cooldown() -> void:
	_charge_cooldown_remaining = charge_cooldown


func start_unreachable_target_cooldown() -> void:
	_charge_cooldown_remaining = maxf(_charge_cooldown_remaining, unreachable_target_cooldown)
