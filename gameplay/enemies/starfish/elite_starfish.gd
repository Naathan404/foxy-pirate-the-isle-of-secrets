class_name EliteStarfish
extends Starfish

@export_group("Elite Starfish Patrol")
@export var use_random_axis_patrol: bool = true
@export_range(0.05, 60.0, 0.05, "suffix:s") var axis_change_duration_min: float = 1.5
@export_range(0.05, 60.0, 0.05, "suffix:s") var axis_change_duration_max: float = 4.0


func _ready() -> void:
	var patrol := get_node_or_null("States/Patrol") as EnemyPatrol
	if patrol != null:
		patrol.use_random_axis_changes = use_random_axis_patrol
		patrol.axis_change_duration_min = axis_change_duration_min
		patrol.axis_change_duration_max = axis_change_duration_max
	super()
