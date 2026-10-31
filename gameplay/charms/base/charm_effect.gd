class_name CharmEffect
extends Node
## Hook contract cho hiệu ứng Active và Passive Charm.

var actor: Node3D
var definition: CharmData
var runtime: CharmRuntime


func _exit_tree() -> void:
	cancel_active()


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
