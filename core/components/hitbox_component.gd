class_name HitBox
extends Area3D

signal damage_applied(damage: DamageContext, target: Node, applied_hp: float)
signal damage_prepared(damage: DamageContext, target: Node)
signal hit_confirmed(damage: DamageContext, target: Node, applied_hp: float)

enum RehitPolicy {
	ONCE_PER_ATTACK,
	ONCE_PER_CONTACT,
}

@export var actor: Node
@export_enum("None:0", "Player:1", "Enemy:2") var team: int = CombatTeams.NONE

var _active: bool = false
var _damage: DamageContext
var _hit_actors: Dictionary = {}
var _hit_crates: Dictionary[int, bool] = {}
var _contact_areas_by_actor: Dictionary = {}
var _rehit_policy: RehitPolicy = RehitPolicy.ONCE_PER_ATTACK


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	set_physics_process(false)


func _physics_process(_delta: float) -> void:
	for area in get_overlapping_areas():
		_on_area_entered(area)


func begin_attack(
	amount_hp: float,
	attack_id: int = 0,
	tag: StringName = &"normal",
	rehit_policy: RehitPolicy = RehitPolicy.ONCE_PER_ATTACK
) -> bool:
	var damage := DamageContext.new()
	damage.source = actor
	damage.source_team = team
	damage.base_amount_hp = amount_hp
	damage.amount_hp = amount_hp
	damage.attack_id = attack_id
	damage.tag = tag
	return begin_attack_with_context(damage, rehit_policy)


func begin_attack_with_context(
	damage: DamageContext, rehit_policy: RehitPolicy = RehitPolicy.ONCE_PER_ATTACK
) -> bool:
	end_attack()
	if damage == null or not is_instance_valid(damage.source) or damage.amount_hp <= 0:
		return false
	actor = damage.source
	team = damage.source_team
	_damage = damage
	_rehit_policy = rehit_policy
	_active = true
	set_physics_process(true)
	return true


func end_attack() -> void:
	_active = false
	_damage = null
	_hit_actors.clear()
	_hit_crates.clear()
	_contact_areas_by_actor.clear()
	_rehit_policy = RehitPolicy.ONCE_PER_ATTACK
	set_physics_process(false)


func is_active() -> bool:
	return _active


## Immediate sample for swept melee, sharing the same per-swing target reservation.
func sample_shape() -> void:
	if not _active or not is_inside_tree():
		return
	for child in get_children():
		var collider := child as CollisionShape3D
		if collider == null or collider.disabled or collider.shape == null:
			continue
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = collider.shape
		query.transform = collider.global_transform
		query.collision_mask = collision_mask
		query.collide_with_areas = true
		query.collide_with_bodies = false
		for result in get_world_3d().direct_space_state.intersect_shape(query, 64):
			_on_area_entered(result.collider as Area3D)
			if not _active:
				return
		if _damage.crate_knockback_distance > 0.0:
			_sample_crates(collider)


func _sample_crates(collider: CollisionShape3D) -> void:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	query.transform = collider.global_transform
	query.collision_mask = CombatLayers.WORLD
	query.collide_with_areas = false
	query.collide_with_bodies = true
	for result in get_world_3d().direct_space_state.intersect_shape(query, 64):
		var crate := result.collider as PushableCrate
		if crate == null or _hit_crates.has(crate.get_instance_id()):
			continue
		if not _can_reach_crate(crate):
			continue
		var distance := _damage.crate_knockback_distance * maxf(
			0.0, _damage.knockback_multiplier
		)
		if crate.request_knockback(_damage.direction, distance):
			_hit_crates[crate.get_instance_id()] = true
			crate.play_weapon_impact_feedback(_damage.direction)


func _can_reach_crate(crate: PushableCrate) -> bool:
	if not _damage.source is Node3D:
		return false
	var origin: Vector3 = (_damage.source as Node3D).global_position + Vector3.UP * 0.75
	var destination: Vector3 = crate.global_position + Vector3.UP * 0.75
	var ray := PhysicsRayQueryParameters3D.create(origin, destination, CombatLayers.WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	return not hit.is_empty() and hit.collider == crate


func _on_area_entered(area: Area3D) -> void:
	try_hit(area as HurtBox)


## Swept projectiles can submit a sampled target through the same deduplication policy.
func try_hit(hurtbox: HurtBox) -> void:
	if not _active or not is_instance_valid(hurtbox):
		return
	if not is_instance_valid(hurtbox.actor):
		return
	var target_id := hurtbox.actor.get_instance_id()
	if _rehit_policy == RehitPolicy.ONCE_PER_CONTACT:
		_register_contact_area(target_id, hurtbox.get_instance_id())
	if _hit_actors.has(target_id):
		return
	# Reserve before dispatch because damage callbacks can cancel the attack.
	_hit_actors[target_id] = true

	var target = hurtbox.actor
	# Each target needs its own snapshot for charm modifiers and proc results.
	var damage := _damage.create_hit_copy(target)
	damage_prepared.emit(damage, target)
	if not _active or not is_instance_valid(target):
		return
	var applied_hp = hurtbox.take_damage(damage)
	if applied_hp <= 0:
		_hit_actors.erase(target_id)
		return

	damage_applied.emit(damage, target, applied_hp)
	hit_confirmed.emit(damage, target, applied_hp)


func _on_area_exited(area: Area3D) -> void:
	if not _active or _rehit_policy != RehitPolicy.ONCE_PER_CONTACT or not area is HurtBox:
		return
	var hurtbox := area as HurtBox
	if not is_instance_valid(hurtbox.actor):
		return
	var target_id := hurtbox.actor.get_instance_id()
	if not _contact_areas_by_actor.has(target_id):
		return
	var overlapping_areas: Dictionary = _contact_areas_by_actor[target_id]
	overlapping_areas.erase(hurtbox.get_instance_id())
	if not overlapping_areas.is_empty():
		return
	_contact_areas_by_actor.erase(target_id)
	_hit_actors.erase(target_id)


func _register_contact_area(target_id: int, area_id: int) -> void:
	var overlapping_areas: Dictionary = {}
	if _contact_areas_by_actor.has(target_id):
		overlapping_areas = _contact_areas_by_actor[target_id]
	else:
		overlapping_areas = {}
		_contact_areas_by_actor[target_id] = overlapping_areas
	overlapping_areas[area_id] = true
