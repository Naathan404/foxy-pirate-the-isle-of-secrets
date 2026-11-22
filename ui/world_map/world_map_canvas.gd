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
@export_range(0.5, 10.0, 0.1) var pulse_speed: float = 3.5
@export_range(0.0, 12.0, 0.5, "suffix:px") var pulse_grow_pixels: float = 5.0

@export_group("Colours")
@export var ink_color: Color = Color(0.1, 0.07, 0.09)
@export var unknown_color: Color = Color(0.2, 0.17, 0.19)
@export var text_color: Color = Color(0.98, 0.93, 0.86)
@export var muted_color: Color = Color(0.77, 0.61, 0.53)
@export var highlight_color: Color = Color(0.96, 0.89, 0.77)
@export var checkpoint_color: Color = Color(0.98, 0.6, 0.3)
@export_range(8, 64, 1) var name_font_size: int = 28
@export_range(8, 40, 1) var detail_font_size: int = 18

var focused_index: int = NO_BIOME:
	set(value):
		focused_index = value
		queue_redraw()
var zoom_index: int = NO_BIOME:
	set(value):
		zoom_index = value
		queue_redraw()
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
var _hovered_index: int = NO_BIOME
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
	if motion != null:
		var index := _biome_at(motion.position)
		if index != _hovered_index:
			_hovered_index = index
			if index != NO_BIOME:
				biome_hovered.emit(index)
		return
	var button := event as InputEventMouseButton
	if button == null or not button.pressed:
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
	queue_redraw()


func get_status(index: int) -> BiomeMapData.Status:
	var biome := world_map.biomes[index]
	return biome.get_status(_progress, _unlocked.get(biome.biome_id, false))


func get_progress() -> MapProgress:
	return _progress


func get_current_biome_index() -> int:
	return world_map.biomes.find(world_map.find_biome_of_room(_progress.current_room))


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
	# Grow the rooms out of their island so the two layers read as one zoom.
	var start := _world_transform(target, zoom) * _island_rooms_rect(_island_rect(target))
	var rect := Rect2(start.position.lerp(Vector2.ZERO, zoom), start.size.lerp(size, zoom))
	_draw_rooms(target, rect, zoom, true)


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
		if room.hidden and not visited:
			continue
		var center := grid * Vector2(room.cell)
		var room_size := cell_pixels * room_fill_ratio
		var rect_room := Rect2(center - Vector2.ONE * room_size * HALF, Vector2.ONE * room_size)
		var fill := biome.accent if visited else ink_color
		var border := ink_color if visited else _faded(muted_color, HALF)
		var corner := room_corner_pixels if detailed else 0
		_draw_box(rect_room, fill, border, room_border_pixels if detailed else 0, corner, alpha)
		if detailed and visited:
			_draw_exits(biome, room, center, room_size, alpha)
			_draw_marker(room.marker, center, room_size, alpha)
		if room.scene_path == _progress.current_room:
			_draw_current(rect_room, room_size, alpha, detailed)


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
			# Leave the room straight out of its door, cross the gap, then enter the other.
			var step := Vector2(RoomMapData.offset_of(direction)) * half_cell
			var from := grid * Vector2(room.cell)
			var to := grid * Vector2(other.cell)
			draw_polyline(
				PackedVector2Array([from, from + step, to - step, to]),
				_faded(muted_color, alpha),
				link_width_pixels,
				true
			)


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


## Rooms are drawn on a known room's side only; a door into a hidden room stays a secret.
func _is_link_visible(room: RoomMapData, other: RoomMapData) -> bool:
	var room_visited := _progress.has_visited(room.scene_path)
	var other_visited := _progress.has_visited(other.scene_path)
	if (room.hidden and not room_visited) or (other.hidden and not other_visited):
		return false
	return room_visited or other_visited


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
	return Transform2D(
		0.0, Vector2.ONE * cell_pixels, 0.0, rect.get_center() - middle * cell_pixels
	)


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
