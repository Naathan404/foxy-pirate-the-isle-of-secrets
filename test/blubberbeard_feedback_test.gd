extends SceneTree

const BOSS_SCENE := preload("res://gameplay/bosses/blubberbeard/blubberbeard.tscn")
const EXPLOSION := preload("res://gameplay/bosses/blubberbeard/powder_explosion_vfx.tscn")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arena := Node3D.new()
	root.add_child(arena)
	current_scene = arena
	var player := Node3D.new()
	player.add_to_group("player")
	player.position = Vector3(8, 0, 0)
	arena.add_child(player)
	var camera := Camera3D.new()
	player.add_child(camera)
	camera.fov = 30.0
	camera.make_current()
	var boss := BOSS_SCENE.instantiate() as BossBase
	arena.add_child(boss)
	boss.set_physics_process(false)
	boss.start_fight(player)
	var behavior := boss.behavior as BlubberbeardBehavior
	var feedback := behavior.feedback
	await create_timer(0.75).timeout
	_check(is_equal_approx(camera.fov, feedback.fight_camera_fov), "Fight camera did not zoom out")
	behavior.skill = boss.boss_data.phases[0].skills[0] as BlubberbeardSkillData
	behavior._spawn_barrel(Vector3(5, 0, 0))
	var hazard: Node3D
	for node in arena.get_children():
		if node.get_script() == behavior.HAZARD:
			hazard = node as Node3D
	_check(hazard != null, "Barrel hazard not created")
	if hazard != null:
		hazard._physics_process(behavior.skill.windup + 0.1)
	var effect := arena.get_node_or_null("PowderExplosionVFX") as Node3D
	_check(
		effect != null and effect.scene_file_path == EXPLOSION.resource_path,
		"Explosion VFX not spawned"
	)
	if effect != null:
		var sprite := effect.get_node("Explosion") as AnimatedSprite3D
		_check(sprite.sprite_frames.get_frame_count(&"explode") == 4, "Explosion needs four frames")
		_check(sprite.is_playing(), "Explosion animation did not start")
	feedback.charge_start()
	feedback.charge_tick(0.1)
	_check(arena.get_node_or_null("BossChargeAfterimage") != null, "Charge afterimage not spawned")
	feedback.phase_changed()
	_check(feedback.aura.emitting, "Phase 2 ember aura not started")
	_check(feedback.flash.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Impact flash blocks input")
	feedback.death()
	_check(not feedback.aura.emitting, "Ember aura did not stop on death")
	await create_timer(1.2).timeout
	_check(not is_instance_valid(effect), "Explosion effect did not clean itself up")
	_check(is_equal_approx(camera.fov, 30.0), "Fight camera did not restore its FOV")
	root.get_node("AudioManager").stop_all_sfx()
	behavior.sound.stop()
	arena.queue_free()
	await process_frame
	if failures.is_empty():
		print("Blubberbeard feedback test passed")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
