extends SceneTree

const FOREST := "res://world/biomes/forest/forest_double_01.tscn"
const SILAS := preload("res://gameplay/npcs/silas/silas_npc.tscn")
const PANEL := preload("res://gameplay/merchant/silas_shop_panel.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()
	create_timer(15.0, true, false, true).timeout.connect(func() -> void:
		push_error("Silas panel autowire test timed out")
		quit(1)
	)


func _run() -> void:
	change_scene_to_file(FOREST)
	await scene_changed
	var silas := current_scene.get_node("Silas") as SilasNpc
	var panel := silas.get_node_or_null("SilasShopPanel") as SilasShopPanel
	_check(panel != null, "Silas in Forest_double_01 creates its missing shop UI")
	_check(silas.get("_shop_panel") == panel, "Silas connects to the generated panel")
	var player := current_scene.get_node("Foxy") as Player
	if panel != null:
		silas._open_shop(player)
		_check(panel.visible, "Silas opens the generated shop UI for Foxy")
		panel.close_shop()
		await create_timer(panel.close_duration + 0.05, true).timeout
	current_scene.free()
	current_scene = null
	var fixture := Node3D.new()
	root.add_child(fixture)
	var placed := PANEL.instantiate() as SilasShopPanel
	placed.name = "SilasShopPanel"
	fixture.add_child(placed)
	var npc := SILAS.instantiate() as SilasNpc
	fixture.add_child(npc)
	_check(npc.get("_shop_panel") == placed, "Silas reuses an explicitly placed shop panel")
	_check(npc.get_node_or_null("SilasShopPanel") == null, "No duplicate panel is created")
	fixture.free()
	for failure: String in failures:
		push_error(failure)
	if failures.is_empty():
		print("Silas panel autowire checks: PASS")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
