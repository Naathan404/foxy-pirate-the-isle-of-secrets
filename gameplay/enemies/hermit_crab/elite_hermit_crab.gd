class_name EliteHermitCrab
extends HermitCrab

const MAX_DASH_SWEEP_HITS := 64

@export_group("Elite Hermit Crab Patrol")
@export var use_random_axis_patrol: bool = true
@export_range(0.05, 60.0, 0.05, "suffix:s") var axis_change_duration_min: float = 1.5
@export_range(0.05, 60.0, 0.05, "suffix:s") var axis_change_duration_max: float = 4.0

@export_group("Dash Collisions")
@export_range(0.0, 30.0, 0.5, "suffix:m/s") var dash_side_push_speed: float = 14.0
@export_range(0.0, 1.0, 0.05, "suffix:m") var dash_sweep_padding_meters: float = 0.15

var _dash_collision_active := false
var _body_mask_before_dash: int
var _front_mask_before_dash: int
var _pushed_enemies: Dictionary[int, bool] = {}
var _ignored_dash_bodies: Array[PhysicsBody3D] = []
var _sweep_shape := BoxShape3D.new()

@onready var _dash_collision: CollisionShape3D = $Direction/ContactHitBox/CollisionShape3D


func _ready() -> void:
	var patrol := get_node_or_null("States/Patrol") as EnemyPatrol
	if patrol != null:
		patrol.use_random_axis_changes = use_random_axis_patrol
		patrol.axis_change_duration_min = axis_change_duration_min
		patrol.axis_change_duration_max = axis_change_duration_max
	super()


func begin_dash_collision() -> void:
	_pushed_enemies.clear()
	if _dash_collision_active:
		return
	_dash_collision_active = true
	_body_mask_before_dash = collision_mask
	_front_mask_before_dash = front_ray.collision_mask
	collision_mask &= ~(CombatLayers.ENEMY_BODY | CombatLayers.PLAYER_BODY)
	front_ray.collision_mask &= ~CombatLayers.ENEMY_BODY


func end_dash_collision() -> void:
	if not _dash_collision_active:
		return
	_dash_collision_active = false
	# Death owns the disabled body mask; do not re-enable it from the outgoing state.
	if not dead:
		collision_mask = _body_mask_before_dash
	front_ray.collision_mask = _front_mask_before_dash
	for body: PhysicsBody3D in _ignored_dash_bodies:
		if is_instance_valid(body):
			remove_collision_exception_with(body)
			front_ray.remove_exception(body)
	_ignored_dash_bodies.clear()
	_pushed_enemies.clear()


## Sweep the whole upcoming step, including props which do not accept enemy attacks.
func clear_dash_path(direction: Vector3, distance_meters: float) -> void:
	if not _dash_collision_active:
		return
	var reach := maxf(0.0, distance_meters) + dash_sweep_padding_meters
	_sweep_shape.size = (_dash_collision.shape as BoxShape3D).size + Vector3(0, 0, reach)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _sweep_shape
	query.transform = _dash_collision.global_transform
	query.transform.origin += direction * reach * 0.5
	query.collision_mask = CombatLayers.WORLD | CombatLayers.ENEMY_BODY | CombatLayers.ENEMY_HURTBOX
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [get_rid()]
	for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(
		query, MAX_DASH_SWEEP_HITS
	):
		var collider := hit.collider as Node
		var actor := _dash_actor(collider)
		if actor is DestructibleProp:
			_ignore_prop_bodies(actor)
			(actor as DestructibleProp).break_from_impact()
		elif actor is EnemyBase and actor != self:
			_push_enemy_aside(actor as EnemyBase, direction)
	front_ray.force_raycast_update()


func _dash_actor(collider: Node) -> Node:
	if collider is HurtBox:
		return (collider as HurtBox).actor
	var current := collider
	while current != null:
		if current is EnemyBase or current is DestructibleProp:
			return current
		current = current.get_parent()
	return null


func _ignore_prop_bodies(prop: Node) -> void:
	for child in prop.get_children():
		var body := child as PhysicsBody3D
		if body == null or _ignored_dash_bodies.has(body):
			continue
		add_collision_exception_with(body)
		front_ray.add_exception(body)
		_ignored_dash_bodies.append(body)


func _push_enemy_aside(other: EnemyBase, direction: Vector3) -> void:
	var instance_id := other.get_instance_id()
	if other.dead or _pushed_enemies.has(instance_id):
		return
	_pushed_enemies[instance_id] = true
	var sideways := Vector3(direction.z, 0.0, -direction.x).normalized()
	if (other.global_position - global_position).dot(sideways) < 0.0:
		sideways = -sideways
	other.apply_external_push(sideways * dash_side_push_speed)
