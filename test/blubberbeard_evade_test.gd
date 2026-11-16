extends SceneTree

const BOSS_SCENE := preload("res://gameplay/bosses/blubberbeard/blubberbeard.tscn")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arena := Node3D.new()
	root.add_child(arena)
	current_scene = arena
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = CombatLayers.WORLD
	var floor_collider := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(100.0, 1.0, 100.0)
	floor_collider.shape = floor_shape
	floor_body.add_child(floor_collider)
	floor_body.position.y = -0.5
	arena.add_child(floor_body)
	var player := Node3D.new()
	player.position = Vector3(8, 0, 0)
	player.add_to_group("player")
	arena.add_child(player)
	var boss := BOSS_SCENE.instantiate() as BlubberbeardBoss
	arena.add_child(boss)
	boss.start_fight(player)
	var behavior := boss
	behavior.timer = 10.0
	for i in 5:
		await physics_frame
	var start := boss.global_position
	var damage := DamageContext.new()
	damage.source = player
	damage.source_team = CombatTeams.PLAYER
	damage.amount_hp = 0.1
	var hp_before := boss.hp.current_hp
	for hit in 2:
		_check(is_equal_approx(boss.receive_damage(damage), 0.1), "Hurt hit did not deal damage")
		_check(behavior._evade_remaining <= 0.0, "Evade began before configured hurt hits")
		_check(behavior.visual.texture == behavior.visual.HIT_DEATH_SHEET, "Hurt sprite not active")
	_check(behavior._hits_since_evade == 2, "Hurt hits were not counted")
	_check(is_equal_approx(boss.receive_damage(damage), 0.1), "The triggering hit must deal damage")
	_check(behavior._evade_remaining > 0.0, "Hit did not start evasive hop")
	_check(behavior._hits_since_evade == 0, "Evade did not reset the hit count")
	var deflate_textures := [
		behavior.visual.DEFLATE_FRONT,
		behavior.visual.DEFLATE_SIDE,
		behavior.visual.DEFLATE_BACK,
	]
	_check(behavior.visual.texture in deflate_textures, "Deflation sprite not active")
	_check(behavior._evade_steam.emitting, "Deflation steam did not start")
	var visual := behavior.visual
	var duration: float = visual._evade_clip_duration
	visual.face_direction(Vector3.BACK)
	_check(visual.texture == visual.DEFLATE_FRONT, "Front deflation view missing")
	visual.face_direction(Vector3.FORWARD)
	_check(visual.texture == visual.DEFLATE_BACK, "Back deflation view missing")
	visual.face_direction(Vector3.RIGHT)
	_check(visual.texture == visual.DEFLATE_SIDE and not visual.flip_h, "Right deflation view missing")
	visual.face_direction(Vector3.LEFT)
	_check(visual.texture == visual.DEFLATE_SIDE and visual.flip_h, "Left deflation view missing")
	visual._evade_clip_left = duration * 0.9
	visual._update_active_frame()
	var starting_frame: int = visual.frame
	visual._evade_clip_left = duration * 0.5
	visual._update_active_frame()
	var deflated_frame: int = visual.frame
	visual._evade_clip_left = duration * 0.05
	visual._update_active_frame()
	var reinflating_frame: int = visual.frame
	_check(deflated_frame > starting_frame, "Deflation did not advance through frames")
	_check(reinflating_frame > deflated_frame, "Reinflation did not advance through its own frames")
	visual._evade_clip_left = duration
	visual._update_active_frame()
	_check(boss.receive_damage(damage) == 0.0, "Boss took damage while evading")
	_check(is_equal_approx(boss.hp.current_hp, hp_before - 0.3), "Evade immunity did not preserve HP")
	for i in 10:
		await physics_frame
	_check(not behavior._evade_launched, "Boss moved before deflating")
	_check(boss.global_position.distance_to(start) < 0.2, "Boss moved during deflation")
	var max_y := start.y
	var launch_speed := 0.0
	var late_speed := -1.0
	for i in 88:
		await physics_frame
		max_y = maxf(max_y, boss.global_position.y)
		if behavior._evade_launched and launch_speed == 0.0:
			launch_speed = behavior._evade_horizontal_velocity.length()
		if behavior.EVADE_DURATION - behavior._evade_remaining > 1.1 and late_speed < 0.0:
			late_speed = behavior._evade_horizontal_velocity.length()
	_check(launch_speed > 10.0, "Evade did not launch quickly")
	_check(late_speed >= 0.0 and late_speed < launch_speed * 0.5, "Air drag did not slow the evade")
	_check(behavior._evade_bounced, "Boss did not bounce on landing")
	var inhale_start := boss.global_position
	_check(not behavior._evade_steam.emitting, "Steam continued while reinflating")
	for i in 12:
		await physics_frame
	var inhale_delta := boss.global_position - inhale_start
	_check(
		Vector2(inhale_delta.x, inhale_delta.z).length() < 0.2,
		"Boss kept flying during reinflation"
	)
	for i in 15:
		await physics_frame
	_check(max_y > start.y + 0.3, "Evade did not jump")
	var displacement := boss.global_position - start
	_check(Vector2(displacement.x, displacement.z).length() > 1.0, "Evade did not move away")
	_check(behavior._evade_remaining <= 0.0, "Evade did not finish")
	_check(not behavior._evade_steam.emitting, "Deflation steam continued after evasion")
	_check(is_equal_approx(boss.receive_damage(damage), 0.1), "Boss stayed immune after evading")
	_check(behavior._evade_remaining <= 0.0, "Cooldown allowed an immediate second evade")
	_check(behavior._hits_since_evade == 1, "Cooldown hit was not counted")
	behavior.hits_before_evade = 3
	behavior._evade_cooldown_left = 0.0
	behavior.state = BlubberbeardBoss.State.CHARGE
	behavior.visual.begin_charge(Vector3.RIGHT)
	behavior.charge_hitbox.begin_attack(5.0, 0, &"test_charge")
	for hit in 2:
		_check(
			is_equal_approx(boss.receive_damage(damage), 0.1),
			"A hit during charge did not deal damage"
		)
		_check(behavior._evade_remaining <= 0.0, "Evade ignored the configured hit count")
		_check(
			behavior.visual.texture == behavior.visual.HIT_DEATH_SHEET,
			"Hurt sprite missing during charge"
		)
		behavior.visual._process(behavior.visual.HURT_FLASH_DURATION + 0.01)
		_check(behavior.visual._hit_clip_left <= 0.0, "Hurt hid the charge animation for too long")
	_check(
		is_equal_approx(boss.receive_damage(damage), 0.1),
		"The next hit during charge did not deal damage"
	)
	_check(behavior._evade_remaining > 0.0, "A hit during charge did not start evasion")
	_check(not behavior.charge_hitbox.is_active(), "Charge hitbox stayed active during evasion")
	arena.queue_free()
	await process_frame
	await _check_wall_bounce()
	if failures.is_empty():
		print("Blubberbeard evade test passed")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_wall_bounce() -> void:
	var arena := Node3D.new()
	root.add_child(arena)
	current_scene = arena
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = CombatLayers.WORLD
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(100.0, 1.0, 100.0)
	var floor_collider := CollisionShape3D.new()
	floor_collider.shape = floor_shape
	floor_body.position.y = -0.5
	floor_body.add_child(floor_collider)
	arena.add_child(floor_body)
	var wall := StaticBody3D.new()
	wall.collision_layer = CombatLayers.WORLD
	var wall_shape := BoxShape3D.new()
	wall_shape.size = Vector3(0.5, 12.0, 100.0)
	var wall_collider := CollisionShape3D.new()
	wall_collider.shape = wall_shape
	wall.position = Vector3(-6.0, 5.0, 0.0)
	wall.add_child(wall_collider)
	arena.add_child(wall)
	var player := Node3D.new()
	player.position = Vector3(8, 0, 0)
	player.add_to_group("player")
	arena.add_child(player)
	var boss := BOSS_SCENE.instantiate() as BlubberbeardBoss
	arena.add_child(boss)
	boss.start_fight(player)
	var behavior := boss
	behavior.hits_before_evade = 0
	behavior.timer = 10.0
	for i in 5:
		await physics_frame
	var damage := DamageContext.new()
	damage.source = player
	damage.source_team = CombatTeams.PLAYER
	damage.amount_hp = 0.1
	boss.receive_damage(damage)
	var reflected := false
	var nearest_x := boss.global_position.x
	for i in 85:
		await physics_frame
		nearest_x = minf(nearest_x, boss.global_position.x)
		if behavior._evade_horizontal_velocity.x > 0.1:
			reflected = true
	_check(reflected, "Boss did not bounce back from the wall")
	_check(nearest_x > -4.0, "Boss crossed the wall while evading")
	arena.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
