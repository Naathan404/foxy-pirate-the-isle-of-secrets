extends SceneTree

const SILAS: PackedScene = preload("res://gameplay/npcs/silas/silas_npc.tscn")
const ROOM: PackedScene = preload("res://world/biomes/coral_valley/map/room_13.tscn")

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var shared := SILAS.instantiate() as SilasNpc
	root.add_child(shared)
	await process_frame
	if shared.catalog == null or not shared.catalog.validate().is_empty() or not shared.interaction_area.interaction_requested.is_connected(shared._on_interaction_requested):
		push_error("Shared Silas scene must load its catalog and interaction handler")
		quit(1)
		return
	shared.queue_free()
	await process_frame
	var room := ROOM.instantiate()
	root.add_child(room)
	var silas := room.get_node("Silas") as SilasNpc
	var player := room.get_node("Foxy") as Player
	player.global_position = silas.global_position + Vector3(2.0, 0.0, 0.0)
	for i in 5:
		await physics_frame
	if silas.catalog == null or not silas.catalog.validate().is_empty():
		push_error("Silas catalog must load and validate in room_13")
		quit(1)
		return
	if not silas.interaction_area.interaction_requested.is_connected(silas._on_interaction_requested):
		push_error("Silas must connect its interaction handler")
		quit(1)
		return
	if silas.interaction_area._get_interactor() != player:
		push_error("Silas interaction area must detect the nearby player")
		quit(1)
		return
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(640, 360)
	root.push_input(click, true)
	await process_frame
	if silas._presentation_state != SilasNpc.PresentationState.OPENING or not player.blocked:
		push_error("Left click should start Silas interaction and block combat")
		quit(1)
		return
	print("Shared Silas and room_13 interaction tests passed")
	room.queue_free()
	await process_frame
	quit(0)
