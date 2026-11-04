extends SceneTree

const SLOT: PackedScene = preload("res://gameplay/inventory/equipment_slot.tscn")
const ITEM_SLOT: PackedScene = preload("res://gameplay/inventory/inventory_slot_ui.tscn")

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var grid := GridContainer.new()
	grid.position = Vector2(200, 200)
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 7)
	root.add_child(grid)
	var slot = SLOT.instantiate()
	grid.add_child(slot)
	var other = SLOT.instantiate()
	grid.add_child(other)
	var artwork := load("res://assets/ui/player_hud/weapon_skills/CP_Dagger.png") as Texture2D
	slot.present(artwork)
	other.present(artwork)
	await process_frame
	await process_frame
	var hit_area: Rect2 = slot.get_global_rect()
	var neighbor: Rect2 = other.get_global_rect()
	var base_scale: Vector2 = slot.background.scale
	_motion(hit_area.get_center())
	await create_timer(0.15).timeout
	_check(
		slot.background.scale.is_equal_approx(base_scale * slot.hover_scale),
		"Pointer hover enlarges artwork"
	)
	_check(slot.background.modulate.r > 1.0, "Pointer hover brightens the slot")
	_check(slot.get_node("SelectionHighlight").visible, "Hover highlight is visible")
	_check(
		slot.get_global_rect() == hit_area and other.get_global_rect() == neighbor,
		"Hover never moves hit area or neighboring slot"
	)
	_check(
		slot.background.get_global_rect().end.x < other.background.get_global_rect().position.x,
		"Hover artwork does not overlap its neighbor"
	)
	_click(hit_area.get_center(), true)
	await create_timer(0.15).timeout
	_check(
		slot.background.scale.is_equal_approx(base_scale * slot.pressed_scale),
		"Mouse down depresses artwork"
	)
	_click(hit_area.get_center(), false)
	slot.present(artwork, "E", true)
	_motion(Vector2(30, 30))
	await create_timer(0.15).timeout
	_check(
		slot.background.scale.is_equal_approx(base_scale * 1.02),
		"Selected slot keeps a gentle emphasis"
	)
	var highlight := slot.get_node("SelectionHighlight") as TextureRect
	_check(
		highlight.texture.resource_path.ends_with("06_item_selection_highlight.png"),
		"Shop highlight texture is used"
	)
	_check(
		slot.get_node("Badge").z_index > highlight.z_index, "Equipment badge stays above highlight"
	)
	slot.present(artwork, "x", true, true)
	await create_timer(0.15).timeout
	_check(
		is_equal_approx(slot.item_icon.modulate.a, 0.35), "Locked icon stays dim during feedback"
	)
	slot.play_equip_feedback()
	_check(slot.background.scale.x > base_scale.x, "Equip confirmation pops artwork")
	grid.hide()
	_check(slot.background.scale == base_scale, "Hiding tab resets transient scale")
	_check(
		not slot.get("_pressed") and not slot.get("_hovered"), "Hiding tab clears input feedback"
	)
	grid.show()
	await create_timer(0.15).timeout
	_check(slot.get_global_rect() == hit_area, "Reopening preserves slot geometry")
	grid.free()
	var item_slot := ITEM_SLOT.instantiate() as InventorySlotUI
	root.add_child(item_slot)
	item_slot.set_potion_assignment("MAIN")
	item_slot.set_selected(true)
	var item_highlight := item_slot.get_node("Selection") as TextureRect
	_check(
		item_highlight.texture.resource_path.ends_with("06_item_selection_highlight.png"),
		"Inventory slot uses the same highlight texture"
	)
	_check(
		item_slot.potion_assignment_label.z_index > item_highlight.z_index,
		"Potion assignment label stays above the highlight"
	)
	_check(
		item_slot.quantity_label.z_index > item_highlight.z_index,
		"Item quantity stays above the highlight"
	)
	item_slot.free()
	if _failures == 0:
		print(
			(
				"Equipment slot feedback: pointer hover, press, selection, locked tint, "
				+ "confirmation and fixed geometry passed"
			)
		)
	quit(0 if _failures == 0 else 1)


func _motion(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	root.push_input(event, true)


func _click(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event, true)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
