class_name CharmActiveAttack
extends WeaponAttack
## Base execution cho Active Charm dùng hitbox vật lý của combat system.

signal attack_started(damage_hp: float, direction: Vector3)
signal travel_finished

@export var hitbox: HitBox
@export var hitbox_scale: Vector3 = Vector3.ONE
@export var forward_offset: float = 0.0
@export var travel_speed_units_per_second: float = 0.0
@export var max_travel_distance: float = 0.0

@export_group("Presentation")
@export var trail_color: Color = CharmVfx.GOLD
@export var trail_length: float = 1.1
@export var trail_width: float = 0.45
@export var trail_height: float = 0.65
@export var hitstop_seconds: float = 0.045
@export var shake_pixels: float = 4.0
@export var local_hitstop: bool = false

var _travelled_distance: float = 0.0
var _trail: CharmVfx
var _impact_reported: bool = false


func _ready() -> void:
	if is_instance_valid(hitbox):
		hitbox.hit_confirmed.connect(_on_charm_hit)


func validate() -> bool:
	return is_instance_valid(hitbox)


func activate() -> void:
	if context == null or not is_instance_valid(hitbox) or not is_instance_valid(context.actor):
		return

	super.activate()
	var facing := context.direction
	if facing.is_zero_approx() or facing.cross(Vector3.UP).is_zero_approx():
		facing = Vector3.BACK
	look_at(global_position + facing, Vector3.UP)
	hitbox.position.z = -forward_offset
	hitbox.scale = hitbox_scale * context.hitbox_multiplier
	hitbox.actor = context.actor
	hitbox.team = context.team
	if not hitbox.begin_attack_with_context(context.create_damage_context()):
		deactivate()
		return
	_travelled_distance = 0.0
	_impact_reported = false
	_start_trail()
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
	_update_trail(context.direction)
	_travelled_distance += step
	if _travelled_distance >= max_travel_distance:
		travel_finished.emit()
		_cancel_and_free()


func _start_trail() -> void:
	_trail = CharmVfx.streak(self, global_position, global_position, trail_color, trail_width)
	_trail.sustained = true
	_update_trail(context.direction)


func _update_trail(direction: Vector3) -> void:
	if is_instance_valid(_trail):
		var head := global_position + Vector3.UP * trail_height
		_trail.set_endpoints(head - direction.normalized() * trail_length, head, trail_width)


func _on_charm_hit(_damage: DamageContext, target: Node, applied_hp: float) -> void:
	if applied_hp <= 0.0:
		return
	var at := global_position
	if target is Node3D:
		at = (target as Node3D).global_position + Vector3.UP * 0.6
	CharmVfx.spawn(get_parent(), at, trail_color, 0.8)
	_apply_impact_feedback(target)


func _apply_impact_feedback(target: Node) -> void:
	if _impact_reported:
		return
	_impact_reported = true
	var hitstop := get_node("/root/HitstopController")
	if local_hitstop:
		hitstop.request_local(null, target as Node3D, hitstop_seconds)
	else:
		hitstop.request(hitstop_seconds, target)
	get_node("/root/ScreenShakeController").request(shake_pixels, 0.14)


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
