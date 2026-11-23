class_name DelayedBlastCharm
extends CharmEffect

var _markers: Array[CharmVfx] = []


func _plant(at: Vector3, color: Color, shadow: bool) -> void:
	var delay := definition.get_param_float(&"delay_seconds")
	var radius := definition.get_param_float(&"radius_units")
	var marker := CharmVfx.spawn(
		actor.get_parent(), at, color, radius, delay, CharmVfx.Style.TARGET
	)
	marker.sustained = true
	_markers.append(marker)
	if shadow:
		var ghost := Sprite3D.new()
		ghost.texture = preload("res://assets/sprites/foxy/charm_casts/shadow_lunge.png")
		ghost.hframes = 4
		ghost.vframes = 2
		ghost.frame = 0
		ghost.pixel_size = 0.009 / radius
		ghost.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		ghost.modulate = Color(0.55, 0.32, 0.95, 0.75)
		marker.add_child(ghost)
		ghost.position.y = 0.8 / radius
	var tween := marker.create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(_detonate.bind(marker, at, color, shadow))


func _detonate(marker: CharmVfx, at: Vector3, color: Color, shadow: bool) -> void:
	if not _markers.has(marker) or not is_instance_valid(actor):
		return
	_markers.erase(marker)
	marker.queue_free()
	var amount := (
		_get_base_damage() * definition.get_param_float(&"damage_multiplier")
		if shadow
		else definition.get_param_float(&"blast_hp")
	)
	var radius := definition.get_param_float(&"radius_units")
	var hit := false
	for target in _targets_in_radius(at, radius):
		if _damage_target(target, amount, at, 1.0) > 0.0:
			hit = true
	if not shadow and actor.global_position.distance_to(at) <= radius:
		var damage := DamageContext.new()
		damage.origin = at
		damage.source = marker
		damage.tag = definition.charm_id
		damage.base_amount_hp = amount
		damage.amount_hp = amount
		hit = float(actor.call("receive_damage", damage)) > 0.0 or hit
	CharmVfx.spawn(actor.get_parent(), at, color, radius)
	if hit:
		CharmVfx.heavy_impact(actor.get_parent(), at, color)


func cancel_active() -> void:
	for marker in _markers:
		if is_instance_valid(marker):
			marker.queue_free()
	_markers.clear()
