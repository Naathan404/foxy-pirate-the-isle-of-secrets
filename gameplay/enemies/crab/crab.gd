class_name Crab
extends EnemyBase

## Crab-owned patrol tuning. The patrol state consumes these values at startup.

@export_group("Crab Patrol")
@export var patrol_contact_damage: bool = true
@export_range(0.0, 10.0, 0.1) var patrol_speed_scale: float = 1.0

@export_group("Crab Chase")
## Tốc độ khi đuổi player, nhân với move_speed của EnemyData.
@export_range(0.0, 10.0, 0.05) var chase_speed_scale: float = 1.2
@export_range(0.1, 50.0, 0.1, "suffix:m") var player_detection_radius: float = 6.5
@export_range(1.0, 100.0, 0.5, "suffix:m") var movement_radius: float = 12.0
@export_range(0.1, 10.0, 0.1, "suffix:m") var min_chase_segment_distance: float = 1.0
@export_range(0.1, 5.0, 0.1, "suffix:m") var chase_stop_distance: float = 1.2

@export_group("Crab Anger")
@export_range(0.1, 30.0, 0.1, "suffix:s") var anger_duration: float = 5.0
@export_range(1.0, 5.0, 0.1) var anger_detection_multiplier: float = 1.5
@export_range(1.0, 5.0, 0.1) var anger_movement_multiplier: float = 1.5
@export var anger_color: Color = Color(1.0, 0.35, 0.35, 1.0)

var home_position: Vector3
var anger_remaining: float = 0.0
var _refresh_detector_frames: int = 0
var _normal_modulate: Color = Color.WHITE
var _ignored_player: Node3D
var _ignore_verify_frames: int = 0


func _ready() -> void:
	var patrol := get_node_or_null("States/Patrol") as EnemyPatrol
	if patrol != null:
		patrol.use_contact_damage = patrol_contact_damage
		patrol.speed_scale = patrol_speed_scale
	if Engine.is_editor_hint():
		return
	home_position = global_position
	_ensure_detector()
	super()
	for attack_hitbox: HitBox in [contact_hitbox, active_hitbox]:
		if is_instance_valid(attack_hitbox):
			attack_hitbox.hit_confirmed.connect(_on_player_hit_confirmed)
	if is_instance_valid(target_detector):
		target_detector.body_exited.connect(_on_ignored_player_exited)
	if is_instance_valid(visual) and is_instance_valid(visual.sprite):
		_normal_modulate = visual.sprite.modulate
	died.connect(_end_anger)


func _ensure_detector() -> void:
	var detector := get_node_or_null("TargetDetector") as Area3D
	if detector == null:
		detector = Area3D.new()
		detector.name = "TargetDetector"
		var collision := CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		var cylinder := CylinderShape3D.new()
		cylinder.height = 3.0
		collision.shape = cylinder
		collision.position.y = 1.0
		detector.add_child(collision)
		add_child(detector)
	target_detector = detector
	var collision := detector.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null and collision.shape is CylinderShape3D:
		collision.shape = collision.shape.duplicate()
	_apply_detection_radius()


func _apply_detection_radius() -> void:
	if not is_instance_valid(target_detector):
		return
	var collision := target_detector.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null and collision.shape is CylinderShape3D:
		var factor := anger_detection_multiplier if anger_remaining > 0.0 else 1.0
		(collision.shape as CylinderShape3D).radius = maxf(0.1, player_detection_radius * factor)
		_refresh_detector_frames = 2


func _physics_process(delta: float) -> void:
	if anger_remaining > 0.0:
		anger_remaining = maxf(0.0, anger_remaining - maxf(delta, 0.0))
		if anger_remaining <= 0.0:
			_end_anger()
	if _refresh_detector_frames > 0:
		_refresh_detector_frames -= 1
		if _refresh_detector_frames == 0:
			_refresh_target()
	if _ignore_verify_frames > 0:
		_ignore_verify_frames -= 1
		if _ignore_verify_frames == 0:
			_verify_ignored_player()
	super(delta)


func _process(_delta: float) -> void:
	if not is_instance_valid(visual) or not is_instance_valid(visual.sprite):
		return
	if anger_remaining > 0.0 and not dead:
		var flash := visual._hit_flash_tween
		if flash == null or not flash.is_running():
			visual.sprite.modulate = _normal_modulate * anger_color


func receive_damage(damage: DamageContext) -> float:
	var applied := super(damage)
	if (
		applied > 0.0 and not dead and damage != null
		and damage.source_team == CombatTeams.PLAYER
		and is_instance_valid(damage.source)
		and damage.source.is_in_group("player")
		and damage.delivery_type == AttackData.DeliveryType.PROJECTILE
	):
		anger_remaining = maxf(0.1, anger_duration)
		_apply_detection_radius.call_deferred()
	return applied


func _end_anger() -> void:
	anger_remaining = 0.0
	if is_instance_valid(visual) and is_instance_valid(visual.sprite):
		visual.sprite.modulate = _normal_modulate
	if not dead:
		_apply_detection_radius.call_deferred()


func effective_movement_radius() -> float:
	return movement_radius * (anger_movement_multiplier if anger_remaining > 0.0 else 1.0)


func can_chase_target() -> bool:
	if not has_target() or target == _ignored_player:
		return false
	var offset := target.global_position - home_position
	offset.y = 0.0
	return offset.length() <= effective_movement_radius()


func _is_target_candidate(candidate: Node3D) -> bool:
	return candidate != _ignored_player and super(candidate)


func _on_player_hit_confirmed(_damage: DamageContext, hit_target: Node, applied_hp: float) -> void:
	if applied_hp <= 0.0 or not hit_target is Node3D or not hit_target.is_in_group(target_group):
		return
	_ignored_player = hit_target as Node3D
	_ignore_verify_frames = 2
	set_target(null)


func _on_ignored_player_exited(body: Node3D) -> void:
	if body == _ignored_player:
		_ignored_player = null
		_ignore_verify_frames = 0


func _verify_ignored_player() -> void:
	if not is_instance_valid(_ignored_player):
		_ignored_player = null
		return
	if not is_instance_valid(target_detector) or not target_detector.monitoring:
		return
	if not target_detector.overlaps_body(_ignored_player):
		_ignored_player = null
