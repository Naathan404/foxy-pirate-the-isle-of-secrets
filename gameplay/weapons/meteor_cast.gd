extends WeaponAttack
## The cast releases the first meteor at the end of windup; the volley continues independently.

@export var meteor_scene: PackedScene
@export var charge_vfx_scene: PackedScene
@export_range(0.0, 3.0, 0.05, "suffix:m") var charge_vfx_height: float = 1.0
@export_range(1, 20, 1) var minimum_meteors: int = 1
@export_range(1, 20, 1) var maximum_meteors: int = 1
@export_range(0.0, 10.0, 0.1, "suffix:m") var spread_radius: float = 0.0
@export_range(0.01, 2.0, 0.01, "suffix:s") var meteor_interval: float = 0.18

var _remaining_meteors: int = 0
var _time_until_next: float = 0.0
var _random := RandomNumberGenerator.new()
var _charge_vfx: Node3D
var _windup_elapsed: float = 0.0
var _windup_duration: float = 1.0


func validate() -> bool:
	return (
		meteor_scene != null
		and charge_vfx_scene != null
		and minimum_meteors > 0
		and maximum_meteors >= minimum_meteors
		and is_finite(meteor_interval) and meteor_interval > 0.0
		and is_finite(spread_radius) and spread_radius >= 0.0
	)


func begin_windup() -> void:
	if context == null or not is_instance_valid(context.actor):
		return
	_windup_elapsed = 0.0
	var player := context.actor as Player
	if player != null and is_instance_valid(player.weapon_controller):
		_windup_duration = maxf(0.01, player.weapon_controller.get_attack_windup_duration())
	_charge_vfx = charge_vfx_scene.instantiate() as Node3D
	get_parent().add_child(_charge_vfx)
	_sync_charge_vfx()


func tick_windup(delta: float) -> void:
	_windup_elapsed = minf(_windup_duration, _windup_elapsed + maxf(delta, 0.0))
	_sync_charge_vfx()
	if is_instance_valid(_charge_vfx):
		_charge_vfx.call("set_progress", _windup_elapsed / _windup_duration)


func _sync_charge_vfx() -> void:
	if is_instance_valid(_charge_vfx) and is_instance_valid(context.actor):
		_charge_vfx.global_position = context.actor.global_position + Vector3.UP * charge_vfx_height


func activate() -> void:
	if is_instance_valid(_charge_vfx):
		_charge_vfx.call("burst", 1.0)
		_charge_vfx = null
	if context == null or not is_instance_valid(context.actor) or not context.has_target:
		return
	var player := context.actor as Player
	if player != null:
		var cursor := player.build_attack_context()
		if cursor.has_target:
			var offset := cursor.target_position - context.origin
			offset.y = 0.0
			var attack: AttackData = context.weapon.get_attack(context.action)
			if not attack.target_cursor_without_range_limit:
				offset = offset.limit_length(context.range_units)
			context.target_position = context.origin + offset
			if not offset.is_zero_approx():
				context.direction = offset.normalized()
	super.activate()
	_random.randomize()
	_remaining_meteors = _random.randi_range(minimum_meteors, maximum_meteors)
	_spawn_meteor(true)
	_time_until_next = meteor_interval
	set_physics_process(_remaining_meteors > 0)


func _physics_process(delta: float) -> void:
	if not launched or _remaining_meteors <= 0:
		set_physics_process(false)
		return
	_time_until_next -= maxf(delta, 0.0)
	while _remaining_meteors > 0 and _time_until_next <= 0.0:
		_spawn_meteor(false)
		_time_until_next += meteor_interval
	if _remaining_meteors <= 0:
		set_physics_process(false)
		if not active:
			queue_free()


func _spawn_meteor(first: bool) -> void:
	if not is_instance_valid(get_parent()):
		_remaining_meteors = 0
		return
	var impact_position := context.target_position
	if not first and spread_radius > 0.0:
		var angle := _random.randf_range(0.0, TAU)
		var radius := sqrt(_random.randf()) * spread_radius
		impact_position += Vector3(cos(angle), 0.0, sin(angle)) * radius
	var meteor = meteor_scene.instantiate()
	get_parent().add_child(meteor)
	meteor.global_position = impact_position
	meteor.launch(context)
	_remaining_meteors -= 1


func deactivate() -> void:
	super.deactivate()
	if _remaining_meteors <= 0:
		set_physics_process(false)


func release() -> void:
	if _remaining_meteors <= 0:
		queue_free()


func cancel() -> void:
	if is_instance_valid(_charge_vfx):
		_charge_vfx.queue_free()
		_charge_vfx = null
	if launched:
		deactivate()
		if _remaining_meteors <= 0:
			queue_free()
	else:
		super.cancel()
