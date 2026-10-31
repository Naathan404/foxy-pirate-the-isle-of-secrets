class_name CharmActiveAttack
extends WeaponAttack
## Base execution cho Active Charm dùng hitbox vật lý của combat system.

signal attack_started(damage_hp: float, direction: Vector3)

@export var hitbox: HitBox
@export var hitbox_scale: Vector3 = Vector3.ONE
@export var forward_offset: float = 0.0
@export var travel_speed_units_per_second: float = 0.0
@export var max_travel_distance: float = 0.0

var _travelled_distance: float = 0.0


func validate() -> bool:
	return is_instance_valid(hitbox)


func activate() -> void:
	if context == null or not is_instance_valid(hitbox) or not is_instance_valid(context.actor):
		return

	super.activate()
	look_at(global_position + context.direction, Vector3.UP)
	hitbox.position.z = -forward_offset
	hitbox.scale = hitbox_scale * context.hitbox_multiplier
	hitbox.actor = context.actor
	hitbox.team = context.team
	if not hitbox.begin_attack(context.damage_hp, context.attack_id, context.action):
		deactivate()
		return
	_travelled_distance = 0.0
	set_physics_process(true)
	attack_started.emit(context.damage_hp, context.direction)


func deactivate() -> void:
	super.deactivate()
	set_physics_process(false)
	if is_instance_valid(hitbox):
		hitbox.end_attack()


func _physics_process(delta: float) -> void:
	if not active or not is_instance_valid(context) or not is_instance_valid(context.actor):
		_cancel_and_free()
		return
	if bool(context.actor.get("dead")):
		_cancel_and_free()
		return
	if travel_speed_units_per_second <= 0.0 or max_travel_distance <= 0.0:
		return
	var remaining_distance := maxf(0.0, max_travel_distance - _travelled_distance)
	var step := minf(travel_speed_units_per_second * maxf(0.0, delta), remaining_distance)
	global_position += context.direction * step
	_travelled_distance += step
	if _travelled_distance >= max_travel_distance:
		_cancel_and_free()


func release_after(seconds: float = 0.08) -> void:
	var tree := get_tree()
	if tree == null:
		deactivate()
		queue_free()
		return
	var timer := tree.create_timer(maxf(0.01, seconds))
	timer.timeout.connect(_release_execution, CONNECT_ONE_SHOT)


func _release_execution() -> void:
	deactivate()
	queue_free()


func _exit_tree() -> void:
	if is_instance_valid(hitbox):
		hitbox.end_attack()


func _cancel_and_free() -> void:
	deactivate()
	queue_free()
