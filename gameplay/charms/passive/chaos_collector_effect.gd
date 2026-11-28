class_name ChaosCollectorEffect
extends CharmEffect
## Adds a fixed amount of Chaos for every confirmed Player normal-attack hit. Each gain
## sends motes from the target to Foxy and ticks the HUD slot; filling the bar is a proc.

const COLOR := Color(1.0, 0.4, 0.24)


func setup(owner_actor: Node3D, charm_definition: CharmData, charm_runtime: CharmRuntime) -> bool:
	if not super.setup(owner_actor, charm_definition, charm_runtime):
		return false
	return (
		is_instance_valid(_get_chaos()) and definition.get_param_float(&"chaos_per_hit", 2.0) > 0.0
	)


func on_damage_dealt(damage: DamageContext, target: Node, applied_hp: float) -> void:
	if (
		damage == null
		or applied_hp <= 0.0
		or damage.source != actor
		or not damage.is_normal_attack()
	):
		return
	var chaos := _get_chaos()
	var before := chaos.current
	chaos.gain(definition.get_param_float(&"chaos_per_hit", 2.0))
	var gained := chaos.current - before
	if gained <= 0.0:
		return
	if target is Node3D and actor.is_inside_tree():
		ChaosMotesVfx.spawn(actor.get_parent(), target as Node3D, actor, COLOR)
	if chaos.is_full():
		runtime.proc_triggered.emit("CHAOS READY", COLOR)
	else:
		runtime.gain_ticked.emit(gained, "CP", COLOR)


func _get_chaos() -> ChaosComponent:
	return actor.get("chaos") as ChaosComponent if is_instance_valid(actor) else null
