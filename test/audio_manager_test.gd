extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# Keep the headless loop bounded while waiting for the real-time audio mixer.
	Engine.max_fps = 120
	var audio := root.get_node("AudioManager")
	audio.stop_all_sfx()
	var child_count: int = audio.get_child_count()
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = 22050
	var samples := PackedByteArray()
	samples.resize(4410)
	sound.data = samples
	_check(audio.play_sfx(null) == null, "Null SFX is ignored")
	_check(audio.play_sfx_3d(null, Vector3.ZERO) == null, "Null spatial SFX is ignored")
	_check(audio.play_ui(null) == null, "Null UI sound is ignored")
	for bus in [&"Master", &"SFX", &"UI", &"Music"]:
		_check(AudioServer.get_bus_index(bus) >= 0, "Audio bus exists: %s" % bus)
	var source := Node3D.new()
	root.add_child(source)
	source.position = Vector3(2, 1, 3)
	var voice: AudioStreamPlayer3D = audio.play_sfx_3d(sound, source.global_position, -9.0, 1.1)
	source.free()
	_check(is_instance_valid(voice) and voice.get_parent() == audio, "Sound outlives caller")
	_check(voice.global_position == Vector3(2, 1, 3), "Spatial sound stays at requested position")
	_check(voice.bus == &"SFX" and voice.volume_db == -9.0, "Spatial sound uses SFX mix")
	_check(is_equal_approx(voice.pitch_scale, 1.1), "Caller controls pitch")
	_check(voice.unit_size >= 28.0 and voice.max_distance > 28.0, "Top-down camera can hear SFX")
	for repeat in 80:
		audio.play_sfx(sound)
		audio.play_sfx_3d(sound, Vector3(repeat, 0, 0))
		audio.play_ui(sound)
	_check(audio.get_child_count() == child_count, "Full pools reuse nodes instead of growing")
	audio.stop_all_sfx()
	for child in audio.get_children():
		_check(child.stream == null and not child.playing, "Stop releases every voice")
	var gameplay_voice: AudioStreamPlayer = audio.play_sfx(sound)
	paused = true
	_check(audio.can_process(), "Manager is available during inventory pause")
	_check(not gameplay_voice.can_process(), "Gameplay sound pauses with the world")
	_check(audio.play_sfx(sound) == null, "Paused world rejects new flat SFX")
	_check(audio.play_sfx_3d(sound, Vector3.ZERO) == null, "Paused world rejects new spatial SFX")
	var ui_voice: AudioStreamPlayer = audio.play_ui(sound, -5.0)
	_check(ui_voice != null and ui_voice.can_process(), "UI sound plays during inventory pause")
	_check(ui_voice.bus == &"UI", "UI sound has its own mix")
	await _wait_for_mixer()
	_check(ui_voice.stream == null, "Finished UI sound releases stream while paused")
	_check(gameplay_voice.stream == sound, "Paused gameplay sound is retained for resume")
	paused = false
	await _wait_for_mixer()
	_check(gameplay_voice.stream == null, "Resumed SFX finishes and releases its stream")
	audio.stop_all_sfx()
	if _failures == 0:
		print("AudioManager pooling, routing, caller lifetime, pause and stream cleanup passed")
	quit(0 if _failures == 0 else 1)


func _wait_for_mixer() -> void:
	# SceneTree timers can advance faster than the audio thread in headless tests.
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 500:
		await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
