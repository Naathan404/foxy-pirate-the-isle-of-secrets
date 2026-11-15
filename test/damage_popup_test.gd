extends SceneTree
const CONFIG = preload("res://gameplay/combat/damage_popup_config.tres")
const DAGGER = preload("res://data/weapon/weapon_dagger.tres")
const DUMMY = preload("res://world/biomes/hub/objects/training_dummy.tscn")
const ENEMY = preload("res://gameplay/enemies/starfish/starfish.tscn")
var failures := 0

func _initialize() -> void:
	call_deferred("run_test")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func run_test() -> void:
	var normal := DamageContext.new()
	var critical := DamageContext.new()
	critical.is_critical = true
	check(not CONFIG.is_emphasized(normal, CONFIG.high_damage_threshold - 0.01), "ordinary damage uses normal style")
	check(CONFIG.is_emphasized(normal, CONFIG.high_damage_threshold), "damage threshold is inclusive")
	check(CONFIG.is_emphasized(critical, 1.0), "critical damage is emphasized regardless of amount")
	var steps := DAGGER.normal_attack.combo_steps
	var attack := AttackContext.new()
	attack.combo_step = steps.back()
	var finisher := attack.create_damage_context().create_hit_copy()
	check(finisher.emphasize_popup and CONFIG.is_emphasized(finisher, 1.0), "dagger finisher keeps authored emphasis through hit snapshot")
	attack.combo_step = steps.front()
	check(not attack.create_damage_context().create_hit_copy().emphasize_popup, "ordinary combo step is not marked")
	var arena := Node3D.new()
	root.add_child(arena)
	var dummy := DUMMY.instantiate() as DestructibleProp
	arena.add_child(dummy)
	var enemy := ENEMY.instantiate() as EnemyBase
	arena.add_child(enemy)
	var damage := DamageContext.new()
	damage.source_team = CombatTeams.PLAYER
	damage.amount_hp = 1.0
	dummy.receive_damage(damage)
	damage.emphasize_popup = true
	dummy.receive_damage(damage)
	enemy.receive_damage(damage)
	var popups: Array[Label3D] = []
	for node in arena.get_children():
		if node is Label3D:
			popups.append(node)
	check(popups.size() == 3, "dummy and enemy both create damage popups")
	if popups.size() == 3:
		check(popups[1].font_size > popups[0].font_size, "emphasized number is larger")
		check(popups[1].modulate.r > popups[1].modulate.g, "emphasized number is red")
		check(popups[2].font_size == popups[1].font_size and popups[2].modulate == popups[1].modulate, "enemy and dummy share popup styles")
		check(is_equal_approx(popups[2].pixel_size, popups[1].pixel_size * enemy.damage_popup_size_multiplier), "enemy popup uses configured size multiplier")
		var sprite := enemy.visual.sprite
		var sprite_top := sprite.to_global(Vector3(0, sprite.get_aabb().end.y, 0)).y
		check(popups[2].global_position.y >= sprite_top + enemy.damage_popup_headroom - 0.001, "enemy popup appears above sprite")
	arena.queue_free()
	await process_frame
	print("Damage popup tests: ", "passed" if failures == 0 else "failed")
	quit(0 if failures == 0 else 1)
