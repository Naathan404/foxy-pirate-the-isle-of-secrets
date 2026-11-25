@tool
class_name WorldMapCanvas
extends Control
## Draws the world map: biome islands laid out by `world_cell`, and the room grid of one
## biome. `zoom_progress` blends from the world layer (0) into `zoom_index`'s rooms (1).
## In the editor everything is previewed as explored; the Inspector buttons rebuild the data
## from the room scenes so a new biome shows up after one click.

signal biome_hovered(index: int)
signal biome_pressed(index: int)
signal back_pressed

enum LegendIcon { SAFE, CURRENT, EXPLORED, UNEXPLORED }

const NO_BIOME := -1
const HALF := 0.5
const UNCHARTED_NAME := "???"
const LOCKED_TEXT := "Locked"
const MS_PER_SECOND := 1000.0
const NAME_FONT_TYPE := &"NameLabel"
const DETAIL_FONT_TYPE := &"MutedLabel"
const FONT_NAME := &"font"
const ARROW_HALF_WIDTH_RATIO := 0.7
const CHECKPOINT_SIZE_RATIO := 0.22
const NPC_RADIUS_RATIO := 0.13
const CURRENT_DOT_RATIO := 0.12
const MINI_RING_GROW_PIXELS := 1.0
const WHEEL_ZOOM_STEP := 1.15
const CLOUD_PHASE_STEP := 1.7
const CLOUD_VERTICAL_DRIFT_RATIO := 0.8
## Puffs of the cloud over a room the player has only heard of: x and y offset from the room
## centre, then radius, all in room sizes.
const CLOUD_PUFFS: Array[Vector3] = [
	Vector3(-0.28, -0.12, 0.34),
	Vector3(0.26, -0.2, 0.3),
	Vector3(0.0, 0.05, 0.4),
	Vector3(-0.22, 0.26, 0.3),
	Vector3(0.28, 0.22, 0.32),
	Vector3(0.0, -0.3, 0.26),
]
## Teardrop flame of the safe-room badge, in badge radii around its centre.
const FLAME_SHAPE: Array[Vector2] = [
	Vector2(0.0, -0.9),
	Vector2(0.5, -0.1),
	Vector2(0.4, 0.5),
	Vector2(0.0, 0.85),
	Vector2(-0.4, 0.5),
	Vector2(-0.5, -0.1),
]
const FLAME_SCALE := 0.8
const BADGE_OFFSET_RATIO := Vector2(0.27, -0.27)
const BADGE_RADIUS_RATIO := 0.2
const BADGE_RING_PIXELS := 1.5
const BADGE_RING_POINTS := 24
const MINI_SAFE_RADIUS_RATIO := 0.22
const TABLE_ALPHA := 0.38
const GLOW_ALPHA := 0.22
const SHADOW_ALPHA := 0.35
const SHINE_ALPHA := 0.3
const SHINE_HEIGHT_RATIO := 0.28
const VEILED_FILL_DARKEN := 0.5
const LEGEND_ICON_RING_GROW_PIXELS := 2.0
const LEGEND: Dictionary[LegendIcon, String] = {
	LegendIcon.SAFE: "Safe room",
	LegendIcon.CURRENT: "You are here",
	LegendIcon.EXPLORED: "Explored",
	LegendIcon.UNEXPLORED: "Unexplored",
}

@export var world_map: WorldMapData:
	set(value):
		if world_map == value:
			return
		if world_map != null and world_map.changed.is_connected(queue_redraw):
			world_map.changed.disconnect(queue_redraw)
		world_map = value
		if world_map != null:
			world_map.changed.connect(queue_redraw)
		queue_redraw()
## Reads every biome's map folder, adds new biomes and rooms, refreshes exits and saves.
@export_tool_button("Sync rooms from scenes", "Reload") var sync_rooms_action: Callable:
	get:
		return _sync_rooms.bind(false)
## Same as sync, but places every room again; authored cells are overwritten.
@export_tool_button("Re-layout all rooms", "GridContainer") var relayout_rooms_action: Callable:
	get:
		return _sync_rooms.bind(true)

@export_group("Editor Preview")
## Biome whose rooms the editor shows; empty shows the world layer.
@export var preview_biome_id: StringName = &"":
	set(value):
		preview_biome_id = value
		queue_redraw()

@export_group("World Layer")
@export var island_size_pixels: Vector2 = Vector2(230, 140)
@export var island_spacing_pixels: Vector2 = Vector2(300, 190)
@export_range(0.0, 40.0, 1.0, "suffix:px") var island_header_pixels: float = 42.0
@export_range(0.0, 30.0, 1.0, "suffix:px") var island_padding_pixels: float = 12.0
@export_range(0, 40, 1, "suffix:px") var island_corner_pixels: int = 18
@export_range(0, 8, 1, "suffix:px") var island_border_pixels: int = 3
@export_range(0.0, 20.0, 1.0, "suffix:px") var focus_grow_pixels: float = 8.0
@export_range(0.0, 1.0, 0.05) var explored_fill_darken: float = 0.45
@export_range(1.5, 6.0, 0.1) var zoom_in_scale: float = 3.0

@export_group("Room Layer")
@export_range(16.0, 160.0, 1.0, "suffix:px") var max_room_cell_pixels: float = 112.0
@export_range(0.3, 0.95, 0.01) var room_fill_ratio: float = 0.74
@export_range(0, 20, 1, "suffix:px") var room_corner_pixels: int = 6
@export_range(0, 6, 1, "suffix:px") var room_border_pixels: int = 2
@export_range(1.0, 10.0, 0.5, "suffix:px") var link_width_pixels: float = 4.0
@export_range(4.0, 30.0, 1.0, "suffix:px") var exit_arrow_pixels: float = 16.0
@export_range(1.0, 8.0, 0.1) var max_view_zoom: float = 4.0
@export_range(0.5, 10.0, 0.1) var pulse_speed: float = 3.5
@export_range(0.0, 12.0, 0.5, "suffix:px") var pulse_grow_pixels: float = 5.0
@export_range(0.0, 20.0, 0.5, "suffix:px") var cloud_drift_pixels: float = 4.0
@export_range(0.1, 3.0, 0.1) var cloud_drift_speed: float = 0.7
@export_range(0.0, 10.0, 0.5, "suffix:px") var room_shadow_pixels: float = 4.0
@export_range(0.0, 16.0, 0.5, "suffix:px") var room_glow_pixels: float = 5.0
@export_range(0, 40, 1, "suffix:px") var table_corner_pixels: int = 14
@export_range(8.0, 40.0, 1.0, "suffix:px") var legend_icon_pixels: float = 20.0
@export_range(4.0, 60.0, 1.0, "suffix:px") var legend_gap_pixels: float = 28.0
@export_range(4.0, 40.0, 1.0, "suffix:px") var legend_margin_pixels: float = 16.0

@export_group("Colours")
@export var ink_color: Color = Color(0.1, 0.07, 0.09)
@export var unknown_color: Color = Color(0.2, 0.17, 0.19)
@export var text_color: Color = Color(0.98, 0.93, 0.86)
@export var muted_color: Color = Color(0.77, 0.61, 0.53)
@export var highlight_color: Color = Color(0.96, 0.89, 0.77)
@export var checkpoint_color: Color = Color(0.98, 0.6, 0.3)
@export var safe_room_color: Color = Color(1.0, 0.66, 0.28)
## Dark mist over rooms next to explored ones that the player has not entered yet.
@export var cloud_color: Color = Color(0.05, 0.04, 0.08, 0.6)
@export_range(8, 64, 1) var name_font_size: int = 28
@export_range(8, 40, 1) var detail_font_size: int = 18

var focused_index: int = NO_BIOME:
	set(value):
		focused_index = value
		queue_redraw()
var zoom_index: int = NO_BIOME:
	set(value):
		zoom_index = value
		reset_view()
var zoom_progress: float = 0.0:
	set(value):
		zoom_progress = clampf(value, 0.0, 1.0)
		queue_redraw()
## Sideways nudge of the focused island, used to refuse a locked biome.
var shake_offset_pixels: float = 0.0:
	set(value):
		shake_offset_pixels = value
		queue_redraw()

var _progress: MapProgress = MapProgress.new()
var _unlocked: Dictionary[StringName, bool] = {}
## Unentered rooms next to entered ones; every other unentered room stays off the map.
var _frontier: Dictionary[String, bool] = {}
var _hovered_index: int = NO_BIOME
## Player zoom and pan of the room layer: screen point = point * scale + offset.
var _view_scale: float = 1.0
var _view_offset: Vector2 = Vector2.ZERO
var _dragging_view: bool = false
var _box: StyleBoxFlat = StyleBoxFlat.new()


func _process(_delta: float) -> void:
	# The current-room pulse animates while the tree is paused behind the map.
	if not Engine.is_editor_hint() and is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	if world_map == null:
		return
	var target := zoom_index
	var zoom := zoom_progress
	if Engine.is_editor_hint():
		_use_editor_preview()
		target = _biome_index(preview_biome_id)
		zoom = 1.0 if target != NO_BIOME else 0.0
	if zoom < 1.0 or target == NO_BIOME:
		_draw_world_layer(target, zoom)
	if zoom > 0.0 and target != NO_BIOME:
		_draw_room_layer(target, zoom)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null and _dragging_view:
		_view_offset += motion.relative
		_clamp_view()
		queue_redraw()
		return
	if motion != null:
		var index := _biome_at(motion.position)
		if index != _hovered_index:
			_hovered_index = index
			if index != NO_BIOME:
				biome_hovered.emit(index)
		return
	var button := event as InputEventMouseButton
	if button == null:
		return
	if _is_room_layer_shown():
		if _handle_view_button(button):
			accept_event()
			return
	if not button.pressed:
		return
	if button.button_index == MOUSE_BUTTON_LEFT:
		var index := _biome_at(button.position)
		if index != NO_BIOME:
			biome_pressed.emit(index)
			accept_event()
	elif button.button_index == MOUSE_BUTTON_RIGHT:
		back_pressed.emit()
		accept_event()


## Snapshot of the session shown by the map; it does not change while the map is open.
func show_progress(progress: MapProgress, unlocked_biomes: Dictionary[StringName, bool]) -> void:
	_progress = progress
	_unlocked = unlocked_biomes
	_frontier = world_map.get_frontier_rooms(progress)
	queue_redraw()


func get_status(index: int) -> BiomeMapData.Status:
	var biome := world_map.biomes[index]
	return biome.get_status(_progress, _unlocked.get(biome.biome_id, false))


## Back to the fitted view; called whenever another biome is shown.
func reset_view() -> void:
	_view_scale = 1.0
	_view_offset = Vector2.ZERO
	_dragging_view = false
	queue_redraw()


func get_progress() -> MapProgress:
	return _progress


func get_current_biome_index() -> int:
	return world_map.biomes.find(world_map.find_biome_of_room(_progress.current_room))


func _is_room_layer_shown() -> bool:
	return zoom_index != NO_BIOME and zoom_progress >= 1.0


## Wheel zooms around the cursor; dragging with a mouse button pans.
func _handle_view_button(button: InputEventMouseButton) -> bool:
	match button.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			_zoom_view(WHEEL_ZOOM_STEP, button.position)
		MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_view(1.0 / WHEEL_ZOOM_STEP, button.position)
		MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE:
			_dragging_view = button.pressed
		_:
			return false
	return true


func _zoom_view(factor: float, anchor: Vector2) -> void:
	var new_scale := clampf(_view_scale * factor, 1.0, max_view_zoom)
	var ratio := new_scale / _view_scale
	_view_offset = anchor - (anchor - _view_offset) * ratio
	_view_scale = new_scale
	_clamp_view()
	queue_redraw()


## Keeps the zoomed map covering the canvas so it cannot be dragged out of sight.
func _clamp_view() -> void:
	var slack := size * (_view_scale - 1.0)
	_view_offset = _view_offset.clamp(-slack, Vector2.ZERO)


func _draw_world_layer(target: int, zoom: float) -> void:
	var alpha := 1.0 - zoom
	draw_set_transform_matrix(_world_transform(target, zoom))
	for link: Vector2i in world_map.get_biome_links():
		if (
			get_status(link.x) == BiomeMapData.Status.EXPLORED
			or get_status(link.y) == BiomeMapData.Status.EXPLORED
		):
			draw_line(
				_island_center(link.x),
				_island_center(link.y),
				_faded(muted_color, alpha),
				link_width_pixels,
				true
			)
	for index in world_map.biomes.size():
		_draw_island(index, alpha)


func _draw_island(index: int, alpha: float) -> void:
	var biome := world_map.biomes[index]
	var status := get_status(index)
	var charted := status in [BiomeMapData.Status.EXPLORED, BiomeMapData.Status.UNEXPLORED]
	var focused := index == focused_index
	var rect := _island_rect(index)
	if focused:
		rect = rect.grow(focus_grow_pixels)
		rect.position.x += shake_offset_pixels

	var fill := unknown_color
	if status == BiomeMapData.Status.EXPLORED:
		fill = biome.accent.darkened(explored_fill_darken)
	var border := biome.accent if charted else muted_color.darkened(explored_fill_darken)
	if focused:
		border = highlight_color
	_draw_box(rect, fill, border, island_border_pixels, island_corner_pixels, alpha)

	var title := UNCHARTED_NAME if status == BiomeMapData.Status.UNCHARTED else biome.display_name
	var title_color := text_color if charted else muted_color
	_draw_centered_text(
		title,
		rect.position.x,
		rect.position.y + island_header_pixels * HALF,
		rect.size.x,
		NAME_FONT_TYPE,
		name_font_size,
		_faded(title_color, alpha)
	)
	if status == BiomeMapData.Status.LOCKED:
		_draw_centered_text(
			LOCKED_TEXT,
			rect.position.x,
			rect.get_center().y + island_header_pixels * HALF,
			rect.size.x,
			DETAIL_FONT_TYPE,
			detail_font_size,
			_faded(muted_color, alpha)
		)
	if charted:
		_draw_rooms(index, _island_rooms_rect(rect), alpha, false)


func _draw_room_layer(target: int, zoom: float) -> void:
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_map_table(zoom)
	# Grow the rooms out of their island so the two layers read as one zoom.
	var start := _world_transform(target, zoom) * _island_rooms_rect(_island_rect(target))
	var rect := Rect2(start.position.lerp(Vector2.ZERO, zoom), start.size.lerp(size, zoom))
	_draw_rooms(target, rect, zoom, true)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_legend(world_map.biomes[target].accent, zoom)


## Mini rooms on an island, or the full room layer with links, markers and exits.
func _draw_rooms(index: int, rect: Rect2, alpha: float, detailed: bool) -> void:
	var biome := world_map.biomes[index]
	if biome.rooms.is_empty():
		return
	var grid := _grid_transform(biome, rect, detailed)
	var cell_pixels := grid.get_scale().x
	if detailed:
		_draw_links(biome, grid, alpha)
	for room: RoomMapData in biome.rooms:
		var visited := _progress.has_visited(room.scene_path)
		if not visited and not _frontier.has(room.scene_path):
			continue
		var center := grid * Vector2(room.cell)
		var room_size := cell_pixels * room_fill_ratio
		var rect_room := Rect2(center - Vector2.ONE * room_size * HALF, Vector2.ONE * room_size)
		if visited:
			_draw_visited_room(biome, room, rect_room, alpha, detailed)
		else:
			_draw_veiled_room(rect_room, alpha, detailed)
		if room.scene_path == _progress.current_room:
			_draw_current(rect_room, room_size, alpha, detailed)


func _draw_visited_room(
	biome: BiomeMapData, room: RoomMapData, rect: Rect2, alpha: float, detailed: bool
) -> void:
	var center := rect.get_center()
	var room_size := rect.size.x
	if not detailed:
		_draw_box(rect, biome.accent, ink_color, 0, 0, alpha)
		if room.safe_room:
			draw_circle(center, room_size * MINI_SAFE_RADIUS_RATIO, _faded(safe_room_color, alpha))
		return
	var glow := Color(biome.accent, GLOW_ALPHA)
	_draw_box(rect.grow(room_glow_pixels), glow, Color.TRANSPARENT, 0, room_corner_pixels, alpha)
	var shadow := Rect2(rect.position + Vector2.DOWN * room_shadow_pixels, rect.size)
	_draw_box(shadow, Color(0, 0, 0, SHADOW_ALPHA), Color.TRANSPARENT, 0, room_corner_pixels, alpha)
	_draw_box(rect, biome.accent, ink_color, room_border_pixels, room_corner_pixels, alpha)
	var inset := float(room_border_pixels)
	var shine := Rect2(
		rect.position + Vector2.ONE * inset,
		Vector2(rect.size.x - inset * 2.0, rect.size.y * SHINE_HEIGHT_RATIO)
	)
	draw_rect(shine, _faded(biome.accent.lightened(SHINE_ALPHA), SHINE_ALPHA * alpha))
	_draw_exits(biome, room, center, room_size, alpha)
	_draw_marker(room.marker, center, room_size, alpha)
	if room.safe_room:
		_draw_flame_badge(
			center + BADGE_OFFSET_RATIO * room_size, room_size * BADGE_RADIUS_RATIO, alpha
		)


## A room the player knows is there but has not entered: dark and wrapped in drifting mist.
func _draw_veiled_room(rect: Rect2, alpha: float, detailed: bool) -> void:
	var fill := ink_color.darkened(VEILED_FILL_DARKEN)
	if not detailed:
		_draw_box(rect, fill, Color.TRANSPARENT, 0, 0, alpha * HALF)
		return
	_draw_box(rect, fill, _faded(muted_color, HALF), room_border_pixels, room_corner_pixels, alpha)
	_draw_cloud(rect.get_center(), rect.size.x, alpha)


func _draw_cloud(center: Vector2, room_size: float, alpha: float) -> void:
	var time := Time.get_ticks_msec() / MS_PER_SECOND * cloud_drift_speed
	for index in CLOUD_PUFFS.size():
		var puff := CLOUD_PUFFS[index]
		var phase := time + index * CLOUD_PHASE_STEP
		var drift := Vector2(sin(phase), cos(phase * CLOUD_VERTICAL_DRIFT_RATIO))
		draw_circle(
			center + Vector2(puff.x, puff.y) * room_size + drift * cloud_drift_pixels,
			puff.z * room_size,
			_faded(cloud_color, alpha)
		)


## Campfire badge: a dark disc with a warm flame, for rooms where the player can rest.
func _draw_flame_badge(center: Vector2, radius: float, alpha: float) -> void:
	var color := _faded(safe_room_color, alpha)
	draw_circle(center, radius, _faded(ink_color, alpha))
	draw_arc(center, radius, 0.0, TAU, BADGE_RING_POINTS, color, BADGE_RING_PIXELS, true)
	var flame := PackedVector2Array()
	for point: Vector2 in FLAME_SHAPE:
		flame.append(center + point * radius * FLAME_SCALE)
	draw_colored_polygon(flame, color)


func _draw_links(biome: BiomeMapData, grid: Transform2D, alpha: float) -> void:
	var half_cell := grid.get_scale().x * HALF
	var drawn: Dictionary[String, bool] = {}
	for room: RoomMapData in biome.rooms:
		for direction: RoomMapData.Direction in room.exits:
			var other := biome.find_room(room.exits[direction])
			if other == null or not _is_link_visible(room, other):
				continue
			var key := _pair_key(room.scene_path, other.scene_path)
			if drawn.has(key):
				continue
			drawn[key] = true
			draw_polyline(
				_link_route(
					grid * Vector2(room.cell),
					grid * Vector2(other.cell),
					Vector2(RoomMapData.offset_of(direction)),
					half_cell
				),
				_faded(muted_color, alpha),
				link_width_pixels,
				true
			)


## Axis-aligned route that leaves `from` through its door and enters `to` from the opposite
## side. Rooms the data places off the door's axis get one elbow in the gap instead of a
## diagonal. The turn is placed in the gap right outside the door, so it never crosses a room.
func _link_route(
	from: Vector2, to: Vector2, forward: Vector2, half_cell: float
) -> PackedVector2Array:
	var exit_point := from + forward * half_cell
	var entry_point := to - forward * half_cell
	var across := Vector2(absf(forward.y), absf(forward.x))
	if (entry_point - exit_point).dot(across) == 0.0:
		return PackedVector2Array([from, to])
	var slid := exit_point + across * (entry_point - exit_point).dot(across)
	return PackedVector2Array([from, exit_point, slid, entry_point, to])


## Arrows in the neighbouring biome's colour mark doors that leave this biome.
func _draw_exits(
	biome: BiomeMapData, room: RoomMapData, center: Vector2, room_size: float, alpha: float
) -> void:
	for direction: RoomMapData.Direction in room.exits:
		var destination := world_map.find_biome_of_room(room.exits[direction])
		if destination == null or destination == biome:
			continue
		var forward := Vector2(RoomMapData.offset_of(direction))
		var side := Vector2(-forward.y, forward.x) * exit_arrow_pixels * ARROW_HALF_WIDTH_RATIO
		var base := center + forward * (room_size * HALF + exit_arrow_pixels * HALF)
		var tip := base + forward * exit_arrow_pixels
		draw_colored_polygon(
			PackedVector2Array([tip, base + side, base - side]), _faded(destination.accent, alpha)
		)


func _draw_marker(
	marker: RoomMapData.Marker, center: Vector2, room_size: float, alpha: float
) -> void:
	match marker:
		RoomMapData.Marker.CHECKPOINT:
			var reach := room_size * CHECKPOINT_SIZE_RATIO
			draw_colored_polygon(
				PackedVector2Array(
					[
						center + Vector2.UP * reach,
						center + Vector2.RIGHT * reach,
						center + Vector2.DOWN * reach,
						center + Vector2.LEFT * reach,
					]
				),
				_faded(checkpoint_color, alpha)
			)
		RoomMapData.Marker.NPC:
			draw_circle(center, room_size * NPC_RADIUS_RATIO, _faded(ink_color, alpha))


func _draw_current(rect: Rect2, room_size: float, alpha: float, detailed: bool) -> void:
	var pulse := (sin(Time.get_ticks_msec() / MS_PER_SECOND * pulse_speed) + 1.0) * HALF
	var ring := rect.grow(pulse * pulse_grow_pixels if detailed else MINI_RING_GROW_PIXELS)
	_draw_box(ring, Color.TRANSPARENT, highlight_color, room_border_pixels + 1, 0, alpha)
	if detailed:
		draw_circle(
			rect.get_center() + Vector2.DOWN * room_size * HALF * HALF,
			room_size * CURRENT_DOT_RATIO,
			_faded(highlight_color, alpha)
		)


## A door is drawn once one side is entered and both rooms are on the map; a door into a
## hidden room stays a secret.
func _is_link_visible(room: RoomMapData, other: RoomMapData) -> bool:
	var room_visited := _progress.has_visited(room.scene_path)
	var other_visited := _progress.has_visited(other.scene_path)
	if not (room_visited or other_visited):
		return false
	return (
		(room_visited or _frontier.has(room.scene_path))
		and (other_visited or _frontier.has(other.scene_path))
	)


## Dark inset panel behind the rooms so the explored area reads as one chart.
func _draw_map_table(alpha: float) -> void:
	_draw_box(
		Rect2(Vector2.ZERO, size),
		Color(ink_color, TABLE_ALPHA),
		_faded(muted_color, HALF),
		room_border_pixels,
		table_corner_pixels,
		alpha
	)


## Row of icon and caption pairs in the lower left, explaining the symbols on the map.
func _draw_legend(accent: Color, alpha: float) -> void:
	var font := get_theme_font(FONT_NAME, DETAIL_FONT_TYPE)
	var x := legend_margin_pixels
	var middle_y := size.y - legend_margin_pixels - legend_icon_pixels * HALF
	for icon: LegendIcon in LEGEND:
		var text := LEGEND[icon]
		var icon_center := Vector2(x + legend_icon_pixels * HALF, middle_y)
		_draw_legend_icon(icon, icon_center, accent, alpha)
		var text_left := x + legend_icon_pixels + legend_gap_pixels * HALF
		var text_width := (
			font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, detail_font_size).x
		)
		_draw_centered_text(
			text,
			text_left,
			middle_y,
			text_width,
			DETAIL_FONT_TYPE,
			detail_font_size,
			_faded(text_color, alpha)
		)
		x = text_left + text_width + legend_gap_pixels


func _draw_legend_icon(icon: LegendIcon, center: Vector2, accent: Color, alpha: float) -> void:
	var rect := Rect2(
		center - Vector2.ONE * legend_icon_pixels * HALF, Vector2.ONE * legend_icon_pixels
	)
	match icon:
		LegendIcon.SAFE:
			_draw_flame_badge(center, legend_icon_pixels * HALF, alpha)
		LegendIcon.CURRENT:
			_draw_box(rect, accent, ink_color, room_border_pixels, room_corner_pixels, alpha)
			_draw_box(
				rect.grow(LEGEND_ICON_RING_GROW_PIXELS),
				Color.TRANSPARENT,
				highlight_color,
				room_border_pixels,
				0,
				alpha
			)
		LegendIcon.EXPLORED:
			_draw_box(rect, accent, ink_color, room_border_pixels, room_corner_pixels, alpha)
		LegendIcon.UNEXPLORED:
			_draw_veiled_room(rect, alpha, true)


## Maps a room cell to its centre inside `rect`, keeping squares and centring the grid.
## The detailed layer keeps half a cell of margin for exit arrows.
func _grid_transform(biome: BiomeMapData, rect: Rect2, detailed: bool) -> Transform2D:
	var lowest := biome.rooms[0].cell
	var highest := lowest
	for room: RoomMapData in biome.rooms:
		lowest = lowest.min(room.cell)
		highest = highest.max(room.cell)
	var cells := Vector2(highest - lowest + Vector2i.ONE)
	if detailed:
		cells += Vector2.ONE
	var cell_pixels := minf(rect.size.x / cells.x, rect.size.y / cells.y)
	if detailed:
		cell_pixels = minf(cell_pixels, max_room_cell_pixels)
	var middle := Vector2(lowest + highest) * HALF
	var fitted := Transform2D(
		0.0, Vector2.ONE * cell_pixels, 0.0, rect.get_center() - middle * cell_pixels
	)
	if not detailed:
		return fitted
	return Transform2D(0.0, Vector2.ONE * _view_scale, 0.0, _view_offset) * fitted


## World layer placement: shrunk to fit the canvas, then zoomed towards `target`.
func _world_transform(target: int, zoom: float) -> Transform2D:
	var middle := size * HALF
	var focus := middle
	var scale_factor := _world_fit_scale()
	if target != NO_BIOME:
		focus = middle.lerp(_island_center(target), zoom)
		scale_factor *= lerpf(1.0, zoom_in_scale, zoom)
	return Transform2D(0.0, Vector2.ONE * scale_factor, 0.0, middle - focus * scale_factor)


## Never enlarges; shrinks so the farthest island still fits on small screens.
func _world_fit_scale() -> float:
	var reach := Vector2.ZERO
	for biome: BiomeMapData in world_map.biomes:
		reach = reach.max(Vector2(biome.world_cell.abs()))
	var extent := (
		reach * island_spacing_pixels + island_size_pixels * HALF + Vector2.ONE * focus_grow_pixels
	)
	var available := size * HALF
	return minf(1.0, minf(available.x / extent.x, available.y / extent.y))


func _island_center(index: int) -> Vector2:
	return size * HALF + Vector2(world_map.biomes[index].world_cell) * island_spacing_pixels


func _island_rect(index: int) -> Rect2:
	return Rect2(_island_center(index) - island_size_pixels * HALF, island_size_pixels)


func _island_rooms_rect(island: Rect2) -> Rect2:
	var top := island.position + Vector2(island_padding_pixels, island_header_pixels)
	var room_area := (
		island.size
		- Vector2(island_padding_pixels * 2.0, island_header_pixels + island_padding_pixels)
	)
	return Rect2(top, room_area)


## Hit-testing only applies on the unzoomed world layer.
func _biome_at(point: Vector2) -> int:
	if world_map == null or zoom_progress > 0.0:
		return NO_BIOME
	var local := _world_transform(NO_BIOME, 0.0).affine_inverse() * point
	for index in world_map.biomes.size():
		if _island_rect(index).has_point(local):
			return index
	return NO_BIOME


func _biome_index(biome_id: StringName) -> int:
	if biome_id.is_empty():
		return NO_BIOME
	return world_map.biomes.find(world_map.find_biome(biome_id))


func _draw_box(
	rect: Rect2, fill: Color, border: Color, border_pixels: int, corner_pixels: int, alpha: float
) -> void:
	_box.bg_color = _faded(fill, alpha)
	_box.draw_center = fill.a > 0.0
	_box.border_color = _faded(border, alpha)
	_box.set_border_width_all(border_pixels)
	_box.set_corner_radius_all(corner_pixels)
	draw_style_box(_box, rect)


func _draw_centered_text(
	text: String,
	left: float,
	middle_y: float,
	width: float,
	font_type: StringName,
	font_size: int,
	color: Color
) -> void:
	var font := get_theme_font(FONT_NAME, font_type)
	var baseline := middle_y + (font.get_ascent(font_size) - font.get_descent(font_size)) * HALF
	draw_string(
		font, Vector2(left, baseline), text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color
	)


func _faded(color: Color, alpha: float) -> Color:
	return Color(color, color.a * alpha)


func _pair_key(first: String, second: String) -> String:
	return first + "|" + second if first < second else second + "|" + first


## Editor preview: every room explored and every biome open, so layout problems show up.
func _use_editor_preview() -> void:
	_progress = MapProgress.new()
	_frontier.clear()
	_unlocked.clear()
	for biome: BiomeMapData in world_map.biomes:
		_unlocked[biome.biome_id] = true
		for room: RoomMapData in biome.rooms:
			_progress.enter_room(room.scene_path)
	_progress.current_room = ""


func _sync_rooms(relayout_all: bool) -> void:
	if world_map == null or world_map.resource_path.is_empty():
		push_warning("WorldMapCanvas: assign a saved WorldMapData resource before syncing.")
		return
	var report := WorldMapSync.sync(world_map, relayout_all)
	var error := ResourceSaver.save(world_map)
	if error != OK:
		push_error("WorldMapCanvas: cannot save %s (%s)." % [world_map.resource_path, error])
		return
	print("World map synced: %s" % world_map.resource_path)
	for line: String in report:
		print("  - " + line)
	world_map.emit_changed()
	queue_redraw()
