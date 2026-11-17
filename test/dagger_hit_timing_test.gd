extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var actor := Node3D.new()
	var target := Node3D.new()
	holder.add_child(actor)
	holder.add_child(target)
	var attack := load("res://gameplay/weapons/attack scenes/dagger_attack.tscn").instantiate() as DaggerAttack
	holder.add_child(attack)
	var hitstop := root.get_node("HitstopController")
	for i in range(4):
		hitstop.cancel()
		attack._impact_played = false
		var context := AttackContext.new()
		context.actor = actor
		context.combo_step = MeleeComboStep.new()
		context.combo_step.hitstop_seconds = 0.1
		attack.context = context
		attack._on_damage_applied(DamageContext.new(), target, 1.0)
		if hitstop.is_frozen(actor) or not hitstop.is_frozen(target) or Engine.time_scale != 1.0:
			push_error("Dagger hit must preserve attacker timing while retaining target hitstop")
			quit(1)
			return
	hitstop.cancel()
	holder.queue_free()
	await process_frame
	print("Dagger hit timing: passed")
	quit(0)
