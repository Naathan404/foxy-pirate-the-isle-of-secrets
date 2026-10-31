extends SceneTree

const ENEMY_CONFIGS := [
	{
		"label": "Crab",
		"scene": preload("res://gameplay/enemies/crab/crab.tscn"),
		"type": "crab",
		"detector_radius": -1.0,
	},
	{
		"label": "EliteCrab",
		"scene": preload("res://gameplay/enemies/crab/elite_crab.tscn"),
		"type": "elite_crab",
		"detector_radius": 6.7,
	},
	{
		"label": "Starfish",
		"scene": preload("res://gameplay/enemies/starfish/starfish.tscn"),
		"type": "starfish",
		"detector_radius": 6.7,
	},
	{
		"label": "EliteStarfish",
		"scene": preload("res://gameplay/enemies/starfish/elite_starfish.tscn"),
		"type": "elite_starfish",
		"detector_radius": 10.1,
	},
	{
		"label": "Barrel",
		"scene": preload("res://gameplay/enemies/barrel/barrel.tscn"),
		"type": "barrel",
		"detector_radius": 6.5,
	},
	{
		"label": "EliteBarrel",
		"scene": preload("res://gameplay/enemies/barrel/elite_barrel.tscn"),
		"type": "elite_barrel",
		"detector_radius": 9.8,
	},
	{
		"label": "WarLordTurtle",
		"scene": preload("res://gameplay/enemies/war_lord_turtle/war_lord_turtle.tscn"),
		"type": "war_lord_turtle",
		"detector_radius": -1.0,
	},
]

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for config: Dictionary in ENEMY_CONFIGS:
		await _check_enemy(config)
	if not _failures.is_empty():
		for failure: String in _failures:
			push_error(failure)
		quit(1)
		return
	print("Enemy configuration scenarios passed")
	quit(0)


func _check_enemy(config: Dictionary) -> void:
	var enemy := (config["scene"] as PackedScene).instantiate() as EnemyBase
	root.add_child(enemy)
	await process_frame
	await physics_frame
	var label := config["label"] as String
	_check(
		_has_expected_root_script(enemy, config["type"] as String), label + ": root script mismatch"
	)
	_check(
		(enemy.collision_mask & CombatLayers.ENEMY_BODY) != 0,
		label + ": enemy body must collide with other enemies"
	)
	if enemy.front_ray.enabled:
		_check(
			(enemy.front_ray.collision_mask & CombatLayers.ENEMY_BODY) != 0,
			label + ": front ray must detect other enemies"
		)
	var expected_radius := config["detector_radius"] as float
	if expected_radius >= 0.0:
		var collision := (
			enemy.get_node_or_null("TargetDetector/CollisionShape3D") as CollisionShape3D
		)
		var shape: CylinderShape3D
		if collision != null:
			shape = collision.shape as CylinderShape3D
		_check(
			shape != null and is_equal_approx(shape.radius, expected_radius),
			label + ": player detection radius was not configured"
		)
		var updated_radius := expected_radius + 0.4
		enemy.set("player_detection_radius", updated_radius)
		_check(
			shape != null and is_equal_approx(shape.radius, updated_radius),
			label + ": player detection radius did not update its collision"
		)
	if enemy is EliteStarfish:
		var patrol := enemy.get_node_or_null("States/Patrol") as EnemyPatrol
		_check(
			patrol != null and patrol.use_random_axis_changes, label + ": patrol axis setting lost"
		)
	if enemy is EliteBarrel:
		var elite_barrel := enemy as EliteBarrel
		_check(
			(
				elite_barrel.scattershot_bullet_count == 5
				and is_equal_approx(elite_barrel.scattershot_arc_degrees, 50.0)
			),
			label + ": scattershot configuration mismatch"
		)
	if enemy is Starfish and not (enemy is EliteStarfish):
		await _check_starfish_abandons_unreachable_target(enemy as Starfish)
	enemy.queue_free()
	await process_frame


func _check_starfish_abandons_unreachable_target(starfish: Starfish) -> void:
	var target := Node3D.new()
	root.add_child(target)
	starfish.set_target(target)
	var attack := starfish.get_node_or_null("States/Attack") as StarfishAttack
	attack._abandon_unreachable_dash()
	var patrol := starfish.get_node_or_null("States/Patrol") as StarfishPatrol
	_check(not starfish.has_target(), "Starfish: unreachable dash must clear the player target")
	_check(
		starfish.target_detector != null and not starfish.target_detector.monitoring,
		"Starfish: unreachable dash must suspend player detection"
	)
	_check(
		patrol != null and patrol._unreachable_target_remaining > 0.0,
		"Starfish: unreachable dash must start patrol cooldown"
	)
	target.queue_free()
	await process_frame


func _has_expected_root_script(enemy: EnemyBase, expected_type: String) -> bool:
	match expected_type:
		"crab":
			return enemy is Crab and not (enemy is EliteCrab)
		"elite_crab":
			return enemy is EliteCrab
		"starfish":
			return enemy is Starfish and not (enemy is EliteStarfish)
		"elite_starfish":
			return enemy is EliteStarfish
		"barrel":
			return enemy is Barrel and not (enemy is EliteBarrel)
		"elite_barrel":
			return enemy is EliteBarrel
		"war_lord_turtle":
			return enemy is WarLordTurtle
	return false


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
