extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var audio := root.get_node("AudioManager")
	audio.stop_all_sfx()
	var world := Node3D.new()
	root.add_child(world)
	var player := load("res://gameplay/player/foxy.tscn").instantiate() as Player
	world.add_child(player)
	player.set_physics_process(false)
	var enemy := load("res://gameplay/enemies/starfish/starfish.tscn").instantiate() as EnemyBase
	enemy.data = enemy.data.duplicate()
	enemy.data.max_hp = 20
	enemy.position.x = 3.0
	world.add_child(enemy)
	enemy.set_physics_process(false)
	var player_position := player.global_position
	var player_sprite_position := player.visual.sprite.position
	var enemy_position := enemy.global_position
	var enemy_sprite_position := enemy.visual.sprite.position
	var previous_overlay := StandardMaterial3D.new()
	enemy.visual.sprite.material_overlay = previous_overlay
	var dagger = load("res://gameplay/weapons/attack scenes/dagger_throw.tscn").instantiate()
	world.add_child(dagger)
	var context := AttackContext.new()
	context.actor = player
	context.team = 1
	context.damage_hp = 2
	context.direction = Vector3.RIGHT
	dagger.context = context
	var effect = dagger.get_node("ThrowVFX")
	dagger.activate()
	dagger.set_physics_process(false)
	effect.set_process(false)
	_check(player.visual.sprite.position.x < player_sprite_position.x, "Release recoils sprite")
	_check(player.global_position == player_position, "Release keeps Player body position")
	_check(Engine.time_scale < 1.0, "Release requests a short hitstop")
	var throw_voice: AudioStreamPlayer3D = audio._spatial_pool[0]
	_check(throw_voice.stream == effect.THROW_SOUND, "Release plays whoosh through AudioManager")
	_check(
		(
			throw_voice.max_distance
			> player.camera.global_position.distance_to(player.global_position)
		),
		"Combat audio reaches the elevated gameplay camera"
	)
	var release = player.visual.sprite.get_node("DaggerFeedback")
	release._pose_tween.pause()
	release._pose_tween.custom_step(0.25)
	_check(player.visual.sprite.position == player_sprite_position, "Release pose recovers")
	root.get_node("HitstopController").cancel()
	var cuts_before: int = effect._next_cut
	dagger._on_hit_confirmed(DamageContext.new(), enemy, 0)
	_check(effect._next_cut == cuts_before, "Zero damage does not play impact")
	_check(not enemy.visual.sprite.has_node("DaggerFeedback"), "Zero damage has no flash")
	var hp_before: int = enemy.hp.current_hp
	dagger.hit_area._on_area_entered(enemy.hurtbox)
	_check(enemy.hp.current_hp == hp_before - 2, "Impact still applies exactly authored damage")
	_check(enemy.global_position == enemy_position, "Visual recoil does not teleport enemy")
	_check(effect._next_cut != cuts_before, "Confirmed damage emits directional cut")
	_check(Engine.time_scale < 1.0, "Real hitbox signal activates impact hitstop")
	var reaction = enemy.visual.sprite.get_node("DaggerFeedback")
	_check(enemy.visual.sprite.position.x > enemy_sprite_position.x, "Outbound hit kicks right")
	_check(enemy.visual.sprite.material_overlay == reaction._flash_material, "White flash overlay")
	_check(
		(
			reaction._flash_material.get_shader_parameter("sprite_texture")
			== enemy.visual.sprite.texture
		),
		"Flash follows current atlas texture"
	)
	_check(effect._cut_directions[cuts_before].x > 0.0, "Cut follows outgoing direction")
	var cut_at: Vector3 = effect._cuts[cuts_before].global_position
	_check(cut_at.x > 2.0, "Impact is anchored to enemy rather than projectile center")
	var node_count: int = enemy.visual.sprite.get_child_count()
	# Return pass hits again, then deduplicates repeat overlap in that pass.
	dagger.position.x = 4.0
	dagger._begin_return()
	dagger.hit_area._on_area_entered(enemy.hurtbox)
	_check(enemy.hp.current_hp == hp_before - 4, "Return pass still deals damage once")
	_check(enemy.visual.sprite.position.x < enemy_sprite_position.x, "Return hit kicks left")
	dagger.hit_area._on_area_entered(enemy.hurtbox)
	_check(enemy.hp.current_hp == hp_before - 4, "Repeated overlap is deduplicated")
	_check(enemy.visual.sprite.get_child_count() == node_count, "Return hit reuses feedback")
	paused = true
	_check(not reaction.can_process(), "Flash respects inventory pause")
	paused = false
	reaction._pose_tween.pause()
	reaction._pose_tween.custom_step(0.3)
	reaction._flash_tween.pause()
	reaction._flash_tween.custom_step(0.2)
	_check(enemy.visual.sprite.position == enemy_sprite_position, "Enemy pose fully recovers")
	_check(enemy.visual.sprite.material_overlay == previous_overlay, "Existing overlay restored")
	dagger.free()
	effect._process(0.5)
	_check(effect.is_queued_for_deletion(), "Impact pool cleans up independently of shared audio")
	audio.stop_all_sfx()
	root.get_node("HitstopController").cancel()
	root.get_node("ScreenShakeController").cancel()
	world.free()
	if _failures == 0:
		print(
			"Dagger release recoil, real hitstop, target flash, return direction and audio passed"
		)
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
