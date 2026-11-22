extends CharmEffect
## Erupt widening ranks from a snapshot of Foxy's facing at cast time.

const SPIKE := preload("res://gameplay/charms/active/glacial_spike.tscn")
const ICE := Color("8cecff")
const SLAM_FLASH_RADIUS := 0.78
const SLAM_FLASH_SECONDS := 0.17
const FRACTURE_RADIUS := 1.05
const FRACTURE_SECONDS := 0.5
const FIRST_RANK_HEIGHT_SCALE := 0.76
const LAST_RANK_HEIGHT_SCALE := 1.12
const CROWN_HEIGHT_UNITS := 2.16  # Height of the fully raised Crown in glacial_spike.tscn.
const HURTBOX_QUERY_BATCH_SIZE := 32
var _hit_volume := CylinderShape3D.new()
var _hit_query := PhysicsShapeQueryParameters3D.new()
var _origin := Vector3.ZERO
var _forward := Vector3.BACK
var _row := 0
var _delay := 0.0
var _damage := 0.0
var _struck: Array[Node3D] = []
var _marks: Array[CharmVfx] = []
var _impact_reported := false
var _last_rising_spike: GlacialSpike


func activate(context: CharmActivationContext) -> bool:
	var rows := definition.get_param_int(&"row_count")
	if rows < 1 or not _marks.is_empty() or not context.is_valid() or not _begin_cast_lock():
		return false
	_forward = (actor as Player).last_facing_direction if actor is Player else context.direction
	_forward.y = 0.0
	_forward = Vector3.BACK if _forward.is_zero_approx() else _forward.normalized()
	_origin = actor.global_position
	_row = 0
	_delay = definition.get_param_float(&"windup_seconds")
	_damage = _get_base_damage() * definition.get_param_float(&"damage_multiplier")
	_struck.clear()
	_impact_reported = false
	_last_rising_spike = null
	_hit_volume.radius = definition.get_param_float(&"radius_units")
	_hit_query.shape = _hit_volume
	_hit_query.collision_mask = CombatLayers.ENEMY_HURTBOX
	_hit_query.collide_with_areas = true
	_hit_query.collide_with_bodies = false
	for row in rows:
		for site in _row_sites(row):
			var until_hit := _delay + row * definition.get_param_float(&"row_interval_seconds")
			var mark := CharmVfx.spawn(
				actor.get_parent(),
				site,
				ICE,
				_hit_volume.radius,
				until_hit,
				CharmVfx.Style.FROST_PRIMER
			)
			mark.sustained = true
			_marks.append(mark)
	_play_cast_animation(&"windup", _forward, _delay)
	set_physics_process(true)
	return true


func _row_sites(row: int) -> Array[Vector3]:
	var sites: Array[Vector3] = []
	var depth := (
		definition.get_param_float(&"first_row_distance")
		+ row * definition.get_param_float(&"row_spacing")
	)
	var center := _origin + _forward * depth
	var side := _forward.cross(Vector3.UP)
	for column in row + 1:
		var offset := (column - row * 0.5) * definition.get_param_float(&"column_spacing")
		sites.append(center + side * offset)
	return sites


func _physics_process(delta: float) -> void:
	if _marks.is_empty():
		set_physics_process(false)
		return
	_delay -= delta
	if _delay > 0.0:
		return
	if _row == 0:
		_end_cast_lock()
		_play_cast_animation(&"slam", _forward, GlacialSpike.RISE_SECONDS, true)
		CharmVfx.spawn(actor.get_parent(), _origin, ICE, SLAM_FLASH_RADIUS, SLAM_FLASH_SECONDS)
	var last_row := maxi(1, definition.get_param_int(&"row_count") - 1)
	var height_scale := lerpf(
		FIRST_RANK_HEIGHT_SCALE, LAST_RANK_HEIGHT_SCALE, float(_row) / last_row
	)
	_hit_volume.height = CROWN_HEIGHT_UNITS * height_scale
	for site in _row_sites(_row):
		var spike := _erupt(site, height_scale)
		_strike(site)
		var mark: CharmVfx = _marks.pop_front()
		mark.queue_free()
		if _marks.is_empty():
			_last_rising_spike = spike
			spike.raised.connect(_on_final_rank_raised.bind(spike), CONNECT_ONE_SHOT)
	_row += 1
	_delay += definition.get_param_float(&"row_interval_seconds")
	if _marks.is_empty():
		_struck.clear()
		set_physics_process(false)


func _strike(site: Vector3) -> void:
	_hit_query.transform = Transform3D(
		Basis.IDENTITY, site + Vector3.UP * (_hit_volume.height * 0.5)
	)
	var space := actor.get_world_3d().direct_space_state
	var sampled: Array[RID] = []
	while true:
		_hit_query.exclude = sampled
		var hits := space.intersect_shape(_hit_query, HURTBOX_QUERY_BATCH_SIZE)
		for hit in hits:
			sampled.append(hit.rid)
			_hit_hurtbox(hit.collider as HurtBox, site)
		if hits.size() < HURTBOX_QUERY_BATCH_SIZE:
			break


func _hit_hurtbox(hurtbox: HurtBox, site: Vector3) -> void:
	if not is_instance_valid(hurtbox) or not hurtbox.enabled or hurtbox.team == actor.get("team"):
		return
	var target := hurtbox.actor as Node3D
	if not is_instance_valid(target) or target == actor or target in _struck:
		return
	if not target.is_in_group(&"enemy") and not target.is_in_group(&"training_dummy"):
		return
	if _damage_target(target, _damage, site, 0.4) <= 0.0:
		return
	_struck.append(target)
	if target is EnemyBase:
		(target as EnemyBase).apply_charm_stun(definition.get_param_float(&"stun_seconds"))
	get_node("/root/HitstopController").request_local(null, target, 0.04)
	if not _impact_reported:
		_impact_reported = true
		get_node("/root/ScreenShakeController").request(5.0, 0.16)
		get_node("/root/AudioManager").play_sfx_3d(
			preload("res://assets/audio/combat/bow_impact.wav"), target.global_position, -6.0
		)


func _erupt(site: Vector3, height_scale: float) -> GlacialSpike:
	var spike := SPIKE.instantiate() as GlacialSpike
	var arena := actor.get_parent() as Node3D
	# Fan the facets away from the point of contact as the ranks spread.
	var outward := arena.global_basis.inverse() * _origin.direction_to(site)
	spike.rotation.y = atan2(-outward.z, outward.x)
	spike.scale.y = height_scale
	spike.position = arena.to_local(site)
	arena.add_child(spike)
	CharmVfx.spawn(
		arena, site, ICE, FRACTURE_RADIUS, FRACTURE_SECONDS, CharmVfx.Style.FROST_FRACTURE
	)
	return spike


func _on_final_rank_raised(spike: GlacialSpike) -> void:
	if spike == _last_rising_spike:
		_last_rising_spike = null
		_play_cast_animation(&"recover", _forward, 0.0, true)


func on_input_cancelled() -> void:
	if _row == 0:
		cancel_active()


func cancel_active() -> void:
	_last_rising_spike = null
	_stop_cast_animation()
	for mark in _marks:
		if is_instance_valid(mark):
			mark.queue_free()
	_marks.clear()
	_struck.clear()
	set_physics_process(false)
