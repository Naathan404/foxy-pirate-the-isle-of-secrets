class_name HermitCrab
extends EnemyBase

## TargetDetector dimensions are configured here so level design only edits gameplay values.

const MAX_IMPACT_NORMAL_Y := 0.5

@export_group("Hermit Crab Detection")
@export_range(0.1, 50.0, 0.1, "suffix:m") var player_detection_radius: float = 6.7:
	set(value):
		player_detection_radius = maxf(0.1, value)
		_configure_player_detector()

@export_group("Unreachable Player")
## Temporarily stop detecting a player after a dash is blocked by a wall or ledge.
@export_range(0.1, 10.0, 0.1, "suffix:s") var unreachable_target_ignore_duration: float = 2.0

@export_group("Dash Recovery")
## Match the full charge_hit and stunned Spine clips before resuming behavior.
@export_range(0.05, 5.0, 0.01, "suffix:s") var dash_impact_duration_seconds: float = 0.84
@export_range(0.05, 5.0, 0.01, "suffix:s") var dash_stun_duration_seconds: float = 1.6

var _target_detection_ignore_remaining: float = 0.0


func _ready() -> void:
	_configure_player_detector()
	if Engine.is_editor_hint():
		return
	super()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_configure_player_detector()


func _physics_process(delta: float) -> void:
	super(delta)
	if Engine.is_editor_hint() or dead or _target_detection_ignore_remaining <= 0.0:
		return
	_target_detection_ignore_remaining = maxf(
		0.0, _target_detection_ignore_remaining - maxf(0.0, delta)
	)
	if _target_detection_ignore_remaining <= 0.0:
		_resume_player_detection()


func has_dash_impact() -> bool:
	if is_instance_valid(contact_hitbox):
		for area: Area3D in contact_hitbox.get_overlapping_areas():
			var player_hurtbox := area as HurtBox
			if player_hurtbox != null and player_hurtbox.actor is Player:
				# Resolve contact before recovery disables damage, including this physics tick.
				contact_hitbox.try_hit(player_hurtbox)
				return true
	if is_front_blocked():
		return true
	for i in get_slide_collision_count():
		if absf(get_slide_collision(i).get_normal().y) < MAX_IMPACT_NORMAL_Y:
			return true
	return false


func ignore_current_target_after_unreachable_dash() -> void:
	set_target(null)
	_target_detection_ignore_remaining = unreachable_target_ignore_duration
	if is_instance_valid(target_detector):
		target_detector.monitoring = false


func _resume_player_detection() -> void:
	if not is_instance_valid(target_detector):
		return
	target_detector.monitoring = true
	# Wait one physics frame for Area3D to rebuild its overlap list.
	call_deferred("_refresh_target")


func _configure_player_detector() -> void:
	if not is_inside_tree():
		return
	var collision := get_node_or_null("TargetDetector/CollisionShape3D") as CollisionShape3D
	if collision == null:
		return
	var shape := collision.shape as CylinderShape3D
	if shape != null and not is_equal_approx(shape.radius, player_detection_radius):
		shape.radius = player_detection_radius
