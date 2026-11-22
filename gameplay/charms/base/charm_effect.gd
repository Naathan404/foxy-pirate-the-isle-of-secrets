# gdlint: disable=max-public-methods
class_name CharmEffect
extends Node
## Hook contract cho hiệu ứng Active và Passive Charm.

var actor: Node3D
var definition: CharmData
var runtime: CharmRuntime


func _exit_tree() -> void:
	cancel_active()
	_end_cast_lock()


func setup(owner_actor: Node3D, charm_definition: CharmData, charm_runtime: CharmRuntime) -> bool:
	if not is_instance_valid(owner_actor) or charm_definition == null or charm_runtime == null:
		return false
	actor = owner_actor
	definition = charm_definition
	runtime = charm_runtime
	return true


func on_equipped() -> void:
	pass


func on_unequipped() -> void:
	cancel_active()


func cancel_active() -> void:
	pass


func on_damage_dealt(_damage: DamageContext, _target: Node, _applied_hp: float) -> void:
	pass


func on_damage_received(_damage: DamageContext, _applied_hp: float) -> void:
	pass


func on_target_defeated(_target: Node, _damage: DamageContext) -> void:
	pass


func on_actor_died() -> void:
	cancel_active()


func on_dash_started() -> void:
	pass


func on_dash_finished(_interrupted: bool) -> void:
	pass


func modify_outgoing_damage(amount_hp: float, _damage: DamageContext) -> float:
	return amount_hp


func modify_attack_damage(amount_hp: float, _attack: AttackContext) -> float:
	return amount_hp


func modify_incoming_damage(amount_hp: float, _damage: DamageContext) -> float:
	return amount_hp


func modify_stats(_stats: Dictionary[StringName, float]) -> void:
	pass


func can_activate(_context: CharmActivationContext) -> bool:
	return definition != null and definition.is_active()


func activate(_context: CharmActivationContext) -> bool:
	return false


func on_input_held(_context: CharmActivationContext, _delta: float) -> bool:
	return false


func on_input_released(_context: CharmActivationContext) -> bool:
	return false


func on_input_cancelled() -> void:
	if definition != null and definition.is_active():
		cancel_active()


func get_activation_cost(_context: CharmActivationContext) -> float:
	return definition.resource_cost if definition != null else 0.0


func get_cooldown_policy() -> StringName:
	return &"on_activate"


func _play_cast_animation(
	phase: StringName,
	direction: Vector3 = Vector3.ZERO,
	duration_seconds: float = 0.0,
	continue_only: bool = false
) -> void:
	if is_instance_valid(actor) and actor.has_method("play_charm_cast"):
		actor.call(
			"play_charm_cast",
			definition.charm_id,
			phase,
			direction,
			duration_seconds,
			continue_only
		)


func _get_base_damage() -> float:
	var controller := actor.get("weapon_controller") as WeaponController
	var base := 1.0
	if is_instance_valid(controller) and controller.equipped != null:
		var attack := controller.equipped.get_attack(&"normal")
		if attack != null:
			base = attack.damage_hp
	if actor is Player:
		var stats: Dictionary[StringName, float] = {}
		(actor as Player).charm_registry.modify_stats(stats)
		base *= stats.get(&"charm_damage_multiplier", 1.0)
	return base


func _damage_target(
	target: Node3D, amount: float, origin: Vector3, push: float = 0.0, tag: StringName = &""
) -> float:
	if not is_instance_valid(target) or not target.has_method("receive_damage"):
		return 0.0
	var damage := DamageContext.new()
	damage.source = actor
	damage.source_team = actor.get("team")
	damage.tag = definition.charm_id if tag.is_empty() else tag
	damage.amount_hp = amount
	damage.base_amount_hp = amount
	damage.origin = origin
	damage.direction = origin.direction_to(target.global_position)
	damage.charm_push = push > 0.0
	damage.knockback_multiplier = push
	return target.call("receive_damage", damage)


func _targets_in_radius(center: Vector3, radius: float) -> Array[Node3D]:
	var targets: Array[Node3D] = []
	for enemy in actor.get_tree().get_nodes_in_group(&"enemy"):
		if enemy is Node3D and enemy.global_position.distance_squared_to(center) <= radius * radius:
			targets.append(enemy)
	return targets


func _begin_cast_lock() -> bool:
	return not actor is Player or (actor as Player).begin_charm_cast(self)


func _end_cast_lock() -> void:
	if is_instance_valid(actor) and actor is Player:
		(actor as Player).end_charm_cast(self)


func _stop_cast_animation() -> void:
	_end_cast_lock()
	if is_instance_valid(actor) and actor.has_method("cancel_charm_cast"):
		actor.call("cancel_charm_cast", definition.charm_id)


func can_bypass_cooldown(_context: CharmActivationContext) -> bool:
	return false
