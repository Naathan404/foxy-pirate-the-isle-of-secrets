class_name PotionQuickSelect
extends Control
## Owns tap/hold selection and its overlay; PotionComponent remains the equipment authority.

const SLOT_SCENE: PackedScene = preload("res://gameplay/inventory/potion_wheel_slot.tscn")
const SECTOR_START_ANGLE := -PI * 0.5
const MILLIS_PER_SECOND := 1000.0
const FULL_TURN := TAU

@export var catalog: Array[Potion] = []
@export var swap_action: StringName = &"swap_potion"
@export_range(0.1, 0.6, 0.01) var hold_seconds: float = 0.22
@export_range(0.05, 1.0, 0.01) var slow_motion_scale: float = 0.18
@export_range(100.0, 240.0, 1.0) var outer_radius: float = 172.0
@export_range(40.0, 100.0, 1.0) var inner_radius: float = 80.0
@export_group("Wheel Layout")
@export var slot_half_size := Vector2(36.0, 42.0)
@export var center_name_offset := Vector2(-76.0, -42.0)
@export var center_count_offset := Vector2(-78.0, 24.0)
@export var title_offset := Vector2(-180.0, -50.0)
@export var hint_offset := Vector2(-260.0, 28.0)
@export_range(0.0, 100.0, 1.0) var outer_hit_padding := 60.0
@export_range(0.0, 0.2, 0.005) var sector_gap_radians := 0.025
@export_range(0.0, 20.0, 1.0) var inner_circle_inset := 5.0
@export_range(8, 48, 1) var sector_segment_count := 24
@export_group("Wheel Colors")
@export var overlay_color := Color(0.01, 0.025, 0.045, 0.5)
@export var center_color := Color(0.035, 0.06, 0.085, 0.96)
@export var selected_sector_color := Color(0.15, 0.24, 0.27, 0.98)
@export var idle_sector_color := Color(0.04, 0.08, 0.12, 0.96)
@export var selected_rim_color := Color(1.0, 0.8, 0.4)
@export var idle_rim_color := Color(0.25, 0.43, 0.48, 0.7)
@export var unavailable_icon_tint := Color(0.4, 0.45, 0.5, 0.6)
@export_range(0.5, 8.0, 0.5) var selected_rim_width := 2.0
@export_range(0.5, 8.0, 0.5) var idle_rim_width := 1.0

var _player: Player
var _potions: PotionComponent
var _slots: Array[Control] = []
var _pending: bool = false
var _opened: bool = false
var _pressed_at: int = 0
var _hovered: int = -1
var _suppress_secondary_attack: bool = false
var _secondary_block_until_frame: int = -1
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _previous_mouse_position: Vector2

@onready var _center_name: Label = $CenterName
@onready var _center_count: Label = $CenterCount
@onready var _title: Label = $Title
@onready var _hint: Label = $Hint
@onready var _hitstop = get_node("/root/HitstopController")
@onready var _game_manager = get_node("/root/GameManager")


func _ready() -> void:
	hide()
	set_process(false)
	set_process_input(false)
	resized.connect(_layout_slots)
	for potion: Potion in catalog:
		if potion == null:
			push_error("PotionQuickSelect: catalog entries must reference a potion")
			continue
		var slot := SLOT_SCENE.instantiate() as Control
		add_child(slot)
		_slots.append(slot)
		(slot.get_node("Icon") as TextureRect).texture = potion.icon
	_layout_slots()


func configure(player: Player, potions: PotionComponent) -> void:
	if not is_instance_valid(player) or not is_instance_valid(potions) or potions.inventory == null:
		return
	_player = player
	_potions = potions
	_potions.inventory.changed.connect(_refresh_if_open)
	_potions.equipped_potion_changed.connect(_on_equipment_changed)
	_potions.secondary_potion_changed.connect(_on_equipment_changed)
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_RIGHT
		and (_opened or _suppress_secondary_attack)
	):
		if event.pressed and _opened and _can_interact():
			_suppress_secondary_attack = true
			if _confirm_selection(true):
				cancel_selection()
		elif not event.pressed:
			_suppress_secondary_attack = false
			_secondary_block_until_frame = Engine.get_physics_frames() + 1
			set_process(_pending or _opened)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(swap_action) and _can_interact():
		_pending = true
		_pressed_at = Time.get_ticks_msec()
		set_process(true)
		get_viewport().set_input_as_handled()
	elif event.is_action_released(swap_action) and (_pending or _opened):
		if _can_interact():
			if _opened:
				_confirm_selection()
			elif _elapsed_hold() < hold_seconds:
				_potions.swap_potions()
		cancel_selection()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_cancel") and (_pending or _opened):
		cancel_selection()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _suppress_secondary_attack and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_suppress_secondary_attack = false
		_secondary_block_until_frame = Engine.get_physics_frames() + 1
	if not _pending and not _opened:
		set_process(_suppress_secondary_attack)
		return
	if not _can_interact():
		cancel_selection()
		return
	if _pending and _elapsed_hold() >= hold_seconds:
		_open_selection()
	if _opened:
		_update_hover()


func _elapsed_hold() -> float:
	return (Time.get_ticks_msec() - _pressed_at) / MILLIS_PER_SECOND


func _can_interact() -> bool:
	return (
		is_instance_valid(_player)
		and is_instance_valid(_potions)
		and not _player.dead
		and not _player.blocked
		and not get_tree().paused
		and _game_manager.state == _game_manager.State.PLAYING
		and (not is_instance_valid(_player.inventory_ui) or not _player.inventory_ui.is_open())
	)


func _open_selection() -> void:
	# Clear aim/buffers before setting our own input gate; opening must not cancel itself.
	_player.clear_gameplay_input()
	_pending = false
	_opened = true
	_hovered = -1
	_player.potion_selection_active = true
	_player.set_horizontal_velocity(Vector3.ZERO)
	_previous_mouse_mode = Input.mouse_mode
	_previous_mouse_position = get_viewport().get_mouse_position()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_viewport().warp_mouse(size * 0.5)
	_hitstop.begin_slow_motion(self, slow_motion_scale)
	_hint.text = "Release %s: MAIN  /  RMB: BACKUP\nEsc: cancel" % _swap_key_name()
	_refresh_slots()
	_layout_slots()
	show()
	set_process(true)


func cancel_selection() -> void:
	_pending = false
	if _opened:
		_opened = false
		_hitstop.end_slow_motion(self)
		if is_instance_valid(_player):
			_player.potion_selection_active = false
		Input.mouse_mode = _previous_mouse_mode
		get_viewport().warp_mouse(_previous_mouse_position)
	hide()
	set_process(_suppress_secondary_attack)


## Keep polling gameplay from treating the selection click as a weapon skill.
func blocks_secondary_attack() -> bool:
	# A press and release in one frame can leave Input.is_action_just_pressed() true.
	return _suppress_secondary_attack or Engine.get_physics_frames() <= _secondary_block_until_frame


func _confirm_selection(secondary: bool = false) -> bool:
	_update_hover()
	if _hovered < 0 or _potions.inventory.count_item(catalog[_hovered].item_id) <= 0:
		return false
	if secondary:
		return _potions.equip_secondary_potion(catalog[_hovered])
	return _potions.equip_potion(catalog[_hovered])


func _update_hover() -> void:
	var offset := get_local_mouse_position() - size * 0.5
	var distance := offset.length()
	var next: int = -1
	if (
		distance >= inner_radius
		and distance <= outer_radius + outer_hit_padding
		and not _slots.is_empty()
	):
		var step := TAU / _slots.size()
		next = posmod(floori((offset.angle() + PI * 0.5 + step * 0.5) / step), _slots.size())
	if next == _hovered:
		return
	_hovered = next
	_refresh_slots()


func _refresh_if_open() -> void:
	if _opened:
		_refresh_slots()


func _on_equipment_changed(_potion: Potion) -> void:
	_refresh_if_open()


func _refresh_slots() -> void:
	for index in _slots.size():
		var potion: Potion = catalog[index]
		var quantity: int = _potions.inventory.count_item(potion.item_id)
		var slot: Control = _slots[index]
		var icon := slot.get_node("Icon") as TextureRect
		icon.modulate = Color.WHITE if quantity > 0 else unavailable_icon_tint
		(slot.get_node("Count") as Label).text = str(quantity)
		var assignment := slot.get_node("Assignment") as Label
		assignment.text = "MAIN" if _potions.is_equipped(potion) else ""
		if _potions.is_secondary_equipped(potion):
			assignment.text = "BACKUP"
	_center_name.text = "Select potion"
	_center_count.text = "Keep current"
	if _hovered >= 0:
		var potion: Potion = catalog[_hovered]
		var quantity: int = _potions.inventory.count_item(potion.item_id)
		_center_name.text = potion.display_name
		_center_count.text = "%d available" % quantity if quantity > 0 else "Empty"
	queue_redraw()


func _layout_slots() -> void:
	var center := size * 0.5
	for index in _slots.size():
		var angle := SECTOR_START_ANGLE + index * FULL_TURN / _slots.size()
		var radius := (outer_radius + inner_radius) * 0.5
		_slots[index].position = center + Vector2.from_angle(angle) * radius - slot_half_size
	_center_name.position = center + center_name_offset
	_center_count.position = center + center_count_offset
	_title.position = center + title_offset + Vector2(0.0, -outer_radius)
	_hint.position = center + hint_offset + Vector2(0.0, outer_radius)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	draw_rect(Rect2(Vector2.ZERO, size), overlay_color)
	draw_circle(center, inner_radius - inner_circle_inset, center_color)
	for index in _slots.size():
		var angle := SECTOR_START_ANGLE + index * FULL_TURN / _slots.size()
		var half_angle := PI / _slots.size() - sector_gap_radians
		var polygon: PackedVector2Array = []
		for step in range(sector_segment_count + 1):
			var phase := lerpf(
				angle - half_angle, angle + half_angle, float(step) / sector_segment_count
			)
			polygon.append(center + Vector2.from_angle(phase) * outer_radius)
		for step in range(sector_segment_count, -1, -1):
			var phase := lerpf(
				angle - half_angle, angle + half_angle, float(step) / sector_segment_count
			)
			polygon.append(center + Vector2.from_angle(phase) * inner_radius)
		var selected: bool = index == _hovered
		var fill := selected_sector_color if selected else idle_sector_color
		draw_colored_polygon(polygon, fill)
		polygon.append(polygon[0])
		var rim := selected_rim_color if selected else idle_rim_color
		draw_polyline(
			polygon, rim, selected_rim_width if selected else idle_rim_width, true
		)


func _swap_key_name() -> String:
	for event: InputEvent in InputMap.action_get_events(swap_action):
		if event is InputEventKey:
			return (event as InputEventKey).as_text_physical_keycode()
	return swap_action


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		cancel_selection()


func _exit_tree() -> void:
	if _opened:
		cancel_selection()
