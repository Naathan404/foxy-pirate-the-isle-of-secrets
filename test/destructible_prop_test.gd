extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var source := Node3D.new()
	root.add_child(source)
	for index in range(1, 5):
		var scene := load("res://world/biomes/ruins/ruins_grass_%d.tscn" % index) as PackedScene
		assert(scene != null, "Grass scene must load")
		var prop := scene.instantiate() as DestructibleProp
		assert(prop != null, "Grass must inherit DestructibleProp")
		root.add_child(prop)
		assert(prop.max_hp == 1.0)
		assert(prop.drop_item == null and prop.drop_chance == 0.0)
		assert(prop.visual_root == prop.get_node("Visual/Sprite3D"))
		assert(prop.fragment_source == prop.visual_root)
		assert(prop.get_node("HurtBox").actor == prop)
		var damage := DamageContext.new()
		damage.source = source
		damage.source_team = CombatTeams.PLAYER
		damage.amount_hp = 1.0
		assert((prop.get_node("HurtBox") as HurtBox).take_damage(damage) == 1.0)
		assert(not (prop.get_node("HealthComponent") as HealthComponent).is_alive())
		assert(not (prop.get_node("HurtBox") as HurtBox).enabled)
		var flash := (prop.visual_root as Sprite3D).material_overlay as ShaderMaterial
		assert(flash != null and flash.get_shader_parameter("strength") == 1.0, "Destroyed grass should flash")
		var fragments := root.get_child(root.get_child_count() - 1) as DestructibleFragments
		assert(fragments != null and fragments.get_child_count() > 0)
		var first_piece := fragments.get_child(0) as MeshInstance3D
		assert(first_piece != null and first_piece.mesh is ArrayMesh)
		assert((first_piece.material_override as StandardMaterial3D).albedo_texture == prop.fragment_source.texture)
		var start_height := first_piece.position.y
		fragments._process(0.25)
		var raised_height := first_piece.position.y
		assert(raised_height > start_height + 1.0, "Fragments must launch upward")
		fragments._process(0.65)
		assert(first_piece.position.y < raised_height, "Fragments must fall after the arc")
		assert(prop.receive_damage(damage) == 0.0)
		for child in root.get_children():
			assert(not child is ItemPickup, "Grass must not drop items")
		await create_timer(prop.hit_flash_hold_duration + prop.hit_flash_duration + 0.05).timeout
		assert(not is_instance_valid(prop), "Grass should be removed after its flash")
	var durable_scene := load("res://world/biomes/ruins/ruins_grass_1.tscn") as PackedScene
	var durable_prop := durable_scene.instantiate() as DestructibleProp
	durable_prop.max_hp = 2.0
	root.add_child(durable_prop)
	var durable_damage := DamageContext.new()
	durable_damage.source = source
	durable_damage.source_team = CombatTeams.PLAYER
	durable_damage.amount_hp = 1.0
	assert((durable_prop.get_node("HurtBox") as HurtBox).take_damage(durable_damage) == 1.0)
	assert(not durable_prop.is_queued_for_deletion())
	var durable_flash := (durable_prop.visual_root as Sprite3D).material_overlay as ShaderMaterial
	assert(durable_flash != null and durable_flash.get_shader_parameter("strength") == 1.0)
	await create_timer(durable_prop.hit_flash_hold_duration + durable_prop.hit_flash_duration + 0.05).timeout
	assert((durable_prop.visual_root as Sprite3D).material_overlay == null)
	durable_prop.queue_free()
	await process_frame
	source.queue_free()
	print("destructible_prop_test: PASS")
	quit()
