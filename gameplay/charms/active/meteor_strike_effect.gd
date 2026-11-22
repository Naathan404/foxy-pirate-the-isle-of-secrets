extends CharmEffect
## Each impact starts its burn zone at the staff animation's authored contact frame.

const METEOR := preload("res://gameplay/weapons/meteor_impact.tscn")
const RELEASE_SECONDS := 0.2
const FIRE := Color("ff652a")
var _windup := 0.0
var _launch_delay := 0.0
var _sites: Array[Vector3] = []
var _meteors: Array[Node3D] = []
var _zones: Dictionary[CharmVfx, float] = {}
var _tick_remaining := 0.0
var _heavy_hit := false
var _direction := Vector3.ZERO


func activate(context: CharmActivationContext) -> bool:
	if not context.has_target or not _begin_cast_lock():
		return false
	var spread := definition.get_param_float(&"spread_units")
	var axis := Vector3.RIGHT.rotated(Vector3.UP, randf() * TAU)
	_sites.assign(
		[
			context.target_position,
			context.target_position + axis * spread,
			context.target_position + axis.rotated(Vector3.UP, randf_range(2.0, 4.0)) * spread
		]
	)
	_heavy_hit = false
	_windup = definition.get_param_float(&"windup_seconds")
	_launch_delay = 0.0
	_direction = context.direction
	_play_cast_animation(&"windup", _direction, _windup)
	CharmVfx.spawn(actor, actor.global_position, FIRE, 1.3, _windup, CharmVfx.Style.CHARGE)
	set_physics_process(true)
	return true


func _physics_process(delta: float) -> void:
	if _windup > 0.0:
		_windup -= delta
		if _windup > 0.0:
			return
		_end_cast_lock()
		_play_cast_animation(&"release", _direction, RELEASE_SECONDS)
	if not _sites.is_empty():
		_launch_delay -= delta
		if _launch_delay <= 0.0:
			_launch_next()
			_launch_delay = definition.get_param_float(&"interval_seconds")
	if not _zones.is_empty():
		_tick_remaining -= delta
		if _tick_remaining <= 0.00001:
			_burn()
			_tick_remaining += definition.get_param_float(&"tick_seconds")
		for zone: CharmVfx in _zones.keys():
			_zones[zone] -= delta
			if _zones[zone] <= 0.0:
				zone.queue_free()
				_zones.erase(zone)
	if _sites.is_empty() and _meteors.is_empty() and _zones.is_empty():
		set_physics_process(false)


func _launch_next() -> void:
	var site: Vector3 = _sites.pop_front()
	var meteor := METEOR.instantiate()
	actor.get_parent().add_child(meteor)
	meteor.global_position = site
	meteor.set("charm_impact", true)
	_meteors.append(meteor)
	meteor.connect("landed", _on_landed)
	meteor.tree_exiting.connect(_meteors.erase.bind(meteor), CONNECT_ONE_SHOT)
	var attack := AttackContext.new()
	attack.actor = actor
	attack.team = actor.get("team")
	attack.attack_id = Time.get_ticks_usec()
	attack.action = definition.charm_id
	attack.origin = site
	attack.damage_hp = _get_base_damage() * definition.get_param_float(&"damage_multiplier")
	attack.charm_push = true
	attack.knockback_multiplier = 0.7
	meteor.call("launch", attack)


func _on_landed(site: Vector3, hit_target: bool) -> void:
	if hit_target and not _heavy_hit:
		_heavy_hit = true
		get_node("/root/HitstopController").request(CharmVfx.HEAVY_HITSTOP_SECONDS)
		get_node("/root/ScreenShakeController").request(
			CharmVfx.HEAVY_SHAKE_PIXELS, CharmVfx.HEAVY_SHAKE_SECONDS
		)
	var seconds := definition.get_param_float(&"burn_seconds")
	if _zones.is_empty():
		_tick_remaining = definition.get_param_float(&"tick_seconds")
	var zone := CharmVfx.spawn(
		actor.get_parent(),
		site,
		FIRE,
		definition.get_param_float(&"radius_units"),
		seconds,
		CharmVfx.Style.VORTEX
	)
	zone.sustained = true
	_zones[zone] = seconds


func _burn() -> void:
	var burned: Array[Node3D] = []
	for zone in _zones:
		for target in _targets_in_radius(
			zone.global_position, definition.get_param_float(&"radius_units")
		):
			if target in burned:
				continue
			var hp := target.get("hp") as HealthComponent
			if is_instance_valid(hp):
				burned.append(target)
				_damage_target(
					target,
					hp.get_max_hp() * definition.get_param_float(&"bleed_fraction"),
					zone.global_position,
					0.0,
					&"bleed"
				)


func on_input_cancelled() -> void:
	if _windup > 0.0:
		cancel_active()


func cancel_active() -> void:
	set_physics_process(false)
	_stop_cast_animation()
	_sites.clear()
	for meteor in _meteors:
		if is_instance_valid(meteor):
			meteor.queue_free()
			if meteor.is_connected("landed", _on_landed):
				meteor.disconnect("landed", _on_landed)
	_meteors.clear()
	for zone in _zones:
		if is_instance_valid(zone):
			zone.queue_free()
	_zones.clear()
	_windup = 0.0
