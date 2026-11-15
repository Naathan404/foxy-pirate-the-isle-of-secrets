extends SceneTree
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func run() -> void:
	for index in range(11):
		var scene := load("res://world/biomes/hub/map/room_%02d.tscn" % index) as PackedScene
		check(scene != null, "Hub scene loads")
		var room := scene.instantiate()
		root.add_child(room)
		await process_frame
		check(room.has_node("RoomAtmosphere/Overlay/WindAndLeaves"), "Hub inherits atmosphere")
		check(
			(
				room.get_node("RoomAtmosphere/Overlay/Vintage").mouse_filter
				== Control.MOUSE_FILTER_IGNORE
			),
			"Overlay ignores input"
		)
		check(
			not room.get_node("Foxy/Effects/EnvironmentAtmosphere").ambient_enabled,
			"No duplicated ambient"
		)
		check(room.get_node("Foxy/Effects/EnvironmentAtmosphere").water_enabled, "Water retained")
		if index == 2:
			var light := room.get_node("Campfire/FireLight") as OmniLight3D
			var first := light.light_energy
			for frame in range(30):
				light._process(0.05)
				check(light.light_energy > 0.0, "Fire stays lit")
			check(not is_equal_approx(first, light.light_energy), "Fire flickers")
			if DisplayServer.get_name() != "headless":
				for frame in range(60):
					await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://test/hub_atmosphere_preview.png")
		room.queue_free()
		await process_frame
	print("Hub atmosphere: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
