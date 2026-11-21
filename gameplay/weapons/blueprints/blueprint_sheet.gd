extends Control
## Blue drafting sheet that unrolls behind the blueprint icon. It is the visual proof that this
## reward is a plan to forge from, not the weapon itself. Normal blending, drawn under the icon.

const SHEET_CORNER_RADIUS := 8
const SHEET_BORDER_WIDTH := 2
const SHADOW_OFFSET_PIXELS := Vector2(7.0, 10.0)
const SHADOW_ALPHA := 0.35
const GRID_MINOR_PIXELS := 20.0
const GRID_MAJOR_EVERY := 5
const GRID_MINOR_ALPHA := 0.09
const GRID_MAJOR_ALPHA := 0.2
const MARGIN_PIXELS := 14.0
const BRACKET_LENGTH_PIXELS := 18.0
const DIMENSION_INSET_PIXELS := 9.0
const DIMENSION_TICK_PIXELS := 5.0
const DIMENSION_ALPHA := 0.55
const SWAY_DEGREES := 1.4
const SWAY_SPEED := 1.3
const OPEN_WIDTH_FRACTION := 0.45
const STAMP_RING_SECONDS := 0.45
const STAMP_RING_RADIUS_PIXELS := 78.0
const STAMP_RING_WIDTH_PIXELS := 4.0
const RING_SEGMENTS := 48

@export var paper_color := Color(0.1, 0.23, 0.37, 0.93)
@export var line_color := Color(0.62, 0.82, 0.96)
@export var border_color := Color(1.0, 0.88, 0.63)
@export_range(100.0, 400.0, 1.0, "suffix:px") var sheet_width_pixels := 224.0
@export_range(100.0, 400.0, 1.0, "suffix:px") var sheet_height_pixels := 240.0

var _center := Vector2.ZERO
var _open := 0.0
var _alpha := 0.0
var _clock := 0.0
var _stamp_point := Vector2.ZERO
var _stamp_since := -1.0
var _style := StyleBoxFlat.new()


func _ready() -> void:
	_style.set_corner_radius_all(SHEET_CORNER_RADIUS)
	_style.set_border_width_all(SHEET_BORDER_WIDTH)
	_style.anti_aliasing = true


func _draw() -> void:
	if _alpha <= 0.0 or _open <= 0.0:
		return
	var half := (
		Vector2(
			sheet_width_pixels * lerpf(OPEN_WIDTH_FRACTION, 1.0, smoothstep(0.3, 1.0, _open)),
			sheet_height_pixels * smoothstep(0.0, 0.7, _open)
		)
		/ 2.0
	)
	draw_set_transform(_center, sin(_clock * SWAY_SPEED) * deg_to_rad(SWAY_DEGREES), Vector2.ONE)
	_style.bg_color = Color(0.0, 0.0, 0.0, SHADOW_ALPHA * _alpha)
	_style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	draw_style_box(_style, Rect2(-half + SHADOW_OFFSET_PIXELS, half * 2.0))
	_style.bg_color = Color(paper_color, paper_color.a * _alpha)
	_style.border_color = Color(border_color, _alpha)
	draw_style_box(_style, Rect2(-half, half * 2.0))
	_draw_grid(half)
	_draw_brackets(half)
	_draw_dimensions(half)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_stamp_ring()


## Places the sheet. `open` unrolls it, `stamp_since` is seconds since the stamp landed (<0: none).
func present(
	center: Vector2,
	open: float,
	alpha: float,
	clock: float,
	stamp_point: Vector2,
	stamp_since: float
) -> void:
	_center = center
	_open = open
	_alpha = alpha
	_clock = clock
	_stamp_point = stamp_point
	_stamp_since = stamp_since
	queue_redraw()


func _draw_grid(half: Vector2) -> void:
	var inner := half - Vector2.ONE * MARGIN_PIXELS
	var index := 0
	var x := -inner.x
	while x <= inner.x:
		var major := index % GRID_MAJOR_EVERY == 0
		var alpha := GRID_MAJOR_ALPHA if major else GRID_MINOR_ALPHA
		draw_line(Vector2(x, -inner.y), Vector2(x, inner.y), Color(line_color, alpha * _alpha), 1.0)
		x += GRID_MINOR_PIXELS
		index += 1
	index = 0
	var y := -inner.y
	while y <= inner.y:
		var major := index % GRID_MAJOR_EVERY == 0
		var alpha := GRID_MAJOR_ALPHA if major else GRID_MINOR_ALPHA
		draw_line(Vector2(-inner.x, y), Vector2(inner.x, y), Color(line_color, alpha * _alpha), 1.0)
		y += GRID_MINOR_PIXELS
		index += 1


func _draw_brackets(half: Vector2) -> void:
	var inner := half - Vector2.ONE * MARGIN_PIXELS
	var color := Color(border_color, _alpha * DIMENSION_ALPHA)
	for corner_x in [-1.0, 1.0]:
		for corner_y in [-1.0, 1.0]:
			var corner := Vector2(corner_x * inner.x, corner_y * inner.y)
			draw_polyline(
				PackedVector2Array(
					[
						corner - Vector2(corner_x * BRACKET_LENGTH_PIXELS, 0.0),
						corner,
						corner - Vector2(0.0, corner_y * BRACKET_LENGTH_PIXELS)
					]
				),
				color,
				1.5,
				true
			)


## Dimension lines along the bottom and left edge, like measurements on a technical drawing.
func _draw_dimensions(half: Vector2) -> void:
	var color := Color(line_color, _alpha * DIMENSION_ALPHA)
	var inner := half - Vector2.ONE * (MARGIN_PIXELS + DIMENSION_INSET_PIXELS)
	var bottom := inner.y + DIMENSION_INSET_PIXELS * 0.5
	draw_line(Vector2(-inner.x, bottom), Vector2(inner.x, bottom), color, 1.0, true)
	var left := -inner.x - DIMENSION_INSET_PIXELS * 0.5
	draw_line(Vector2(left, -inner.y), Vector2(left, inner.y), color, 1.0, true)
	for end_x in [-inner.x, inner.x]:
		draw_line(
			Vector2(end_x, bottom - DIMENSION_TICK_PIXELS),
			Vector2(end_x, bottom + DIMENSION_TICK_PIXELS),
			color,
			1.0
		)
	for end_y in [-inner.y, inner.y]:
		draw_line(
			Vector2(left - DIMENSION_TICK_PIXELS, end_y),
			Vector2(left + DIMENSION_TICK_PIXELS, end_y),
			color,
			1.0
		)


func _draw_stamp_ring() -> void:
	if _stamp_since < 0.0 or _stamp_since > STAMP_RING_SECONDS:
		return
	var life := 1.0 - _stamp_since / STAMP_RING_SECONDS
	var radius := STAMP_RING_RADIUS_PIXELS * (1.0 - life * life) + 8.0
	draw_arc(
		_stamp_point,
		radius,
		0.0,
		TAU,
		RING_SEGMENTS,
		Color(border_color, life * 0.7 * _alpha),
		STAMP_RING_WIDTH_PIXELS * life,
		true
	)
