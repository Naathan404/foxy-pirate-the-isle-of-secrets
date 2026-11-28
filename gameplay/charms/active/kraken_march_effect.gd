class_name KrakenMarchEffect
extends CharmEffect
## A fissure tears toward the aim point and kraken tentacles burst from it in a fast wave. The
## wave hits and stuns each enemy once, shatters weak props and ends in a giant tentacle; the
## line then guards its ground. The effect owns damage and all summon lifetimes.

const TENTACLE := preload("res://gameplay/charms/active/kraken_tentacle.tscn")
const CRIMSON := Color("f7122f")
const WINE := Color("63041c")
const GROUND_PROBE_UP := 1.5
const GROUND_PROBE_DOWN := 2.0
const MAX_GROUND_STEP := 0.65
const MIN_GROUND_NORMAL_Y := 0.7
const PATH_SAMPLE_SPACING := 0.4
const WALL_PROBE_HEIGHT := 0.5
const QUERY_BATCH_SIZE := 32
const TARGET_HEIGHT_UNITS := 2.4
const IMPACT_SECONDS := 0.25
const SITE_COUNT_EPSILON := 0.001
## The fissure starts this far before the first tentacle and runs this far past the last one.
const FISSURE_LEAD_UNITS := 0.6
const FISSURE_TAIL_UNITS := 0.8
## Cycled along the line so neighbours never look stamped from one mould.
const HEIGHT_SCALES: Array[float] = [0.92, 1.08, 0.86, 1.16, 0.96, 1.04]
const LEANS_RADIANS: Array[float] = [-0.12, 0.1, -0.04, 0.14, -0.16, 0.06]
const CURL_SIDES: Array[float] = [1.0, 1.0, -1.0, 1.0, -1.0, -1.0, 1.0]
const FLANK_SIDE_UNITS := 0.55
const FLANK_ALONG_UNITS := 0.45
const FLANK_MIN_SCALE := 0.3
const FLANK_MAX_SCALE := 0.48
const FLANK_LEAN_RADIANS := 0.35
const ERUPTION_ROCKS := 6
const FINALE_ROCKS := 16
const SLAM_ROCKS := 4
const PROP_ROCKS := 5
const CAST_DIM_OPACITY := 0.16
const CAST_DIM_SECONDS := 0.5
const SHOCKWAVE_RADIUS_PIXELS := 260.0

var _sites: Array[Vector3] = []
var _path := PackedVector3Array()
var _fissure: KrakenFissure
var _finale: KrakenTentacle
var _wave_struck: Array[Node3D] = []
var _wave_confirmed := false
var _tentacles: Array[KrakenTentacle] = []
var _next_site := 0
var _spawn_clock := 0.0
var _direction := Vector3.BACK
var _damage := 0.0


func can_activate(context: CharmActivationContext) -> bool:
	return (
		super.can_activate(context)
		and context.is_valid()
		and context.actor == actor
		and is_instance_valid(actor.get_parent())
		and _sites.is_empty()
		and _tentacles.is_empty()
		and definition.get_param_float(&"spacing_units") > 0.0
		and definition.get_param_int(&"max_tentacles") > 0
	)


func activate(context: CharmActivationContext) -> bool:
	if not can_activate(context):
		return false
	var sites := _build_sites(context)
	if sites.is_empty() or not _begin_cast_lock():
		return false
	_sites = sites
	_direction = actor.global_position.direction_to(_sites.back())
	_direction.y = 0.0
	_direction = _direction.normalized()
	_next_site = 0
	_spawn_clock = definition.get_param_float(&"windup_seconds")
	_damage = _get_base_damage()
	_wave_struck.clear()
	_wave_confirmed = false
	_finale = null
	_fissure = KrakenFissure.spawn(actor.get_parent(), _path, _spawn_clock)
	CharmFeel.flash(actor, WINE, CAST_DIM_OPACITY, CAST_DIM_SECONDS)
	CharmFeel.shake(actor, 2.0, _spawn_clock)
	_play_cast_animation(&"windup", _direction, _spawn_clock)
	CharmFeel.sound(actor, CharmFeel.WHOOSH_SOUND, actor.global_position, -8.0, 0.65)
	set_physics_process(true)
	return true


func _build_sites(context: CharmActivationContext) -> Array[Vector3]:
	var sites: Array[Vector3] = []
	_path = PackedVector3Array()
	var origin := actor.global_position
	# Foxy's body origin is above its feet; compare terrain heights with terrain.
	var starting_ground := _ground_at(origin)
	if starting_ground.is_empty():
		return sites
	origin = starting_ground.position
	var aim := context.target_position - origin if context.has_target else context.direction
	aim.y = 0.0
	if not aim.is_finite() or aim.is_zero_approx():
		return sites
	var reach := definition.get_param_float(&"range_units")
	if context.has_target:
		reach = minf(reach, aim.length())
	var first := definition.get_param_float(&"first_distance_units")
	if reach < first:
		return sites
	var forward := aim.normalized()
	var previous := origin
	var sampled_distance := 0.0
	var count := mini(
		definition.get_param_int(&"max_tentacles"),
		(
			1
			+ floori(
				(reach - first) / definition.get_param_float(&"spacing_units") + SITE_COUNT_EPSILON
			)
		)
	)
	for index in count:
		var fraction := float(index) / (count - 1) if count > 1 else 1.0
		var distance := lerpf(first, reach, fraction)
		# Sample between summons too: a narrow gap must not be jumped by the next tentacle.
		while sampled_distance < distance:
			sampled_distance = minf(sampled_distance + PATH_SAMPLE_SPACING, distance)
			var sample := origin + forward * sampled_distance
			var ground := _ground_at(sample)
			if ground.is_empty():
				return sites
			var at: Vector3 = ground.position
			if absf(at.y - previous.y) > MAX_GROUND_STEP or _wall_between(previous, at):
				return sites
			previous = at
			if sampled_distance >= first - FISSURE_LEAD_UNITS:
				_path.append(at)
		sites.append(previous)
		if is_equal_approx(distance, reach):
			break
	_extend_path(forward)
	return sites


## The tail past the last tentacle is only drawn where the ground carries on.
func _extend_path(forward: Vector3) -> void:
	if _path.is_empty():
		return
	var last := _path[_path.size() - 1]
	var beyond := last + forward * FISSURE_TAIL_UNITS
	var ground := _ground_at(beyond)
	if ground.is_empty():
		return
	var at: Vector3 = ground.position
	if absf(at.y - last.y) <= MAX_GROUND_STEP and not _wall_between(last, at):
		_path.append(at)


func _ground_at(at: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(
		at + Vector3.UP * GROUND_PROBE_UP, at - Vector3.UP * GROUND_PROBE_DOWN, CombatLayers.WORLD
	)
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and (hit.normal as Vector3).y < MIN_GROUND_NORMAL_Y:
		return {}
	return hit


func _wall_between(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(
		from + Vector3.UP * WALL_PROBE_HEIGHT,
		to + Vector3.UP * WALL_PROBE_HEIGHT,
		CombatLayers.WORLD | CombatLayers.PLAYER_BOUNDARY
	)
	return not actor.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(actor) or bool(actor.get("dead")):
		cancel_active()
		return
	for index in range(_tentacles.size() - 1, -1, -1):
		if not is_instance_valid(_tentacles[index]):
			_tentacles.remove_at(index)
	if _next_site < _sites.size():
		_spawn_clock -= maxf(delta, 0.0)
		while _spawn_clock <= 0.0 and _next_site < _sites.size():
			_spawn_tentacle()
			_spawn_clock += maxf(0.01, definition.get_param_float(&"spawn_interval_seconds"))
	if _next_site >= _sites.size() and _tentacles.is_empty():
		if is_instance_valid(_fissure):
			_fissure.close()
		_fissure = null
		_sites.clear()
		set_physics_process(false)


func _spawn_tentacle() -> void:
	var index := _next_site
	var site := _sites[index]
	var is_finale := index == _sites.size() - 1
	var tentacle := _create_tentacle()
	tentacle.size_scale = (
		definition.get_param_float(&"finale_scale")
		if is_finale
		else HEIGHT_SCALES[index % HEIGHT_SCALES.size()]
	)
	tentacle.lean = LEANS_RADIANS[index % LEANS_RADIANS.size()]
	tentacle.curl_side = CURL_SIDES[index % CURL_SIDES.size()]
	if is_finale:
		_finale = tentacle
	tentacle.target_requested.connect(_on_target_requested.bind(tentacle))
	tentacle.struck.connect(_on_tentacle_struck.bind(tentacle))
	_place(tentacle, site)
	_spawn_flankers(site)
	KrakenDebris.spawn(
		actor.get_parent(), site, FINALE_ROCKS if is_finale else ERUPTION_ROCKS, tentacle.size_scale
	)
	if index == 0:
		_end_cast_lock()
		_play_cast_animation(&"slam", _direction, tentacle.RISE_SECONDS, true)
		CharmFeel.shockwave(actor, site, CRIMSON, SHOCKWAVE_RADIUS_PIXELS)
	CharmFeel.shake(actor, 4.0, 0.12)
	CharmFeel.sound(actor, CharmFeel.IMPACT_SOUND, site, -9.0, randf_range(0.5, 0.65))
	_next_site += 1
	if _next_site == _sites.size():
		_play_cast_animation(&"recover", _direction, 0.0, true)


## Short extra tips ripping out beside a summon make the wave read as one torn seam.
func _spawn_flankers(site: Vector3) -> void:
	var across := _direction.cross(Vector3.UP)
	for side: float in [-1.0, 1.0]:
		var offset := across * FLANK_SIDE_UNITS + _direction * FLANK_ALONG_UNITS
		var ground := _ground_at(site + offset * side)
		if ground.is_empty() or absf((ground.position as Vector3).y - site.y) > MAX_GROUND_STEP:
			continue
		var flanker := _create_tentacle()
		flanker.decorative = true
		flanker.size_scale = randf_range(FLANK_MIN_SCALE, FLANK_MAX_SCALE)
		flanker.lean = FLANK_LEAN_RADIANS * side
		flanker.curl_side = side
		_place(flanker, ground.position)


func _create_tentacle() -> KrakenTentacle:
	var tentacle := TENTACLE.instantiate() as KrakenTentacle
	tentacle.definition = definition
	tentacle.facing = _direction
	return tentacle


func _place(tentacle: KrakenTentacle, at: Vector3) -> void:
	var arena := actor.get_parent() as Node3D
	tentacle.position = arena.to_local(at)
	arena.add_child(tentacle)
	_tentacles.append(tentacle)


func _on_target_requested(tentacle: KrakenTentacle) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(tentacle):
		return
	var targets := _targets_at(
		tentacle.global_position, definition.get_param_float(&"seek_radius_units")
	)
	var nearest: Node3D
	var best_distance := INF
	for target in targets:
		var distance := tentacle.global_position.distance_squared_to(target.global_position)
		if distance < best_distance:
			best_distance = distance
			nearest = target
	if nearest != null:
		tentacle.begin_slam(nearest.global_position)


func _targets_at(at: Vector3, radius: float) -> Array[Node3D]:
	var targets: Array[Node3D] = []
	for target in _hurtbox_actors_at(at, radius):
		if not target.is_in_group(&"enemy") and not target.is_in_group(&"training_dummy"):
			continue
		if not _wall_between(at, target.global_position):
			targets.append(target)
	return targets


## Every living opposing actor with a hurtbox in the column, listed once.
func _hurtbox_actors_at(at: Vector3, radius: float) -> Array[Node3D]:
	var actors: Array[Node3D] = []
	var volume := CylinderShape3D.new()
	volume.radius = radius
	volume.height = TARGET_HEIGHT_UNITS
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = volume
	query.transform.origin = at + Vector3.UP * TARGET_HEIGHT_UNITS * 0.5
	query.collision_mask = CombatLayers.ENEMY_HURTBOX
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var sampled: Array[RID] = []
	while true:
		query.exclude = sampled
		var hits := actor.get_world_3d().direct_space_state.intersect_shape(query, QUERY_BATCH_SIZE)
		for hit in hits:
			sampled.append(hit.rid)
			var hurtbox := hit.collider as HurtBox
			if (
				not is_instance_valid(hurtbox)
				or not hurtbox.enabled
				or hurtbox.team == actor.get("team")
			):
				continue
			var target := hurtbox.actor as Node3D
			if not is_instance_valid(target) or target == actor or target.get("dead") == true:
				continue
			if target not in actors:
				actors.append(target)
		if hits.size() < QUERY_BATCH_SIZE:
			break
	return actors


func _on_tentacle_struck(at: Vector3, eruption: bool, tentacle: KrakenTentacle) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(tentacle):
		return
	if eruption:
		_resolve_eruption(at, tentacle)
	else:
		_resolve_slam(at, tentacle)


## One wave, one hit: overlapping eruptions never strike the same enemy twice.
func _resolve_eruption(at: Vector3, tentacle: KrakenTentacle) -> void:
	var is_finale := tentacle == _finale
	var size := definition.get_param_float(&"finale_scale") if is_finale else 1.0
	var radius := definition.get_param_float(&"eruption_radius_units") * size
	var damage := _damage * definition.get_param_float(&"eruption_damage_multiplier")
	var push := definition.get_param_float(&"eruption_push") * size
	var first_hit: Node3D
	for target in _targets_at(at, radius):
		if target in _wave_struck:
			continue
		if _damage_target(target, damage, tentacle.global_position, push) <= 0.0:
			continue
		_wave_struck.append(target)
		if target is EnemyBase:
			(target as EnemyBase).apply_charm_stun(
				definition.get_param_float(&"eruption_stun_seconds")
			)
		CharmVfx.spawn(actor.get_parent(), target.global_position, CRIMSON, 0.7, IMPACT_SECONDS)
		if first_hit == null:
			first_hit = target
	_shatter_props(at, radius)
	if first_hit != null:
		CharmFeel.sound(actor, CharmFeel.HIT_SOUND, at, -8.0, 0.8)
		if not _wave_confirmed:
			_wave_confirmed = true
			CharmFeel.hitstop(actor, 0.06, first_hit)
	if is_finale:
		CharmVfx.spawn(actor.get_parent(), at, CRIMSON, radius, IMPACT_SECONDS)
		CharmFeel.shake(actor, 9.0, 0.28)
		CharmFeel.flash(actor, CRIMSON, 0.12, 0.18)
		CharmFeel.shockwave(actor, at, CRIMSON, SHOCKWAVE_RADIUS_PIXELS)
		CharmFeel.sound(actor, CharmFeel.IMPACT_SOUND, at, -3.0, 0.4)


func _resolve_slam(at: Vector3, tentacle: KrakenTentacle) -> void:
	var radius := definition.get_param_float(&"slam_radius_units")
	var damage := _damage * definition.get_param_float(&"slam_damage_multiplier")
	var push := definition.get_param_float(&"slam_push")
	var hit_confirmed := false
	for target in _targets_at(at, radius):
		if _damage_target(target, damage, tentacle.global_position, push) > 0.0:
			hit_confirmed = true
	CharmVfx.spawn(actor.get_parent(), at, CRIMSON, radius, IMPACT_SECONDS)
	KrakenDebris.spawn(actor.get_parent(), at, SLAM_ROCKS, 0.8)
	CharmFeel.sound(actor, CharmFeel.IMPACT_SOUND, at, -13.0, 0.85)
	if hit_confirmed:
		CharmFeel.shake(actor, 2.5, 0.1)
		CharmFeel.sound(actor, CharmFeel.HIT_SOUND, at, -10.0)


## Only weak scenery breaks; sturdier props (a campfire, a boat) are left alone.
func _shatter_props(at: Vector3, radius: float) -> void:
	var break_max_hp := definition.get_param_float(&"prop_break_max_hp")
	for node in _hurtbox_actors_at(at, radius):
		var prop := node as DestructibleProp
		if prop == null or prop.max_hp > break_max_hp:
			continue
		KrakenDebris.spawn(actor.get_parent(), prop.global_position, PROP_ROCKS)
		prop.break_from_impact()


func on_input_cancelled() -> void:
	# Once released, the summons keep fighting while Foxy moves or dodges.
	if _next_site == 0:
		cancel_active()


func cancel_active() -> void:
	_stop_cast_animation()
	set_physics_process(false)
	if is_instance_valid(_fissure):
		_fissure.queue_free()
	_fissure = null
	_finale = null
	_wave_struck.clear()
	for tentacle in _tentacles:
		if is_instance_valid(tentacle):
			tentacle.set_physics_process(false)
			tentacle.queue_free()
	_tentacles.clear()
	_sites.clear()
	_next_site = 0
