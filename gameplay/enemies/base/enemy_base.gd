class_name EnemyBase
extends CharacterBody3D

## Setup: assign EnemyData, HealthComponent, Direction/HurtBox, FSM and an initial state.
## Keep facing-sensitive nodes under Direction. Add an optional root TargetDetector,
## HitBox and patrol rays only when that enemy needs them; its scene owns the collider shapes,
## animations and behavior states.

signal target_changed(target: Node3D)
signal damaged(applied_hp: float)
signal died

enum InitialFacing {
	DOWN,
	UP,
	LEFT,
	RIGHT,
}

const Teams := preload("res://gameplay/combat/combat_teams.gd")

const ITEM_PICKUP_SCENE: PackedScene = preload("res://gameplay/inventory/item_pickup.tscn")

@export var data: EnemyData
@export var initial_state_name: StringName = &"Idle"
@export var initial_facing: InitialFacing = InitialFacing.DOWN
@export var destroy_on_death: bool = false
@export var charm_grapple_large: bool = false

@export_group("External Push")
## Tốc độ giảm của lực đẩy không gây sát thương.
@export_range(0.1, 100.0, 0.1) var external_push_deceleration: float = 20.0

@export_group("Debug")
@export var show_debug_health: bool = false:
	set(value):
		show_debug_health = value
		_update_debug_health()

var team: int = Teams.ENEMY
var target_group: StringName = &"player"
var target: Node3D
var move_direction: Vector3 = Vector3.ZERO
var last_facing_direction: Vector3 = Vector3.BACK
var dead: bool = false
var pending_hit_direction: Vector3 = Vector3.ZERO
var pending_knockback_multiplier: float = 1.0
var pending_charm_stun_seconds: float = 0.0
var _charm_grapple_tween: Tween
var _external_push_velocity: Vector3 = Vector3.ZERO

@onready var hp: HealthComponent = $HealthComponent
@onready var hurtbox: HurtBox = $Direction/HurtBox
@onready var active_hitbox: HitBox = get_node_or_null(^"Direction/ActiveHitBox") as HitBox
@onready var contact_hitbox: HitBox = get_node_or_null(^"Direction/ContactHitBox") as HitBox
@onready var target_detector: Area3D = get_node_or_null(^"TargetDetector") as Area3D
@onready var visual: EnemyVisual = $Visual
@onready var direction_pivot: Node3D = $Direction
@onready var front_ray: RayCast3D = $Direction/FrontRayCast3D
@onready var ground_ray: RayCast3D = $Direction/GroundRayCast3D
@onready var fsm: Fsm = $FSM
@onready var initial_state: FsmState = (
	get_node_or_null(NodePath("States/" + String(initial_state_name))) as FsmState
)
@onready var debug_health_label: Label3D = $DebugHealthLabel


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if not _validate_components():
		set_physics_process(false)
		return
	_setup_stats()
	_setup_combat()
	_setup_direction_checks()
	_setup_target_detector()
	face_direction(_get_initial_facing_direction())
	_refresh_direction_checks()
	var state_parent := initial_state.get_parent()
	if not fsm.setup(self, state_parent, initial_state):
		set_physics_process(false)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var hitstop_controller := get_node_or_null("/root/HitstopController")
	if (
		hitstop_controller != null
		and hitstop_controller.has_method("is_frozen")
		and bool(hitstop_controller.call("is_frozen", self))
	):
		return
	fsm._update(delta)
	if dead:
		return
	if not is_on_floor():
		velocity += get_gravity() * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0
	move_and_slide()
	if not _external_push_velocity.is_zero_approx():
		move_and_collide(_external_push_velocity * maxf(0.0, delta))
		_external_push_velocity = _external_push_velocity.move_toward(
			Vector3.ZERO, external_push_deceleration * maxf(0.0, delta)
		)


func _apply_external_push(push_velocity: Vector3) -> void:
	if dead:
		return
	_external_push_velocity += Vector3(push_velocity.x, 0.0, push_velocity.z)


func move_in_direction(direction: Vector3, delta: float, speed_scale: float = 1.0) -> void:
	if dead or data == null:
		return
	move_direction = Vector3(direction.x, 0.0, direction.z)
	if not move_direction.is_zero_approx():
		move_direction = move_direction.normalized()
		face_direction(move_direction)

	var target_velocity := move_direction * data.move_speed * maxf(0.0, speed_scale)
	var change_speed := data.deceleration
	if not move_direction.is_zero_approx():
		change_speed = data.acceleration
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	horizontal_velocity = horizontal_velocity.move_toward(
		target_velocity, change_speed * maxf(delta, 0.0)
	)
	_set_horizontal_velocity(horizontal_velocity)


func move_forward(delta: float, speed_scale: float = 1.0) -> void:
	move_in_direction(last_facing_direction, delta, speed_scale)


func move_toward_target(delta: float, stop_distance: float = 0.0) -> bool:
	if not has_target():
		stop_movement(delta)
		return false
	var direction := target.global_position - global_position
	direction.y = 0.0
	if direction.length_squared() <= stop_distance * stop_distance:
		stop_movement(delta)
		return false
	move_in_direction(direction, delta)
	return true


func stop_movement(delta: float = 0.0) -> void:
	move_in_direction(Vector3.ZERO, delta)


func _set_horizontal_velocity(value: Vector3) -> void:
	velocity.x = value.x
	velocity.z = value.z


func _damp_horizontal_velocity(delta: float, deceleration: float) -> void:
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	horizontal_velocity = horizontal_velocity.move_toward(
		Vector3.ZERO, maxf(0.0, deceleration) * maxf(0.0, delta)
	)
	_set_horizontal_velocity(horizontal_velocity)


func face_direction(direction: Vector3) -> void:
	var horizontal := Vector3(direction.x, 0.0, direction.z)
	if horizontal.is_zero_approx():
		return
	last_facing_direction = horizontal.normalized()
	if is_instance_valid(visual):
		visual.set_facing(last_facing_direction)
	if is_instance_valid(direction_pivot):
		direction_pivot.look_at(
			direction_pivot.global_position + last_facing_direction, Vector3.UP, true
		)


func _get_initial_facing_direction() -> Vector3:
	match initial_facing:
		InitialFacing.UP:
			return Vector3.FORWARD
		InitialFacing.LEFT:
			return Vector3.LEFT
		InitialFacing.RIGHT:
			return Vector3.RIGHT
		_:
			return Vector3.BACK


func face_target() -> bool:
	if not has_target():
		return false
	face_direction(target.global_position - global_position)
	return true


func turn_around() -> void:
	face_direction(-last_facing_direction)


func play_directional_animation(action: StringName, restart: bool = false) -> bool:
	if not is_instance_valid(visual):
		return false
	return visual.play_directional(action, last_facing_direction, restart)


func has_target() -> bool:
	return is_instance_valid(target) and not dead


func _distance_to_target() -> float:
	if not has_target():
		return INF
	var direction := target.global_position - global_position
	direction.y = 0.0
	return direction.length()


func is_front_blocked() -> bool:
	return is_instance_valid(front_ray) and front_ray.enabled and front_ray.is_colliding()


func is_ground_ahead() -> bool:
	return not is_instance_valid(ground_ray) or not ground_ray.enabled or ground_ray.is_colliding()


func begin_active_attack(attack_id: int = 0, tag: StringName = &"normal") -> bool:
	if data == null:
		return false
	return _begin_active_attack_with_damage(data.attack_damage, attack_id, tag)


func _begin_active_attack_with_damage(
	amount_hp: float, attack_id: int = 0, tag: StringName = &"normal"
) -> bool:
	if dead or amount_hp <= 0 or not is_instance_valid(active_hitbox):
		return false
	return active_hitbox.begin_attack(amount_hp, attack_id, tag)


func end_active_attack() -> void:
	if is_instance_valid(active_hitbox):
		active_hitbox.end_attack()


func _start_contact_damage() -> bool:
	if dead or data == null or not is_instance_valid(contact_hitbox):
		return false
	contact_hitbox.actor = self
	contact_hitbox.team = team
	return contact_hitbox.begin_attack(
		data.attack_damage, 0, &"contact", HitBox.RehitPolicy.ONCE_PER_CONTACT
	)


func _stop_contact_damage() -> void:
	if is_instance_valid(contact_hitbox):
		contact_hitbox.end_attack()


func take_damage(amount: float) -> float:
	var damage := DamageContext.new()
	damage.amount_hp = amount
	return receive_damage(damage)


func receive_damage(damage: DamageContext) -> float:
	if dead or not is_instance_valid(hp):
		return 0
	if damage == null or damage.amount_hp <= 0:
		return 0
	if damage.source == self or damage.source_team == team:
		return 0
	pending_hit_direction = _get_hit_direction(damage.source)
	if damage.is_melee_normal_attack():
		var direction := Vector3(damage.direction.x, 0.0, damage.direction.z)
		if not direction.is_zero_approx():
			pending_hit_direction = direction.normalized()
	pending_knockback_multiplier = maxf(0.0, damage.knockback_multiplier)
	return hp.take_damage(damage.amount_hp)


## Hit and fatal recoil share forge scaling, resistance and boss immunity.
func consume_hit_knockback_velocity() -> Vector3:
	var multiplier := pending_knockback_multiplier
	pending_knockback_multiplier = 1.0
	if data == null or is_in_group("boss"):
		return Vector3.ZERO
	var direction := pending_hit_direction
	if direction.is_zero_approx():
		direction = -last_facing_direction
	var speed := data.hit_knockback_speed * maxf(0.0, multiplier)
	speed *= 1.0 - data.knockback_resistance
	return direction.normalized() * speed


func apply_charm_grapple(
	source: Node3D, stop_distance: float, pull_speed_units_per_second: float, stun_seconds: float
) -> StringName:
	if dead or not is_instance_valid(source):
		return &"miss"
	if charm_grapple_large or is_in_group("boss"):
		if not source.has_method("apply_charm_grapple_pull"):
			return &"miss"
		var pulled := bool(
			source.call(
				"apply_charm_grapple_pull",
				global_position,
				stop_distance,
				pull_speed_units_per_second
			)
		)
		if not pulled:
			return &"miss"
		return &"actor_pulled_boss" if is_in_group("boss") else &"actor_pulled_large"
	var direction := global_position - source.global_position
	direction.y = 0.0
	if direction.is_zero_approx():
		return &"target_hit"
	pending_hit_direction = direction.normalized()
	pending_charm_stun_seconds = maxf(pending_charm_stun_seconds, stun_seconds)
	if not request_state(&"hit", 60):
		pending_charm_stun_seconds = 0.0
		return &"target_hit"
	var destination := source.global_position + direction.normalized() * maxf(0.0, stop_distance)
	var travel_distance := global_position.distance_to(destination)
	if _charm_grapple_tween != null and _charm_grapple_tween.is_valid():
		_charm_grapple_tween.kill()
	if travel_distance <= 0.001:
		global_position = destination
		return &"target_pulled"
	var duration := travel_distance / maxf(0.01, pull_speed_units_per_second)
	_charm_grapple_tween = create_tween()
	_charm_grapple_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_charm_grapple_tween.tween_property(self, "global_position", destination, duration)
	_charm_grapple_tween.tween_callback(_on_charm_grapple_finished)
	return &"target_pulled"


func _notify_hit() -> void:
	if dead:
		return
	if is_instance_valid(fsm.current_state) and fsm.current_state.name == &"Hit":
		fsm.current_state._enter()
		return
	request_state(&"hit", 50)


func die() -> void:
	if dead:
		return
	dead = true
	_drop_loot.call_deferred()
	if _charm_grapple_tween != null and _charm_grapple_tween.is_valid():
		_charm_grapple_tween.kill()
	_charm_grapple_tween = null
	if not request_state(&"death", 100):
		push_error("EnemyBase: dead enemy could not enter Death state")
	died.emit()


func request_state(state_name: StringName, priority: int = 0) -> bool:
	if not is_instance_valid(fsm):
		return false
	return fsm.change_state(fsm.states.get(String(state_name).to_lower()) as FsmState, priority)


func set_target(next_target: Node3D) -> void:
	if target == next_target:
		return
	target = next_target
	target_changed.emit(target)


func _validate_components() -> bool:
	if data == null:
		push_error("EnemyBase: EnemyData must be assigned")
		return false
	if not is_instance_valid(direction_pivot):
		push_error("EnemyBase: Direction is required")
		return false
	if not is_instance_valid(hp) or not is_instance_valid(hurtbox):
		push_error("EnemyBase: HealthComponent and HurtBox are required")
		return false
	if not is_instance_valid(fsm) or not is_instance_valid(initial_state):
		push_error("EnemyBase: FSM and an initial state are required")
		return false
	if not _validate_required_states():
		return false
	if not _validate_directional_components():
		return false
	return true


func _validate_required_states() -> bool:
	var state_parent := initial_state.get_parent()
	if not is_instance_valid(state_parent):
		push_error("EnemyBase: initial state must belong to a state parent")
		return false
	for state_name: StringName in [&"Hit", &"Death"]:
		if state_parent.get_node_or_null(NodePath(state_name)) is FsmState:
			continue
		push_error("EnemyBase: shared %s state is required" % state_name)
		return false
	return true


func _validate_directional_components() -> bool:
	return (
		_validate_directional_node(hurtbox, &"HurtBox")
		and _validate_directional_node(active_hitbox, &"ActiveHitBox")
		and _validate_directional_node(contact_hitbox, &"ContactHitBox")
		and _validate_directional_node(front_ray, &"FrontRayCast3D")
		and _validate_directional_node(ground_ray, &"GroundRayCast3D")
	)


func _validate_directional_node(node: Node, component_name: StringName) -> bool:
	if node == null:
		return true
	if direction_pivot.is_ancestor_of(node):
		return true
	push_error(
		"EnemyBase: %s must be a child of Direction so it rotates with facing" % component_name
	)
	return false


func _setup_stats() -> void:
	hp.hp_changed.connect(_on_hp_changed)
	hp.damaged.connect(_on_damaged)
	hp.died.connect(die)
	hp.init(data.max_hp)


func _setup_combat() -> void:
	collision_layer = CombatLayers.ENEMY_BODY
	collision_mask = CombatLayers.ENEMY_BODY_MASK
	hurtbox.actor = self
	hurtbox.team = team
	hurtbox.collision_layer = CombatLayers.ENEMY_HURTBOX
	hurtbox.collision_mask = CombatLayers.PLAYER_ATTACK
	for damage_hitbox: HitBox in [active_hitbox, contact_hitbox]:
		if not is_instance_valid(damage_hitbox):
			continue
		damage_hitbox.actor = self
		damage_hitbox.team = team
		damage_hitbox.collision_layer = CombatLayers.ENEMY_ATTACK
		damage_hitbox.collision_mask = CombatLayers.PLAYER_HURTBOX


func _disable_combat_collision() -> void:
	collision_layer = 0
	collision_mask = 0
	if is_instance_valid(hurtbox):
		hurtbox.enabled = false
		hurtbox.collision_layer = 0
		hurtbox.collision_mask = 0
	if is_instance_valid(target_detector):
		target_detector.monitoring = false
	set_target(null)


func _setup_target_detector() -> void:
	if not is_instance_valid(target_detector):
		return
	target_detector.collision_layer = CombatLayers.TARGET_DETECTOR
	target_detector.collision_mask = CombatLayers.PLAYER_BODY
	target_detector.body_entered.connect(_on_target_body_entered)
	target_detector.body_exited.connect(_on_target_body_exited)
	_refresh_target()


func _setup_direction_checks() -> void:
	if is_instance_valid(front_ray):
		front_ray.collision_mask = CombatLayers.ENEMY_FRONT_OBSTACLE_MASK
	if is_instance_valid(ground_ray):
		ground_ray.collision_mask = CombatLayers.WORLD


func _refresh_direction_checks() -> void:
	for ray: RayCast3D in [front_ray, ground_ray]:
		if is_instance_valid(ray) and ray.enabled:
			ray.force_raycast_update()


func _refresh_target() -> void:
	# Disabling the detector during death can still deliver a queued body_exited callback.
	if dead or not is_instance_valid(target_detector) or not target_detector.monitoring:
		return
	var nearest_target: Node3D = null
	var nearest_distance := INF
	for body: Node3D in target_detector.get_overlapping_bodies():
		if not _is_target_candidate(body):
			continue
		var distance := global_position.distance_squared_to(body.global_position)
		if distance < nearest_distance:
			nearest_target = body
			nearest_distance = distance
	set_target(nearest_target)


func _is_target_candidate(candidate: Node3D) -> bool:
	return candidate != self and candidate.is_in_group(target_group)


func _on_target_body_entered(body: Node3D) -> void:
	if _is_target_candidate(body):
		_refresh_target()


func _on_target_body_exited(body: Node3D) -> void:
	if body == target:
		_refresh_target()


func _on_damaged(applied_hp: float) -> void:
	damaged.emit(applied_hp)
	if hp.is_alive():
		_notify_hit()


func _on_hp_changed(_current_hp: float, _maximum_hp: float) -> void:
	_update_debug_health()


func _update_debug_health() -> void:
	if not is_instance_valid(debug_health_label):
		return
	debug_health_label.visible = show_debug_health
	if not is_instance_valid(hp):
		return
	debug_health_label.text = (
		"HP: %s / %s" % [String.num(hp.current_hp, 2), String.num(hp.get_max_hp(), 2)]
	)


func _get_hit_direction(source: Node) -> Vector3:
	if not source is Node3D:
		return Vector3.ZERO
	var direction := global_position - (source as Node3D).global_position
	direction.y = 0.0
	if direction.is_zero_approx():
		return -last_facing_direction
	return direction.normalized()


func _on_charm_grapple_finished() -> void:
	_charm_grapple_tween = null


# drop itemmm =========
func _drop_loot() -> void:
	if data == null or data.drop_item == null or data.drop_quantity <= 0:
		return

	if data.drop_chance <= 0.0:
		return
	if data.drop_chance < 1.0 and randf() >= data.drop_chance:
		return
	if not is_inside_tree():
		return
	var loot_parent: Node = get_parent()
	if loot_parent == null or loot_parent.is_queued_for_deletion():
		return

	var pickup := ITEM_PICKUP_SCENE.instantiate() as ItemPickup
	# gán trước add_child để _ready của pickup lấy đúng icon
	pickup.item = data.drop_item
	pickup.quantity = data.drop_quantity
	loot_parent.add_child(pickup)
	pickup.global_position = global_position
	pickup.play_drop_animation()
