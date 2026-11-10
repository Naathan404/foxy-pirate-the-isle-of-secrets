class_name EliteCrab
extends Crab

const EGG_SCENE := preload("res://gameplay/enemies/crab/crab_egg.tscn")
const SPAWN_ATTEMPTS_PER_EGG := 20

@export_group("Elite Crab Eggs")
@export_range(0, 12, 1) var egg_count_min: int = 2
@export_range(0, 12, 1) var egg_count_max: int = 4
@export_range(1.5, 15.0, 0.1, "suffix:m") var egg_scatter_radius: float = 4.0
@export_range(0.1, 3.0, 0.05, "suffix:s") var egg_flight_duration: float = 0.8
@export_range(0.0, 8.0, 0.1, "suffix:m") var egg_arc_height: float = 2.0
@export_range(0.5, 5.0, 0.1, "suffix:m") var egg_min_spacing: float = 1.8
@export_range(0.0, 30.0, 0.1, "suffix:s") var egg_hatch_delay: float = 2.0
@export_range(0.0, 10.0, 0.1, "suffix:s") var egg_warning_duration: float = 0.7
@export_range(0.0, 1.0, 0.01, "suffix:m") var egg_shake_distance: float = 0.08
@export_range(0.0, 50.0, 0.5, "suffix:Hz") var egg_shake_frequency: float = 15.0

var egg_spawn_used: bool = false
var _egg_spawn_pending: bool = false


func receive_damage(damage: DamageContext) -> float:
	var applied := super(damage)
	if (
		applied > 0.0 and not dead and hp.is_alive() and not egg_spawn_used
		and hp.current_hp <= hp.get_max_hp() * 0.5
	):
		egg_spawn_used = true
		_egg_spawn_pending = true
	return applied


func _physics_process(delta: float) -> void:
	super(delta)
	if dead:
		_egg_spawn_pending = false
		return
	if not _egg_spawn_pending or not is_instance_valid(fsm):
		return
	if (
		(is_instance_valid(fsm.current_state) and fsm.current_state.name == &"Hit")
		or (is_instance_valid(fsm.next_state) and fsm.next_state.name == &"Hit")
	):
		return
	if request_state(&"eggspawn", 20):
		_egg_spawn_pending = false


func launch_eggs() -> int:
	if dead or not is_inside_tree():
		return 0
	var low := clampi(mini(egg_count_min, egg_count_max), 0, 12)
	var high := clampi(maxi(egg_count_min, egg_count_max), 0, 12)
	var desired := randi_range(low, high)
	var positions: Array[Vector3] = []
	for _attempt in range(desired * SPAWN_ATTEMPTS_PER_EGG):
		if positions.size() >= desired:
			break
		var angle := randf_range(0.0, TAU)
		var radius := randf_range(2.5, maxf(2.5, egg_scatter_radius))
		var horizontal := Vector3(cos(angle), 0.0, sin(angle)) * radius
		var candidate := _find_egg_ground(global_position + horizontal)
		if candidate.is_empty():
			continue
		var ground: Vector3 = candidate.position
		var too_close := false
		for existing in positions:
			if existing.distance_to(ground) < egg_min_spacing:
				too_close = true
				break
		if too_close or not _egg_landing_clear(ground):
			continue
		positions.append(ground)
	var parent := get_tree().current_scene
	if not is_instance_valid(parent):
		parent = get_parent()
	if not is_instance_valid(parent):
		return 0
	for ground in positions:
		var egg := EGG_SCENE.instantiate() as CrabEgg
		egg.setup(global_position + Vector3.UP * 1.5, ground, egg_flight_duration, egg_arc_height)
		egg.hatch_delay = egg_hatch_delay
		egg.warning_duration = egg_warning_duration
		egg.shake_distance = egg_shake_distance
		egg.shake_frequency = egg_shake_frequency
		parent.add_child(egg)
	return positions.size()


func _find_egg_ground(position: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(
		position + Vector3.UP * 4.0, position - Vector3.UP * 6.0, CombatLayers.WORLD
	)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)


func _egg_landing_clear(ground: Vector3) -> bool:
	var shape := CylinderShape3D.new()
	shape.radius = 0.85
	shape.height = 1.7
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, ground + Vector3.UP * 0.9)
	query.collision_mask = CombatLayers.WORLD | CombatLayers.ENEMY_BODY | CombatLayers.PLAYER_BODY
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
