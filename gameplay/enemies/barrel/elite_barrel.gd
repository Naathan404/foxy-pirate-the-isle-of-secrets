@tool
class_name EliteBarrel
extends Barrel

@export_group("Elite Normal Attack")
## Một lượt gồm nhiều đợt; mỗi đợt bắn hình quạt hướng về player.
@export_range(1, 20, 1) var normal_volley_count: int = 2
@export_range(1, 24, 1) var normal_bullets_per_volley: int = 5
@export_range(0.0, 180.0, 1.0, "suffix:deg") var normal_fan_angle: float = 50.0
@export_range(0.01, 5.0, 0.01, "suffix:s") var normal_volley_interval: float = 0.2

@export_group("Elite Special Attack")
@export_range(1, 20, 1) var normal_attacks_before_special: int = 5
@export_range(1, 20, 1) var special_volley_count: int = 3
@export_range(2, 32, 1) var special_bullets_per_volley: int = 12
@export_range(0.01, 5.0, 0.01, "suffix:s") var special_volley_interval: float = 0.35
## Bán kính điểm sinh cách tâm để đạn tỏa đều quanh thân Elite.
@export_range(0.1, 5.0, 0.05, "suffix:m") var special_spawn_radius: float = 1.45

@export_group("Elite Charged Feedback")
@export var charged_color: Color = Color(1.0, 0.2, 0.2, 1.0)
@export_range(1.0, 2.0, 0.01) var charged_scale: float = 1.2
@export_range(0.0, 0.5, 0.01, "suffix:m") var charged_shake: float = 0.06
@export_range(0.0, 40.0, 0.5) var charged_shake_frequency: float = 20.0

var normal_attacks_completed: int = 0
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
	visual.position = _charged_base_position + Vector3(
		sin(_charged_elapsed * charged_shake_frequency) * charged_shake, 0.0, 0.0
	)
	visual.scale = _charged_base_scale * charged_scale
	if is_instance_valid(visual.sprite):
		visual.sprite.modulate = _charged_base_modulate * charged_color


func _validate_property(property: Dictionary) -> void:
	super(property)
	if property.name in [
		"direction_mode", "min_bullets_per_volley", "max_bullets_per_volley",
		"max_bullet_angle_offset_degrees", "shot_interval",
		"scattershot_bullet_count", "scattershot_arc_degrees"
	]:
		property.usage &= ~PROPERTY_USAGE_EDITOR


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


func fire_radial_volley(count: int) -> void:
	if dead or data == null:
		return
	var bullet_count := maxi(2, count)
	var center := Vector3(global_position.x, bullet_spawn.global_position.y, global_position.z)
	for index in range(bullet_count):
		var direction := Vector3.FORWARD.rotated(Vector3.UP, TAU * float(index) / bullet_count)
		_spawn_bullet(direction, center + direction * special_spawn_radius)


func _begin_charged_feedback() -> void:
	if _charged_feedback_active or not is_instance_valid(visual):
		return
	_charged_base_position = visual.position
	_charged_base_scale = visual.scale
	if is_instance_valid(visual.sprite):
		_charged_base_modulate = visual.sprite.modulate
	_charged_elapsed = 0.0
	_charged_feedback_active = true


func _clear_charged_feedback() -> void:
	if not _charged_feedback_active:
		return
	_charged_feedback_active = false
	if is_instance_valid(visual):
		visual.position = _charged_base_position
		visual.scale = _charged_base_scale
		if is_instance_valid(visual.sprite):
			visual.sprite.modulate = _charged_base_modulate
