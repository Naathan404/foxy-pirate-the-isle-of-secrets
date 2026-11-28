@tool
class_name EliteBarrel
extends Barrel

## A burst only reaches targets standing on roughly the same ground.
const BURST_HEIGHT_METERS := 2.5
const WALL_PROBE_HEIGHT_METERS := 1.0

@export_group("Elite Normal Attack")
## Một lượt gồm nhiều đợt; mỗi đợt bắn hình quạt hướng về player.
@export_range(1, 20, 1) var normal_volley_count: int = 2
@export_range(1, 24, 1) var normal_bullets_per_volley: int = 5
@export_range(0.0, 180.0, 1.0, "suffix:deg") var normal_fan_angle: float = 50.0
@export_range(0.01, 5.0, 0.01, "suffix:s") var normal_volley_interval: float = 0.2
## Các đợt lệch nhau nửa khoảng cách giữa hai viên, đợt sau lấp khe của đợt trước.
@export var normal_stagger_volleys: bool = true

@export_group("Elite Special Attack")
@export_range(1, 20, 1) var normal_attacks_before_special: int = 5
@export_range(1, 20, 1) var special_volley_count: int = 3
@export_range(2, 32, 1) var special_bullets_per_volley: int = 12
@export_range(0.01, 5.0, 0.01, "suffix:s") var special_volley_interval: float = 0.35
## Bán kính điểm sinh cách tâm để đạn tỏa đều quanh thân Elite.
@export_range(0.1, 5.0, 0.05, "suffix:m") var special_spawn_radius: float = 1.45
## Mỗi đợt xoay thêm phần này của khoảng cách giữa hai tia: 0.5 là so le (không còn khe
## an toàn cố định), giá trị khác tạo vòng xoắn ốc; 0 bắn lại đúng các tia cũ.
@export_range(0.0, 1.0, 0.05) var special_volley_stagger: float = 0.5

@export_group("Elite Point Blank")
## Blobs leave the raised mouth too high to hit anything close, so each fan also sprays ink
## down over this reach. It must overlap the distance where the blobs come back to body height.
@export_range(0.5, 8.0, 0.05, "suffix:m") var point_blank_radius: float = 4.8
@export_range(10.0, 360.0, 1.0, "suffix:deg") var point_blank_arc_degrees: float = 110.0

@export_group("Elite Ink Slam")
## Foxy this close makes the elite slam instead of waiting for its next volley.
@export_range(0.5, 10.0, 0.05, "suffix:m") var slam_trigger_radius: float = 3.6
## Reach of the slam burst, also used by the burst that opens the 360 turn.
@export_range(0.5, 12.0, 0.05, "suffix:m") var slam_radius: float = 4.9
@export_range(0.0, 30.0, 0.1, "suffix:s") var slam_cooldown: float = 4.5
## Scales the ink push of a burst, so it throws Foxy clear of the barrel.
@export_range(0.0, 4.0, 0.05) var slam_push_multiplier: float = 2.0

@export_group("Elite Charged Feedback")
@export var charged_color: Color = Color(1.0, 0.2, 0.2, 1.0)
@export_range(1.0, 2.0, 0.01) var charged_scale: float = 1.2
@export_range(0.0, 0.5, 0.01, "suffix:m") var charged_shake: float = 0.06
@export_range(0.0, 40.0, 0.5) var charged_shake_frequency: float = 20.0

var normal_attacks_completed: int = 0
var _slam_cooldown_remaining: float = 0.0
var _charged_elapsed: float = 0.0
var _charged_base_position: Vector3 = Vector3.ZERO
var _charged_base_scale: Vector3 = Vector3.ONE
var _charged_base_modulate: Color = Color.WHITE
var _charged_feedback_active: bool = false


func _init() -> void:
	direction_mode = DirectionMode.MULTI


func _ready() -> void:
	super()
	if not Engine.is_editor_hint():
		died.connect(_clear_charged_feedback)


func _process(delta: float) -> void:
	super(delta)
	if Engine.is_editor_hint() or not _charged_feedback_active or not is_instance_valid(visual):
		return
	_charged_elapsed += maxf(delta, 0.0)
	visual.position = (
		_charged_base_position
		+ Vector3(sin(_charged_elapsed * charged_shake_frequency) * charged_shake, 0.0, 0.0)
	)
	visual.scale = _charged_base_scale * charged_scale
	visual.set_tint(_charged_base_modulate * charged_color)


func _validate_property(property: Dictionary) -> void:
	super(property)
	if (
		property.name
		in [
			"direction_mode",
			"min_bullets_per_volley",
			"max_bullets_per_volley",
			"max_bullet_angle_offset_degrees",
			"shot_interval",
			"scattershot_bullet_count",
			"scattershot_arc_degrees"
		]
	):
		property.usage &= ~PROPERTY_USAGE_EDITOR


func update_slam_cooldown(delta: float) -> void:
	_slam_cooldown_remaining = maxf(0.0, _slam_cooldown_remaining - maxf(0.0, delta))


func start_slam_cooldown() -> void:
	_slam_cooldown_remaining = slam_cooldown


## A charged elite keeps its 360 turn, which opens with a burst of its own.
func wants_to_slam() -> bool:
	if dead or data == null or special_ready() or _slam_cooldown_remaining > 0.0:
		return false
	return has_target() and _horizontal_offset(target).length() <= slam_trigger_radius


## Ink bursts all around the barrel, hurting and throwing back a Foxy inside it.
func erupt_ink() -> void:
	if dead or data == null:
		return
	EliteBarrelInkVfx.blast(_get_ink_parent(), global_position, slam_radius)
	_splash_foes(slam_radius, Vector3.ZERO, PI, slam_push_multiplier)


func point_blank_half_arc() -> float:
	return deg_to_rad(point_blank_arc_degrees) * 0.5


## Direction the next fan will leave in, flattened to the ground.
func get_spray_direction() -> Vector3:
	var aim := _get_firing_direction()
	return Vector3(aim.x, 0.0, aim.z).normalized()


func special_ready() -> bool:
	return normal_attacks_completed >= maxi(1, normal_attacks_before_special)


func complete_normal_attack() -> void:
	if special_ready() or dead:
		return
	normal_attacks_completed += 1
	if special_ready():
		_begin_charged_feedback()


func complete_special_attack() -> void:
	normal_attacks_completed = 0
	_clear_charged_feedback()


## One normal-turn fan; `volley_index` counts the fans of this turn from 0.
func fire_normal_volley(volley_index: int) -> void:
	var offset_degrees := 0.0
	if normal_stagger_volleys and normal_bullets_per_volley > 1:
		var step_degrees := normal_fan_angle / float(normal_bullets_per_volley - 1)
		# Quarter steps either side of the aim keep the fans centred while they interleave.
		offset_degrees = step_degrees * (0.25 if volley_index % 2 == 1 else -0.25)
	fire_fan_volley(normal_bullets_per_volley, normal_fan_angle, offset_degrees)
	_spray_point_blank()


## One ring of the 360° turn. The first ray of the first ring points along the current aim;
## each later ring turns by `special_volley_stagger` of the gap between rays.
func fire_radial_volley(count: int, volley_index: int = 0) -> void:
	if dead or data == null:
		return
	var bullet_count := maxi(2, count)
	var center := Vector3(global_position.x, bullet_spawn.global_position.y, global_position.z)
	var aim := _get_firing_direction()
	var turn := special_volley_stagger * volley_index
	_spit_muzzle_ink(Vector3.ZERO)
	for index in range(bullet_count):
		var direction := aim.rotated(Vector3.UP, TAU * (index + turn) / bullet_count)
		_spawn_bullet(direction, center + direction * special_spawn_radius)


func _spray_point_blank() -> void:
	if dead or data == null:
		return
	var direction := get_spray_direction()
	EliteBarrelInkVfx.cone_spray(
		_get_ink_parent(), global_position, point_blank_radius, direction, point_blank_half_arc()
	)
	_splash_foes(point_blank_radius, direction, point_blank_half_arc(), 1.0)


## Damages every opposing player within the cone that no wall shields. The player's own
## post-hit immunity keeps a blob and its spray from landing twice.
func _splash_foes(reach: float, direction: Vector3, half_arc: float, push: float) -> void:
	for node: Node in get_tree().get_nodes_in_group(target_group):
		var player := node as Player
		if player == null or player.dead:
			continue
		var offset := _horizontal_offset(player)
		if offset.length() > reach:
			continue
		if absf(player.global_position.y - global_position.y) > BURST_HEIGHT_METERS:
			continue
		if half_arc < PI and not offset.is_zero_approx():
			if direction.angle_to(offset.normalized()) > half_arc:
				continue
		if _wall_between(player.global_position):
			continue
		_ink_player(player, push)


func _ink_player(player: Player, push: float) -> void:
	var damage := DamageContext.new()
	damage.source = self
	damage.source_team = team
	damage.base_amount_hp = data.attack_damage
	damage.amount_hp = data.attack_damage
	damage.tag = &"ink_burst"
	damage.origin = global_position
	damage.direction = _horizontal_offset(player).normalized()
	damage.knockback_multiplier = (ink_hit.knockback_multiplier * push if ink_hit != null else 0.0)
	if player.receive_damage(damage) > 0.0 and ink_hit != null:
		ink_hit.apply_to(player)


func _horizontal_offset(node: Node3D) -> Vector3:
	var offset := node.global_position - global_position
	offset.y = 0.0
	return offset


func _wall_between(at: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * WALL_PROBE_HEIGHT_METERS,
		Vector3(at.x, global_position.y + WALL_PROBE_HEIGHT_METERS, at.z),
		CombatLayers.WORLD
	)
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _get_ink_parent() -> Node3D:
	var scene := _get_projectile_parent() as Node3D
	return scene if scene != null else get_parent() as Node3D


func _begin_charged_feedback() -> void:
	if _charged_feedback_active or not is_instance_valid(visual):
		return
	_charged_base_position = visual.position
	_charged_base_scale = visual.scale
	_charged_base_modulate = visual.get_tint()
	_charged_elapsed = 0.0
	_charged_feedback_active = true


func _clear_charged_feedback() -> void:
	if not _charged_feedback_active:
		return
	_charged_feedback_active = false
	if is_instance_valid(visual):
		visual.position = _charged_base_position
		visual.scale = _charged_base_scale
		visual.set_tint(_charged_base_modulate)
