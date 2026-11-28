class_name CrescentCleaveAttack
extends Node3D
## Một lần quét vùng bán nguyệt phía trước và chỉ gây sát thương một lần mỗi mục tiêu.

signal target_hit(target: Node, applied_hp: float)
signal completed

@export var hit_area: Area3D

var context: AttackContext
var radius_units: float = 2.8
var half_angle_degrees: float = 90.0
var active_seconds: float = 0.12

var _active: bool = false
var _remaining_seconds: float = 0.0
var _hit_actor_ids: Dictionary[int, bool] = {}
var _slash: MeleeSlashVFX
var _impact_reported: bool = false


func _ready() -> void:
	set_physics_process(false)
	if is_instance_valid(hit_area):
		hit_area.area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	if not _active:
		return
	if not is_instance_valid(context) or not is_instance_valid(context.actor):
		_finish()
		return
	if bool(context.actor.get("dead")):
		_finish()
		return
	for area: Area3D in hit_area.get_overlapping_areas():
		_try_hit(area)
	_remaining_seconds = maxf(0.0, _remaining_seconds - maxf(0.0, delta))
	if is_instance_valid(_slash):
		_slash.set_progress(1.0 - _remaining_seconds / maxf(0.01, active_seconds))
	if _remaining_seconds <= 0.0:
		completed.emit()
		_finish()


func _exit_tree() -> void:
	_active = false
	_hit_actor_ids.clear()
	if is_instance_valid(_slash):
		_slash.finish()


func validate() -> bool:
	return is_instance_valid(hit_area)


func activate() -> bool:
	if not validate() or context == null or not is_instance_valid(context.actor):
		return false
	if context.direction.is_zero_approx() or context.damage_hp <= 0:
		return false
	look_at(global_position + context.direction, Vector3.UP)
	var shape_node := hit_area.get_node_or_null("CollisionShape3D") as CollisionShape3D
	var sphere := shape_node.shape as SphereShape3D if shape_node != null else null
	if sphere == null:
		return false
	sphere.radius = radius_units
	_hit_actor_ids.clear()
	_impact_reported = false
	var step := MeleeComboStep.new()
	step.swing_start_degrees = -half_angle_degrees
	step.swing_end_degrees = half_angle_degrees
	step.slash_color = CharmVfx.GOLD
	step.slash_width = 0.85
	step.heavy_impact = true
	_slash = MeleeSlashVFX.new()
	get_parent().add_child(_slash)
	_slash.global_transform = global_transform
	# The melee renderer adds 15% reach for weapon art; the Charm shows its actual AoE.
	_slash.setup(step, radius_units / 1.15)
	_remaining_seconds = maxf(0.01, active_seconds)
	_active = true
	CharmFeel.sound(self, CharmFeel.WHOOSH_SOUND, global_position, -4.0, 0.85)
	CharmFeel.shake(self, 2.5, 0.1)
	set_physics_process(true)
	return true


func cancel() -> void:
	_finish()


func _on_area_entered(area: Area3D) -> void:
	if _active:
		_try_hit(area)


func _try_hit(area: Area3D) -> void:
	if not area is HurtBox:
		return
	var hurtbox := area as HurtBox
	if (
		not is_instance_valid(hurtbox.actor)
		or hurtbox.actor == context.actor
		or not hurtbox.actor is Node3D
	):
		return
	var target_id := hurtbox.actor.get_instance_id()
	if _hit_actor_ids.has(target_id):
		return
	var offset := (hurtbox.actor as Node3D).global_position - global_position
	offset.y = 0.0
	if offset.length() > radius_units:
		return
	var forward := context.direction.normalized()
	var target_direction := forward if offset.is_zero_approx() else offset.normalized()
	var minimum_dot := cos(deg_to_rad(clampf(half_angle_degrees, 0.0, 180.0)))
	if forward.dot(target_direction) < minimum_dot:
		return
	_hit_actor_ids[target_id] = true
	var damage := context.create_damage_context()
	damage.charm_push = true
	damage.knockback_multiplier = 1.6
	var applied_hp := hurtbox.take_damage(damage)
	if applied_hp > 0:
		context.damage_applied.emit(damage, hurtbox.actor, applied_hp)
		target_hit.emit(hurtbox.actor, applied_hp)
		var at := (hurtbox.actor as Node3D).global_position + Vector3.UP * 0.7
		CharmVfx.spawn(get_parent(), at, CharmVfx.GOLD, 0.85)
		if not _impact_reported:
			_impact_reported = true
			get_node("/root/HitstopController").request(0.065, hurtbox.actor)
			get_node("/root/ScreenShakeController").request(6.0, 0.18)
			CharmVfx.heavy_impact(get_parent(), at, CharmVfx.GOLD)
			CharmFeel.flash(self, CharmVfx.GOLD, 0.08, 0.12)
			CharmFeel.shockwave(self, at, CharmVfx.GOLD, 130.0, 0.01, 0.35)


func _finish() -> void:
	_active = false
	if is_instance_valid(_slash):
		_slash.finish()
	set_physics_process(false)
	queue_free()
