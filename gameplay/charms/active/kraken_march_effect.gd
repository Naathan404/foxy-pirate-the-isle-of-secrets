class_name KrakenMarchEffect
extends CharmEffect
## Grounded, staggered summons. The effect owns damage and all summon lifetimes.

const TENTACLE := preload("res://gameplay/charms/active/kraken_tentacle.tscn")
const INK := Color("9960ee")
const FOAM := Color("65eee1")
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

var _sites: Array[Vector3] = []
var _marks: Array[CharmVfx] = []
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
	for index in _sites.size():
		var delay := _spawn_clock + index * definition.get_param_float(&"spawn_interval_seconds")
		var mark := CharmVfx.spawn(
			actor.get_parent(),
			_sites[index],
			INK,
			definition.get_param_float(&"eruption_radius_units"),
			delay,
			CharmVfx.Style.TARGET
		)
		mark.sustained = true
		_marks.append(mark)
	_play_cast_animation(&"windup", _direction, _spawn_clock)
	CharmFeel.sound(actor, CharmFeel.WHOOSH_SOUND, actor.global_position, -8.0, 0.65)
	set_physics_process(true)
	return true


func _build_sites(context: CharmActivationContext) -> Array[Vector3]:
	var sites: Array[Vector3] = []
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
		sites.append(previous)
		if is_equal_approx(distance, reach):
			break
	return sites


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
		_sites.clear()
		set_physics_process(false)


func _spawn_tentacle() -> void:
	var site := _sites[_next_site]
	var mark := _marks[_next_site]
	if is_instance_valid(mark):
		mark.queue_free()
	var tentacle := TENTACLE.instantiate() as KrakenTentacle
	tentacle.definition = definition
	tentacle.facing = _direction
	tentacle.target_requested.connect(_on_target_requested.bind(tentacle))
	tentacle.struck.connect(_on_tentacle_struck.bind(tentacle))
	var arena := actor.get_parent() as Node3D
	tentacle.position = arena.to_local(site)
	arena.add_child(tentacle)
	_tentacles.append(tentacle)
	if _next_site == 0:
		_end_cast_lock()
		_play_cast_animation(&"slam", _direction, tentacle.RISE_SECONDS, true)
	_next_site += 1
	if _next_site == _sites.size():
		_marks.clear()
		_play_cast_animation(&"recover", _direction, 0.0, true)


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
			if not target.is_in_group(&"enemy") and not target.is_in_group(&"training_dummy"):
				continue
			if target not in targets and not _wall_between(at, target.global_position):
				targets.append(target)
		if hits.size() < QUERY_BATCH_SIZE:
			break
	return targets


func _on_tentacle_struck(at: Vector3, eruption: bool, tentacle: KrakenTentacle) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(tentacle):
		return
	var radius := definition.get_param_float(
		&"eruption_radius_units" if eruption else &"slam_radius_units"
	)
	var multiplier := definition.get_param_float(
		&"eruption_damage_multiplier" if eruption else &"slam_damage_multiplier"
	)
	var push := definition.get_param_float(&"eruption_push" if eruption else &"slam_push")
	var hit_confirmed := false
	for target in _targets_at(at, radius):
		if _damage_target(target, _damage * multiplier, tentacle.global_position, push) > 0.0:
			hit_confirmed = true
	CharmVfx.spawn(actor.get_parent(), at, FOAM, radius, IMPACT_SECONDS)
	CharmFeel.sound(actor, CharmFeel.IMPACT_SOUND, at, -13.0, 0.7 if eruption else 0.85)
	if hit_confirmed:
		CharmFeel.shake(actor, 2.5, 0.1)
		CharmFeel.sound(actor, CharmFeel.HIT_SOUND, at, -10.0)


func on_input_cancelled() -> void:
	# Once released, the summons keep fighting while Foxy moves or dodges.
	if _next_site == 0:
		cancel_active()


func cancel_active() -> void:
	_stop_cast_animation()
	set_physics_process(false)
	for mark in _marks:
		if is_instance_valid(mark):
			mark.queue_free()
	_marks.clear()
	for tentacle in _tentacles:
		if is_instance_valid(tentacle):
			tentacle.set_physics_process(false)
			tentacle.queue_free()
	_tentacles.clear()
	_sites.clear()
	_next_site = 0
