extends CharmEffect

var _hits: Dictionary[int, int] = {}


func on_damage_dealt(damage: DamageContext, target: Node, applied_hp: float) -> void:
	if (
		applied_hp <= 0.0
		or damage.source != actor
		or not damage.is_normal_attack()
		or not target is EnemyBase
	):
		return
	var enemy := target as EnemyBase
	var id := enemy.get_instance_id()
	if enemy.dead or enemy.is_in_group(&"boss"):
		_hits.erase(id)
		return
	if not _hits.has(id):
		var cleanup := _forget.bind(id)
		if not enemy.tree_exiting.is_connected(cleanup):
			enemy.tree_exiting.connect(cleanup, CONNECT_ONE_SHOT)
	_hits[id] = _hits.get(id, 0) + 1
	if _hits[id] < definition.get_param_int(&"hit_threshold"):
		return
	_hits[id] = 0
	enemy.apply_charm_stun(definition.get_param_float(&"stun_seconds"))
	CharmVfx.heavy_impact(actor.get_parent(), enemy.global_position, CharmVfx.GOLD)
	runtime.proc_triggered.emit("STUN", CharmVfx.GOLD)


func _forget(id: int) -> void:
	_hits.erase(id)


func cancel_active() -> void:
	_hits.clear()
