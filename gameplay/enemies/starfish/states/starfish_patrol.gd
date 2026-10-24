class_name StarfishPatrol
extends EnemyPatrol


func _update(delta: float) -> void:
	if enemy.has_target():
		request_state(&"attack")
		return
	super(delta)
