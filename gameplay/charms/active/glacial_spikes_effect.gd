extends CharmEffect
## Erupt widening ranks from a snapshot of Foxy's facing at cast time.

const SPIKE := preload("res://gameplay/charms/active/glacial_spike.tscn")
const ICE := Color("8cecff")
const RELEASE_SECONDS := 0.22
const SLAM_FLASH_RADIUS := 0.78
const SLAM_FLASH_SECONDS := 0.17
const FRACTURE_RADIUS := 1.05
const FRACTURE_SECONDS := 0.5
const FIRST_RANK_HEIGHT_SCALE := 0.76
const LAST_RANK_HEIGHT_SCALE := 1.12
var _origin := Vector3.ZERO
var _forward := Vector3.BACK
var _row := 0
var _delay := 0.0
var _damage := 0.0
var _struck: Array[Node3D] = []
var _marks: Array[CharmVfx] = []
var _impact_reported := false


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
	for row in rows:
		for site in _row_sites(row):
			var until_hit := _delay + row * definition.get_param_float(&"row_interval_seconds")
			var mark := CharmVfx.spawn(
				actor.get_parent(),
				site,
				ICE,
				definition.get_param_float(&"radius_units"),
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
		_play_cast_animation(&"release", _forward, RELEASE_SECONDS)
		CharmVfx.spawn(actor.get_parent(), _origin, ICE, SLAM_FLASH_RADIUS, SLAM_FLASH_SECONDS)
	for site in _row_sites(_row):
		_erupt(site)
		_strike(site)
		var mark: CharmVfx = _marks.pop_front()
		mark.queue_free()
	_row += 1
	_delay += definition.get_param_float(&"row_interval_seconds")
	if _marks.is_empty():
		_struck.clear()
		set_physics_process(false)


func _strike(site: Vector3) -> void:
	for target in _targets_in_radius(site, definition.get_param_float(&"radius_units")):
		if target in _struck or _damage_target(target, _damage, site, 0.4) <= 0.0:
			continue
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


func _erupt(site: Vector3) -> void:
	var spike := SPIKE.instantiate() as Node3D
	var arena := actor.get_parent() as Node3D
	# Fan the facets away from the point of contact as the ranks spread.
	var outward := arena.global_basis.inverse() * _origin.direction_to(site)
	spike.rotation.y = atan2(-outward.z, outward.x)
	var last_row := maxi(1, definition.get_param_int(&"row_count") - 1)
	spike.scale.y = lerpf(FIRST_RANK_HEIGHT_SCALE, LAST_RANK_HEIGHT_SCALE, float(_row) / last_row)
	spike.position = arena.to_local(site)
	arena.add_child(spike)
	CharmVfx.spawn(
		arena, site, ICE, FRACTURE_RADIUS, FRACTURE_SECONDS, CharmVfx.Style.FROST_FRACTURE
	)


func on_input_cancelled() -> void:
	if _row == 0:
		cancel_active()


func cancel_active() -> void:
	_stop_cast_animation()
	for mark in _marks:
		if is_instance_valid(mark):
			mark.queue_free()
	_marks.clear()
	_struck.clear()
	set_physics_process(false)
