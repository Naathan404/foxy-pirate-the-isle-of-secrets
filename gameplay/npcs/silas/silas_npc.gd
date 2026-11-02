class_name SilasNpc
extends BaseNpc

## Fixed merchant NPC. Shared talk/camera mechanics remain in BaseNpc.
@export_group("Silas Merchant")
@export var data: NpcData
@export var catalog: MerchantCatalog
@export var shop_panel_path: NodePath

var _shop_panel: SilasShopPanel


func _ready() -> void:
	if data == null or catalog == null or not catalog.validate().is_empty():
		push_error("SilasNpc: valid data and merchant catalog are required")
		set_physics_process(false)
		return
	super()
	_shop_panel = get_node_or_null(shop_panel_path) as SilasShopPanel
	if _shop_panel == null:
		push_error("SilasNpc: shop panel is missing")
		return
	_shop_panel.shop_closed.connect(_on_shop_closed)
	dialogue_finished.connect(_on_dialogue_finished)


func get_npc_data() -> NpcData:
	return data


func play_directional_animation(action: StringName, restart: bool = false) -> bool:
	if action != &"idle" or not is_instance_valid(visual.animation_player):
		return false
	if visual.animation_player.assigned_animation == &"idle" and not restart:
		return true
	visual.animation_player.play(&"idle")
	return true


func _on_interaction_requested(interactor: Player) -> void:
	if _shop_panel == null or _shop_panel.visible or is_talking:
		return
	var progress := get_node_or_null("/root/SilasProgress") as SilasProgressStore
	if progress == null or not progress.has_met_silas():
		super._on_interaction_requested(interactor)
		return
	_open_shop(interactor)


func _on_dialogue_finished(interactor: Player) -> void:
	var progress := get_node_or_null("/root/SilasProgress") as SilasProgressStore
	if progress != null:
		progress.mark_met_silas()
	_open_shop.call_deferred(interactor)


func _open_shop(interactor: Player) -> void:
	if _shop_panel == null or _shop_panel.visible:
		return
	interaction_area.set_interaction_enabled(false)
	if not _shop_panel.open_for(interactor, catalog):
		interaction_area.set_interaction_enabled(true)


func _on_shop_closed() -> void:
	interaction_area.set_interaction_enabled(true)
