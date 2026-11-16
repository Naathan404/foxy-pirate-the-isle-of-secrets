class_name EliteCoralSkeleton
extends CoralSkeleton

const MORTAR_SCRIPT := preload("res://gameplay/enemies/coral_skeleton/coral_poison_mortar.gd")

@export_group("Elite Revive")
@export_range(1, 5, 1) var total_lives: int = 3
@export var life_hp_ratios: Array[float] = [1.0, 0.8, 0.6]

@export_group("Elite Normal Attack")
@export_range(1, 20, 1) var normal_attacks_before_special: int = 3

@export_group("Elite Special Mortar Attack")
@export_range(1, 12, 1) var mortar_shot_count: int = 5
@export_range(0.2, 4.0, 0.05, "suffix:s") var mortar_flight_duration: float = 1.1
@export_range(1.0, 10.0, 0.1, "suffix:m") var mortar_arc_height: float = 4.5
@export_range(1.0, 8.0, 0.1, "suffix:m") var mortar_min_distance: float = 3.0
@export_range(2.0, 14.0, 0.1, "suffix:m") var mortar_max_distance: float = 6.5
@export_range(0.5, 5.0, 0.1, "suffix:m") var poison_cloud_radius: float = 1.8
@export_range(0.5, 10.0, 0.1, "suffix:s") var poison_cloud_duration: float = 3.5
@export_range(0.1, 3.0, 0.05, "suffix:s") var poison_tick_interval: float = 0.9
@export_range(0.1, 5.0, 0.1) var poison_tick_damage: float = 0.5

@export_group("Elite Charged Feedback")
@export var charged_color: Color = Color(1.0, 0.25, 0.25, 1.0)
@export_range(1.0, 2.0, 0.01) var charged_scale: float = 1.18
@export_range(0.0, 0.5, 0.01, "suffix:m") var charged_shake: float = 0.05
@export_range(0.0, 40.0, 0.5) var charged_shake_frequency: float = 32.0

var normal_attacks_completed: int = 0
var current_life: int = 1
var reviving: bool = false
var _revive_pending: bool = false
var _base_life_max_hp: float = 0.0

var _charged_elapsed: float = 0.0
var _charged_base_position: Vector3 = Vector3.ZERO
var _charged_base_scale: Vector3 = Vector3.ONE
var _charged_base_modulate: Color = Color.WHITE
var _charged_feedback_active: bool = false


func _init() -> void:
	can_sleep = false
	roam_when_guarding = true
	randomize_shot_mode = true


func _ready() -> void:
	super()
	current_life = 1
	if is_instance_valid(hp):
		_base_life_max_hp = hp.get_max_hp()
		var initial_max := get_life_max_hp(current_life)
		hp.set_max_hp_modifier(&"elite_life", initial_max - _base_life_max_hp)
		hp.set_current_hp(initial_max)
	died.connect(_clear_charged_feedback)


func can_revive() -> bool:
	return not dead and current_life < maxi(1, total_lives)


func get_life_max_hp(life_number: int) -> float:
	if _base_life_max_hp <= 0.0:
		return 0.0
	var index := maxi(0, life_number - 1)
	var ratio := 1.0
	if not life_hp_ratios.is_empty():
		ratio = clampf(life_hp_ratios[mini(index, life_hp_ratios.size() - 1)], 0.05, 1.0)
	return maxf(1.0, _base_life_max_hp * ratio)


func _process(delta: float) -> void:
	if (
		not _charged_feedback_active
		or reviving
		or dead
		or not is_instance_valid(visual)
	):
		return
	_charged_elapsed += maxf(delta, 0.0)
	visual.position = _charged_base_position + Vector3(
		sin(_charged_elapsed * charged_shake_frequency) * charged_shake, 0.0, 0.0
	)
	visual.scale = _charged_base_scale * charged_scale
	if is_instance_valid(visual.sprite):
		visual.sprite.modulate = _charged_base_modulate * charged_color


func _physics_process(delta: float) -> void:
	super(delta)
	if dead:
		_revive_pending = false
		return
	if not _revive_pending or not is_instance_valid(fsm):
		return
	if (
		(is_instance_valid(fsm.current_state) and fsm.current_state.name == &"Hit")
		or (is_instance_valid(fsm.next_state) and fsm.next_state.name == &"Hit")
	):
		return
	if request_state(&"revive", 80):
		_revive_pending = false


func receive_damage(damage: DamageContext) -> float:
	if reviving or _revive_pending:
		return 0.0
	var effective_damage := damage
	if (
		can_revive()
		and is_instance_valid(hp)
		and hp.is_alive()
		and damage != null
		and damage.amount_hp > 0.0
		and damage.source != self
		and damage.source_team != team
		and hp.current_hp - damage.amount_hp <= 0.0
	):
		_revive_pending = true
		if hp.current_hp > 1.0:
			effective_damage = _clone_damage_with_amount(damage, hp.current_hp - 1.0)
		else:
			return 0.0
	return super(effective_damage)


func set_reviving(value: bool) -> void:
	reviving = value
	if is_instance_valid(hurtbox):
		hurtbox.enabled = not value
		hurtbox.monitorable = not value
	if value:
		_clear_charged_feedback()


func complete_revive() -> void:
	if can_revive():
		current_life += 1
	if is_instance_valid(hp) and hp.is_alive():
		var next_max := get_life_max_hp(current_life)
		hp.set_max_hp_modifier(&"elite_life", next_max - _base_life_max_hp)
		hp.set_current_hp(next_max)
	set_reviving(false)
	if is_special_attack_ready():
		_begin_charged_feedback()


func is_special_attack_ready() -> bool:
	return normal_attacks_completed >= maxi(1, normal_attacks_before_special)


func notify_normal_burst_completed() -> void:
	if is_special_attack_ready() or dead:
		return
	normal_attacks_completed += 1
	if is_special_attack_ready():
		_begin_charged_feedback()


func notify_special_burst_completed() -> void:
	normal_attacks_completed = 0
	_clear_charged_feedback()


func fire_special_attack() -> void:
	if dead or not has_target() or data == null:
		return
	face_target()
	var parent := get_tree().current_scene
	if not is_instance_valid(parent):
		parent = get_parent()
	if not is_instance_valid(parent):
		return
	var count := maxi(1, mortar_shot_count)
	var to_target := target.global_position - global_position
	to_target.y = 0.0
	var base_dir := (
		to_target.normalized() if not to_target.is_zero_approx() else last_facing_direction
	)
	base_dir.y = 0.0
	if base_dir.is_zero_approx():
		base_dir = Vector3.FORWARD
	base_dir = base_dir.normalized()
	var launch_distance := clampf(to_target.length(), mortar_min_distance, mortar_max_distance)
	for index in count:
		var angle := TAU * float(index) / float(count)
		var shot_dir := base_dir.rotated(Vector3.UP, angle)
		var aim_ground := global_position + shot_dir * launch_distance
		if index == 0 and to_target.length() <= mortar_max_distance:
			aim_ground = target.global_position
		var landing := _find_mortar_ground(aim_ground)
		var mortar := MORTAR_SCRIPT.new() as CoralPoisonMortar
		mortar.setup(
			self,
			team,
			muzzle.global_position,
			landing,
			mortar_flight_duration,
			mortar_arc_height,
			data.attack_damage
		)
		mortar.configure_poison(
			poison_cloud_radius,
			poison_cloud_duration,
			poison_tick_interval,
			poison_tick_damage
		)
		parent.add_child(mortar)
	_show_muzzle_effect()


func _find_mortar_ground(around: Vector3) -> Vector3:
	if not is_inside_tree():
		return Vector3(around.x, global_position.y, around.z)
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(around.x, around.y + 6.0, around.z),
		Vector3(around.x, around.y - 12.0, around.z),
		CombatLayers.WORLD
	)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		return hit.position
	return Vector3(around.x, global_position.y, around.z)


func _clone_damage_with_amount(source_damage: DamageContext, next_amount: float) -> DamageContext:
	var copy := DamageContext.new()
	copy.source = source_damage.source
	copy.source_team = source_damage.source_team
	copy.base_amount_hp = next_amount
	copy.amount_hp = next_amount
	copy.stagger_damage = source_damage.stagger_damage
	copy.is_critical = source_damage.is_critical
	copy.tag = source_damage.tag
	copy.direction = source_damage.direction
	copy.knockback_multiplier = source_damage.knockback_multiplier
	return copy


func _begin_charged_feedback() -> void:
	if _charged_feedback_active or reviving or not is_instance_valid(visual):
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
