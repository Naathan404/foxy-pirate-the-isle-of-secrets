extends SceneTree
const DUMMY: PackedScene = preload("res://world/biomes/hub/objects/training_dummy.tscn")
const ARROW: PackedScene = preload("res://gameplay/weapons/attack scenes/bow_arrow.tscn")
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
	var dummy := DUMMY.instantiate() as DestructibleProp
	arena.add_child(dummy)
	dummy.position = Vector3(0, 0, -4)
	var health := dummy.get_node("HealthComponent") as HealthComponent
	var starting_hp := health.current_hp
	var damage := DamageContext.new()
	damage.source_team = CombatTeams.PLAYER
	damage.amount_hp = 1000000.5
	check(dummy.receive_damage(damage) == damage.amount_hp, "dummy reports full damage even beyond its health")
	damage.amount_hp = 2.5
	damage.is_critical = true
	check(dummy.receive_damage(damage) == 2.5, "dummy accepts repeated critical damage")
	check(health.current_hp == starting_hp and not dummy._destroyed, "dummy health and lifetime do not decrease")
	check(dummy._hurtbox.enabled and not dummy._movement_shape.disabled, "dummy remains hittable and solid")
	var popups: Array[Label3D] = []
	for child in arena.get_children():
		if child is Label3D:
			popups.append(child)
	check(popups.size() == 2, "normal and critical hits create popups")
	if popups.size() == 2:
		check(popups[0].text == "1000000.5" and popups[1].text == "2.5", "popups display actual damage")
		check(popups[0].global_position.y > dummy.global_position.y + 3.0, "popup appears above dummy")
		check(popups[0].modulate == popups[1].modulate, "high damage and critical use emphasized popup")
	damage.amount_hp = -5
	check(dummy.receive_damage(damage) == 0.0, "invalid damage is ignored")
	var hitbox := HitBox.new()
	arena.add_child(hitbox)
	var attack := DamageContext.new()
	attack.source = arena
	attack.source_team = CombatTeams.PLAYER
	attack.base_amount_hp = 7.25
	attack.amount_hp = 7.25
	var confirmed := [0.0]
	hitbox.damage_applied.connect(func(_damage, _target, amount): confirmed[0] = amount)
	check(hitbox.begin_attack_with_context(attack), "weapon hitbox starts")
	hitbox.try_hit(dummy._hurtbox)
	check(is_equal_approx(confirmed[0], 7.25), "weapon hitbox confirms the dummy hit")
	check(health.current_hp == starting_hp, "weapon hit does not reduce dummy health")
	var arrow := ARROW.instantiate()
	arena.add_child(arrow)
	arrow.context = AttackContext.new()
	arrow.context.range_units = 10.0
	check(arrow._find_homing_target() == dummy, "Stormstring can target a dummy in front")
	dummy.position = Vector3(0, 0, 4)
	check(arrow._find_homing_target() == null, "Stormstring still ignores targets behind the arrow")
	arena.queue_free()
	await process_frame
	print("Training dummy tests: ", "passed" if failures == 0 else "failed")
	quit(0 if failures == 0 else 1)
