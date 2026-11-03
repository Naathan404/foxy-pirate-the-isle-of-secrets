class_name WarLordTurtle
extends EnemyBase

@export_group("War Lord Turtle Patrol")
@export_range(0.0, 10.0, 0.1) var patrol_speed_scale: float = 0.8
@export var patrol_contact_damage: bool = true
@export var use_random_axis_patrol: bool = true


func _ready() -> void:
	var patrol := get_node_or_null("States/Patrol") as EnemyPatrol
	if patrol != null:
		patrol.speed_scale = patrol_speed_scale
		patrol.use_contact_damage = patrol_contact_damage
		patrol.use_random_axis_changes = use_random_axis_patrol
	super()
