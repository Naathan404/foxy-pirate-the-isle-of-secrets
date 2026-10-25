class_name CharmRegistry
extends Node
## Catalog, ownership và runtime lifecycle của Charm.

signal charm_registered(charm_id: StringName)
signal charm_unregistered(charm_id: StringName)
signal charm_owned(charm_id: StringName)
signal charm_ownership_removed(charm_id: StringName)
signal charm_equipped(charm_id: StringName, socket_id: int)
signal charm_unequipped(charm_id: StringName, socket_id: int)

@export var definitions: Array[CharmData] = []

var _catalog: Dictionary[StringName, CharmData] = {}
var _owned_ids: Dictionary[StringName, bool] = {}
var _equipped: Dictionary[int, CharmRuntime] = {}


func _ready() -> void:
	for definition: CharmData in definitions:
		if not register_definition(definition):
			push_error("CharmRegistry: failed to register a Charm definition")


func _physics_process(delta: float) -> void:
	advance(delta)


func register_definition(definition: CharmData) -> bool:
	if definition == null or CharmValidator.validate_data(definition).size() > 0:
		return false
	if _catalog.has(definition.charm_id):
		return false
	_catalog[definition.charm_id] = definition
	charm_registered.emit(definition.charm_id)
	return true


func unregister_definition(charm_id: StringName) -> bool:
	if not _catalog.has(charm_id) or _is_equipped(charm_id):
		return false
	_catalog.erase(charm_id)
	_owned_ids.erase(charm_id)
	charm_unregistered.emit(charm_id)
	return true


func get_definition(charm_id: StringName) -> CharmData:
	return _catalog.get(charm_id) as CharmData


func get_registered_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for charm_id: StringName in _catalog.keys():
		ids.append(charm_id)
	return ids


func validate_catalog() -> PackedStringArray:
	return CharmValidator.validate_catalog(definitions)


func set_owned(charm_id: StringName, owned: bool) -> bool:
	if not _catalog.has(charm_id):
		return false
	if owned:
		if _owned_ids.has(charm_id):
			return true
		_owned_ids[charm_id] = true
		charm_owned.emit(charm_id)
		return true
	if not _owned_ids.erase(charm_id):
		return false
	if _is_equipped(charm_id):
		unequip_charm(charm_id)
	charm_ownership_removed.emit(charm_id)
	return true


func is_owned(charm_id: StringName) -> bool:
	return _owned_ids.has(charm_id)


func get_owned_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for charm_id: StringName in _owned_ids:
		result.append(charm_id)
	result.sort()
	return result


func equip_charm(charm_id: StringName, socket_id: int, owner_actor: Node3D) -> bool:
	if not is_owned(charm_id):
		return false
	return _equip_charm_runtime(charm_id, socket_id, owner_actor)


func _debug_equip_charm(charm_id: StringName, socket_id: int, owner_actor: Node3D) -> bool:
	if not OS.is_debug_build():
		return false
	return _equip_charm_runtime(charm_id, socket_id, owner_actor)


func _equip_charm_runtime(charm_id: StringName, socket_id: int, owner_actor: Node3D) -> bool:
	if _equipped.has(socket_id):
		return false
	var definition := get_definition(charm_id)
	if definition == null or not is_instance_valid(owner_actor):
		return false
	var runtime := CharmRuntime.new()
	if not runtime.setup(definition, socket_id):
		return false
	var effect := _instantiate_effect(definition)
	if effect == null or not effect.setup(owner_actor, definition, runtime):
		if is_instance_valid(effect):
			effect.free()
		return false
	add_child(effect)
	runtime.effect = effect
	runtime.equipped = true
	_equipped[socket_id] = runtime
	effect.on_equipped()
	charm_equipped.emit(charm_id, socket_id)
	return true


func unequip_socket(socket_id: int) -> bool:
	var runtime := _equipped.get(socket_id) as CharmRuntime
	if runtime == null:
		return false
	if is_instance_valid(runtime.effect):
		runtime.effect.on_unequipped()
		runtime.effect.queue_free()
	runtime.equipped = false
	_equipped.erase(socket_id)
	charm_unequipped.emit(runtime.definition.charm_id, socket_id)
	return true


func unequip_charm(charm_id: StringName) -> bool:
	for socket_id: int in _equipped.keys():
		var runtime := _equipped[socket_id] as CharmRuntime
		if (
			runtime != null
			and runtime.definition != null
			and runtime.definition.charm_id == charm_id
		):
			return unequip_socket(socket_id)
	return false


func get_equipped(socket_id: int) -> CharmRuntime:
	return _equipped.get(socket_id) as CharmRuntime


func activate_socket(socket_id: int, context: CharmActivationContext) -> bool:
	var runtime := get_equipped(socket_id)
	if runtime == null or context == null or not runtime.can_activate():
		return false
	if not runtime.effect.can_activate(context):
		return false
	if (
		runtime.definition.resource_cost > 0.0
		and not _can_consume_resource(context.actor, runtime.definition.resource_cost)
	):
		return false
	if not runtime.effect.activate(context):
		return false
	if (
		runtime.definition.resource_cost > 0.0
		and not _consume_resource(context.actor, runtime.definition.resource_cost)
	):
		runtime.effect.cancel_active()
		return false
	runtime.start_cooldown()
	return true


func advance(delta: float) -> void:
	for runtime: CharmRuntime in _get_equipped_runtime_snapshot():
		if _is_runtime_still_equipped(runtime):
			runtime.advance(delta)


func modify_outgoing_damage(amount_hp: int, damage: DamageContext) -> int:
	var modified_amount := amount_hp
	# Forge/attack-level modifiers đã được chốt trước; per-hit Charm stack theo Q -> Space -> E.
	for runtime: CharmRuntime in _get_equipped_runtime_snapshot():
		if _is_runtime_still_equipped(runtime):
			modified_amount = runtime.effect.modify_outgoing_damage(modified_amount, damage)
	return maxi(0, modified_amount)


func modify_attack_damage(amount_hp: int, attack: AttackContext) -> int:
	var modified_amount := amount_hp
	for runtime: CharmRuntime in _get_equipped_runtime_snapshot():
		if _is_runtime_still_equipped(runtime):
			modified_amount = runtime.effect.modify_attack_damage(modified_amount, attack)
	return maxi(0, modified_amount)


func modify_incoming_damage(amount_hp: int, damage: DamageContext) -> int:
	var modified_amount := amount_hp
	for runtime: CharmRuntime in _get_equipped_runtime_snapshot():
		if _is_runtime_still_equipped(runtime):
			modified_amount = runtime.effect.modify_incoming_damage(modified_amount, damage)
	return maxi(0, modified_amount)


func modify_stats(stats: Dictionary[StringName, float]) -> void:
	for runtime: CharmRuntime in _get_equipped_runtime_snapshot():
		if _is_runtime_still_equipped(runtime):
			runtime.effect.modify_stats(stats)


func dispatch_event(event_name: StringName, payload: Array) -> void:
	# Snapshot theo thứ tự socket; callback có thể unequip Charm khác giữa event.
	for runtime: CharmRuntime in _get_equipped_runtime_snapshot():
		if not _is_runtime_still_equipped(runtime):
			continue
		match event_name:
			&"damage_dealt":
				if payload.size() >= 3:
					runtime.effect.on_damage_dealt(payload[0], payload[1], payload[2])
			&"damage_received":
				if payload.size() >= 2:
					runtime.effect.on_damage_received(payload[0], payload[1])
			&"target_defeated":
				if payload.size() >= 2:
					runtime.effect.on_target_defeated(payload[0], payload[1])
			&"dash_started":
				runtime.effect.on_dash_started()
			&"dash_finished":
				if payload.size() >= 1:
					runtime.effect.on_dash_finished(payload[0])


func reset_active_cooldowns() -> void:
	for runtime: CharmRuntime in _get_equipped_runtime_snapshot():
		if (
			_is_runtime_still_equipped(runtime)
			and runtime.definition != null
			and runtime.definition.is_active()
		):
			runtime.reset_cooldown()


func _can_consume_resource(actor: Node3D, amount: float) -> bool:
	if not is_instance_valid(actor) or amount <= 0.0:
		return true
	var stamina := actor.get("stamina") as StaminaComponent
	return is_instance_valid(stamina) and stamina.can_consume(amount)


func _consume_resource(actor: Node3D, amount: float) -> bool:
	if not is_instance_valid(actor) or amount <= 0.0:
		return true
	var stamina := actor.get("stamina") as StaminaComponent
	return is_instance_valid(stamina) and stamina.try_consume(amount)


func _instantiate_effect(definition: CharmData) -> CharmEffect:
	if definition.effect_scene == null:
		return CharmEffect.new()
	var node := definition.effect_scene.instantiate()
	var effect := node as CharmEffect
	if effect == null:
		node.free()
		return null
	return effect


func _is_equipped(charm_id: StringName) -> bool:
	for runtime: CharmRuntime in _equipped.values():
		if (
			runtime != null
			and runtime.definition != null
			and runtime.definition.charm_id == charm_id
		):
			return true
	return false


func _get_equipped_runtime_snapshot() -> Array[CharmRuntime]:
	var result: Array[CharmRuntime] = []
	var socket_ids: Array = _equipped.keys()
	socket_ids.sort()
	for socket_id: int in socket_ids:
		var runtime := _equipped.get(socket_id) as CharmRuntime
		if runtime != null:
			result.append(runtime)
	return result


func _is_runtime_still_equipped(runtime: CharmRuntime) -> bool:
	return (
		runtime != null
		and runtime.equipped
		and _equipped.get(runtime.socket_id) == runtime
		and is_instance_valid(runtime.effect)
	)
