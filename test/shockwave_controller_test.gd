extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var wave := root.get_node("ShockwaveController")
	wave.request_screen(Vector2(300, 200), 0.08, 0.02)
	assert(wave._rect.visible and wave.is_processing(), "screen request starts the wave")
	var size := root.get_visible_rect().size
	var center := Vector2(300, 200) / size
	var corner := Vector2((1.0 - center.x) * size.x / size.y, 1.0 - center.y)
	assert(float(wave._material.get_shader_parameter("max_radius")) > corner.length(), "wave reaches the far corner")
	paused = true
	assert(wave.can_process(), "wave continues processing while paused")
	wave._started_usec = Time.get_ticks_usec() - 150000
	wave._process(0.0)
	assert(not wave._rect.visible and not wave.is_processing(), "wave ends while paused")
	paused = false
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.make_current()
	wave.request_world(Vector3(0, 0, -5), 0.4, 0.02)
	assert(wave._rect.visible, "world request starts the wave")
	wave.cancel()
	assert(not wave._rect.visible, "cancel hides the wave")
	camera.queue_free()
	await process_frame
	print("Shockwave controller: passed")
	quit(0)
