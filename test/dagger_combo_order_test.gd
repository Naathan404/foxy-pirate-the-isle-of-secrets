extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var dagger := load("res://data/weapon/weapon_dagger.tres") as WeaponData
	assert(dagger != null and dagger.normal_attack != null)
	var steps := dagger.normal_attack.combo_steps
	assert(steps.size() == 4, "Dagger combo must have exactly four attacks")
	assert(steps[0] != steps[2], "Third attack must have independent settings")
	assert(is_equal_approx(steps[0].active_seconds, steps[2].active_seconds))
	var original_damage := steps[0].damage_multiplier
	steps[2].damage_multiplier = original_damage + 1.0
	assert(is_equal_approx(steps[0].damage_multiplier, original_damage))
	assert(steps[3].straight_thrust and steps[3].heavy_impact)
	assert(is_equal_approx(steps[3].damage_multiplier, 2.0))
	assert(is_equal_approx(steps[0].shake_pixels, 9.5))
	assert(is_equal_approx(steps[3].shake_pixels, 12.0))
	var attack_scene := dagger.normal_attack.attack_scene.instantiate() as DaggerAttack
	assert(attack_scene != null and attack_scene.hitbox != null)
	assert(is_equal_approx(attack_scene.swing_width, 0.42))
	assert(is_equal_approx(attack_scene.thrust_width, 0.62))
	attack_scene.free()
	var preview_script := load("res://gameplay/player/spine_idle_preview.gd") as GDScript
	var animations: Array = preview_script.get_script_constant_map()["DAGGER_COMBO_ANIMATIONS"]
	assert(animations == ["Attack_1", "Attack_2", "Attack_1", "Attack_3"])
	print("dagger_combo_order_test: PASS")
	quit()
