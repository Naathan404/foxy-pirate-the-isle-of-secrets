extends SceneTree
const PLAYER_SCENE: PackedScene = preload("res://gameplay/player/foxy.tscn")
const DUMMY_SCENE: PackedScene = preload("res://world/biomes/hub/objects/training_dummy.tscn")
var failures := 0


func _initialize() -> void:
	call_deferred("run_test")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func run_test() -> void:
	var arena := Node3D.new()
	root.add_child(arena)
	var player := PLAYER_SCENE.instantiate() as Player
	arena.add_child(player)
	var dummy := DUMMY_SCENE.instantiate() as DestructibleProp
	arena.add_child(dummy)
	await process_frame
	var weapon := player.weapon_controller.equipped
	check(weapon != null and weapon.get_chaos_gain() > 0.0, "equipped weapon has chaos gain")
	var damage := DamageContext.new()
	damage.source = player
	damage.source_team = CombatTeams.PLAYER
	damage.amount_hp = 2.0
	player.chaos._idle_remaining = 0.0
	var applied := dummy.receive_damage(damage)
	check(player.chaos._idle_remaining > 0.0, "dummy hit counts as combat activity")
	player.weapon_controller._on_damage_applied(
		damage,
		dummy,
		applied,
		weapon,
		weapon.get_chaos_gain(),
		player.weapon_controller._equip_revision
	)
	check(
		is_equal_approx(player.chaos.current, weapon.get_chaos_gain()),
		"confirmed dummy hit grants equipped weapon chaos"
	)
	var previous := player.chaos.current
	player.weapon_controller._on_damage_applied(
		damage,
		dummy,
		applied,
		weapon,
		weapon.get_chaos_gain(),
		player.weapon_controller._equip_revision - 1
	)
	check(is_equal_approx(player.chaos.current, previous), "stale projectiles do not grant chaos")
	var other := Node3D.new()
	arena.add_child(other)
	damage.chaos_gain = weapon.get_chaos_gain()
	player._on_weapon_damage_dealt(damage, other, applied)
	check(is_equal_approx(player.chaos.current, previous), "ordinary scenery does not grant chaos")
	arena.queue_free()
	await process_frame
	print("Training dummy chaos tests: ", "passed" if failures == 0 else "failed")
	quit(0 if failures == 0 else 1)
