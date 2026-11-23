extends CharmEffect

const BLOOD := Color("c82d51")
var _ticks_left: Dictionary[int, int] = {}
var _until_tick: Dictionary[int, float] = {}


func on_damage_dealt(damage: DamageContext, target: Node, applied_hp: float) -> void:
	if (
		applied_hp <= 0.0
		or damage.source != actor
		or not damage.is_normal_attack()
		or not target is Node3D
		or damage.target_defeated
	):
		return
	var id := target.get_instance_id()
	_ticks_left[id] = definition.get_param_int(&"tick_count")
	if not _until_tick.has(id):
		_until_tick[id] = definition.get_param_float(&"tick_seconds")
		runtime.proc_triggered.emit("BLEED", BLOOD)
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	for id: int in _ticks_left.keys():
		var target := instance_from_id(id) as Node3D if is_instance_id_valid(id) else null
		if is_instance_valid(target) and target.get("dead") != true:
			_until_tick[id] -= delta
			if _until_tick[id] > 0.00001:
				continue
			_until_tick[id] += definition.get_param_float(&"tick_seconds")
			var applied := _damage_target(
				target,
				definition.get_param_float(&"tick_hp"),
				target.global_position,
				0.0,
				&"bleed"
			)
			if applied > 0.0:
				CharmVfx.spawn(actor.get_parent(), target.global_position, BLOOD, 0.4, 0.16)
			_ticks_left[id] -= 1
			if _ticks_left[id] > 0:
				continue
		_ticks_left.erase(id)
		_until_tick.erase(id)
	set_physics_process(not _ticks_left.is_empty())


func cancel_active() -> void:
	_ticks_left.clear()
	_until_tick.clear()
	set_physics_process(false)
