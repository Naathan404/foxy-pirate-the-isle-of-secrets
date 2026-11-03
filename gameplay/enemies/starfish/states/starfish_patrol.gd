class_name StarfishPatrol
extends EnemyPatrol

@export_range(0.0, 10.0, 0.01, "suffix:s") var unreachable_target_cooldown: float = 2.0

var _unreachable_target_remaining: float = 0.0


func _update(delta: float) -> void:
	_unreachable_target_remaining = maxf(0.0, _unreachable_target_remaining - maxf(0.0, delta))
	if _unreachable_target_remaining <= 0.0 and enemy.has_target():
		request_state(&"attack")
		return
	super(delta)


func start_unreachable_target_cooldown() -> void:
	_unreachable_target_remaining = unreachable_target_cooldown
