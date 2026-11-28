class_name DelayedBlastCharm
extends CharmEffect
## Plants a blast that goes off after `delay_seconds` and damages every enemy within
## `radius_units` (Shadow Renment, Death Bloom). Never hurts Foxy. Planting shows the charm's
## word on its HUD slot; CharmBlastVfx shows the area, the fuse and the explosion.

var _blasts: Array[CharmBlastVfx] = []


func _plant(at: Vector3, kind: CharmBlastVfx.Kind, color: Color, word: String) -> void:
	var delay := definition.get_param_float(&"delay_seconds")
	var radius := definition.get_param_float(&"radius_units")
	var blast := CharmBlastVfx.plant(actor.get_parent(), at, kind, radius, delay, color)
	_blasts.append(blast)
	runtime.proc_triggered.emit(word, color)
	var tween := blast.create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(_detonate.bind(blast, at, kind, color))


func _detonate(
	blast: CharmBlastVfx, at: Vector3, kind: CharmBlastVfx.Kind, color: Color
) -> void:
	if not _blasts.has(blast) or not is_instance_valid(actor):
		return
	_blasts.erase(blast)
	blast.detonate()
	var amount := (
		_get_base_damage() * definition.get_param_float(&"damage_multiplier")
		if kind == CharmBlastVfx.Kind.SHADOW
		else definition.get_param_float(&"blast_hp")
	)
	var radius := definition.get_param_float(&"radius_units")
	var hit := false
	for target in _targets_in_radius(at, radius):
		if _damage_target(target, amount, at, 1.0) > 0.0:
			hit = true
	if hit:
		CharmVfx.heavy_impact(actor.get_parent(), at, color)


func cancel_active() -> void:
	for blast in _blasts:
		if is_instance_valid(blast):
			blast.queue_free()
	_blasts.clear()
