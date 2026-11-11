extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://gameplay/npcs/silas/silas_npc.tscn") as PackedScene
	var npc := scene.instantiate() as SilasNpc
	root.add_child(npc)
	await process_frame
	var dialogic := root.get_node("Dialogic")
	var styles: Node = dialogic.call(&"get_subsystem", "Styles")
	assert(styles.call(&"has_active_layout_node"), "Dialogue layout should be prepared")
	var layout := styles.call(&"get_layout_node") as Node
	assert(layout != null and not bool(layout.get("visible")))
	assert(ProjectSettings.get_setting("dialogic/layout/end_behaviour") == 1)
	for timeline_path in npc._get_dialogue_preload_paths():
		if not ResourceLoader.exists(timeline_path):
			continue
		while ResourceLoader.load_threaded_get_status(timeline_path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await process_frame
		if ResourceLoader.load_threaded_get_status(timeline_path) == ResourceLoader.THREAD_LOAD_LOADED:
			ResourceLoader.load_threaded_get(timeline_path)
	npc.queue_free()
	layout.queue_free()
	await process_frame
	if has_meta("dialogic_layout_node"):
		remove_meta("dialogic_layout_node")
	print("npc_dialogue_cache_test: PASS")
	quit()
