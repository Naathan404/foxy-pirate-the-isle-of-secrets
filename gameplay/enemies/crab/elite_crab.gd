class_name EliteCrab
extends Crab

## Detection range is gameplay configuration, not a collider-editing task.

@export_group("Elite Crab")
@export_range(0.1, 50.0, 0.1, "suffix:m") var player_detection_radius: float = 8.0:
	set(value):
		player_detection_radius = maxf(0.1, value)
		_configure_player_detector()


func _ready() -> void:
	_configure_player_detector()
	super()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_configure_player_detector()


func _configure_player_detector() -> void:
	if not is_inside_tree():
		return
	var collision := get_node_or_null("TargetDetector/CollisionShape3D") as CollisionShape3D
	if collision == null:
		return
	var shape := collision.shape as CylinderShape3D
	if shape != null and not is_equal_approx(shape.radius, player_detection_radius):
		shape.radius = player_detection_radius
