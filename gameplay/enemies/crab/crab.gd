class_name Crab
extends EnemyBase

## Crab-owned patrol tuning. The patrol state consumes these values at startup.

@export_group("Crab Patrol")
@export var patrol_contact_damage: bool = true
@export_range(0.0, 10.0, 0.1) var patrol_speed_scale: float = 1.0


func _ready() -> void:
	var patrol := get_node_or_null("States/Patrol") as EnemyPatrol
	if patrol != null:
		patrol.use_contact_damage = patrol_contact_damage
		patrol.speed_scale = patrol_speed_scale
	if Engine.is_editor_hint():
		return
	super()
