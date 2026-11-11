class_name ArrowRainEffect
extends CharmEffect
## Bắn tám projectile theo hướng con trỏ trong khoảng thời gian cấu hình.

signal projectile_launched(
	projectile_index: int, projectile_count: int, direction: Vector3, damage_hp: float
)

const CHARM_ATTACK_SCENE = preload("res://gameplay/charms/active/arrow_rain_attack.tscn")
const TELEGRAPH_SCENE = preload("res://gameplay/charms/active/arrow_rain_telegraph.tscn")

var _remaining_projectiles: int = 0
var _projectile_timer: float = 0.0
var _activation_direction: Vector3 = Vector3.BACK
var _target_position: Vector3 = Vector3.ZERO
var _has_target_position: bool = false
var _socket_id: int = CharmConstants.SocketId.UNASSIGNED
var _executions: Array[CharmActiveAttack] = []
var _launched_projectile_count: int = 0
var _telegraph: Node3D


func can_activate(context: CharmActivationContext) -> bool:
	if not super.can_activate(context) or not context.is_valid():
		return false
	if not is_instance_valid(actor) or not is_instance_valid(actor.get_parent()):
		return false
	if definition.get_param_int(&"projectile_count") <= 0:
		return false
	for param_id: StringName in [
		&"damage_percent",
		&"volley_duration_seconds",
		&"projectile_speed",
		&"range_units",
		&"projectile_width_units",
		&"projectile_length_units",
	]:
		if definition.get_param_float(param_id) <= 0.0:
			return false
	var execution := CHARM_ATTACK_SCENE.instantiate() as CharmActiveAttack
	var is_valid := execution != null and execution.validate()
	if is_instance_valid(execution):
		execution.free()
	return is_valid


func activate(context: CharmActivationContext) -> bool:
	if not can_activate(context):
		return false
	_remaining_projectiles = definition.get_param_int(&"projectile_count")
	_projectile_timer = 0.0
	_activation_direction = _get_aim_direction(context)
	_target_position = (
		context.target_position
		if context.has_target
		else (
			actor.global_position
			+ _activation_direction * definition.get_param_float(&"range_units", 8.0)
		)
	)
	_target_position.y = actor.global_position.y
	_has_target_position = true
	_socket_id = context.socket_id
	_launched_projectile_count = 0
	_spawn_telegraph()
	set_physics_process(true)
	var launch_context := CharmActivationContext.new()
	launch_context.actor = actor
	launch_context.socket_id = _socket_id
	launch_context.direction = _activation_direction
	_spawn_projectile(launch_context)
	_projectile_timer = _get_projectile_interval()
	return true


func on_unequipped() -> void:
	cancel_active()


func cancel_active() -> void:
	set_physics_process(false)
	_remaining_projectiles = 0
	_has_target_position = false
	if is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_telegraph = null
	for execution: CharmActiveAttack in _executions:
		if is_instance_valid(execution):
			execution.deactivate()
			execution.queue_free()
	_executions.clear()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(actor) or bool(actor.get("dead")):
		cancel_active()
		return
	if _remaining_projectiles <= 0:
		set_physics_process(false)
		return
	_projectile_timer -= maxf(delta, 0.0)
	while _projectile_timer <= 0.0 and _remaining_projectiles > 0:
		var context := CharmActivationContext.new()
		context.actor = actor
		context.socket_id = _socket_id
		context.direction = _activation_direction
		_spawn_projectile(context)
		_projectile_timer += _get_projectile_interval()


func _spawn_projectile(context: CharmActivationContext) -> void:
	if not is_instance_valid(actor) or definition == null:
		_remaining_projectiles = 0
		return
	var execution := CHARM_ATTACK_SCENE.instantiate() as CharmActiveAttack
	if execution == null:
		_remaining_projectiles = 0
		return
	var parent := actor.get_parent()
	if not is_instance_valid(parent):
		execution.free()
		_remaining_projectiles = 0
		return
	parent.add_child(execution)
	_executions.append(execution)
	execution.tree_exited.connect(_on_execution_exited.bind(execution), CONNECT_ONE_SHOT)
	execution.context = AttackContext.new()
	execution.context.delivery_type = AttackData.DeliveryType.PROJECTILE
	execution.context.actor = actor
	execution.context.team = actor.team
	execution.context.attack_id = Time.get_ticks_usec()
	execution.context.action = definition.charm_id
	execution.context.origin = actor.global_position
	var index := _launched_projectile_count
	var count := maxi(1, definition.get_param_int(&"projectile_count", 8))
	var radius := definition.get_param_float(&"impact_radius_units", 2.0)
	# Golden-angle distribution fills the full circle instead of placing every arrow
	# on the outer rim, while remaining deterministic for replays and tests.
	var angle := float(index) * 2.39996323
	var radial_fraction := sqrt((float(index) + 0.5) / float(count))
	var radial_offset := Vector3(cos(angle), 0.0, sin(angle)) * radius * radial_fraction
	var impact_position := _target_position + radial_offset
	# Keep the impact/damage facing stable for downstream knockback and callbacks;
	# the arrow sprite itself follows the parabolic tangent independently.
	execution.context.direction = Vector3.BACK
	execution.context.damage_hp = maxf(
		0.0, _get_base_damage() * definition.get_param_float(&"damage_percent", 0.35)
	)
	var spawn_height := definition.get_param_float(&"spawn_height_units", 0.8)
	var flight_height := definition.get_param_float(&"flight_height_units", 5.0)
	var start_position := actor.global_position + Vector3.UP * spawn_height
	var end_position := impact_position + Vector3.UP * 0.05
	execution.flight_start = start_position
	execution.flight_control = start_position.lerp(end_position, 0.5) + Vector3.UP * flight_height
	execution.flight_end = end_position
	execution.flight_duration = definition.get_param_float(&"flight_duration_seconds", 0.8)
	execution.impact_activation_progress = definition.get_param_float(
		&"impact_activation_progress", 0.52
	)
	execution.impact_hold_seconds = definition.get_param_float(&"impact_lifetime_seconds", 0.18)
	execution.global_position = start_position
	var projectile_width := definition.get_param_float(&"projectile_width_units", 0.25)
	var projectile_length := definition.get_param_float(&"projectile_length_units", 0.8)
	execution.hitbox_scale = Vector3(projectile_width, 1.0, projectile_length)
	execution.activate()
	if not execution.active:
		_remaining_projectiles = 0
		execution.queue_free()
		return
	_remaining_projectiles -= 1
	_launched_projectile_count += 1
	projectile_launched.emit(
		_launched_projectile_count,
		definition.get_param_int(&"projectile_count"),
		execution.context.direction,
		execution.context.damage_hp
	)


func _get_base_damage() -> float:
	var weapon_controller := actor.get("weapon_controller") as WeaponController
	if is_instance_valid(weapon_controller) and weapon_controller.equipped != null:
		var attack := weapon_controller.equipped.get_attack(&"normal")
		if attack != null:
			return attack.damage_hp
	return 1


func _get_projectile_interval() -> float:
	var interval_count := maxi(1, definition.get_param_int(&"projectile_count") - 1)
	return definition.get_param_float(&"volley_duration_seconds") / float(interval_count)


func _get_aim_direction(context: CharmActivationContext) -> Vector3:
	var direction := context.direction
	if context.has_target:
		direction = context.target_position - actor.global_position
	direction.y = 0.0
	return direction.normalized() if not direction.is_zero_approx() else Vector3.BACK


func _on_execution_exited(execution: CharmActiveAttack) -> void:
	_executions.erase(execution)


func _spawn_telegraph() -> void:
	if not is_instance_valid(actor) or not _has_target_position:
		return
	if is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_telegraph = TELEGRAPH_SCENE.instantiate() as Node3D
	if _telegraph == null:
		return
	_telegraph.set("radius", definition.get_param_float(&"impact_radius_units", 2.0))
	_telegraph.set("lifetime", (
		definition.get_param_float(&"volley_duration_seconds", 1.4)
		+ definition.get_param_float(&"flight_duration_seconds", 0.8)
		+ definition.get_param_float(&"impact_lifetime_seconds", 0.18)
	))
	var parent := actor.get_parent()
	if is_instance_valid(parent):
		parent.add_child(_telegraph)
		_telegraph.global_position = _target_position
