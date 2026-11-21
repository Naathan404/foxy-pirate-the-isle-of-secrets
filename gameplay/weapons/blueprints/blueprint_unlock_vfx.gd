extends Control
## Additive drafting instruments, soft ribbons and deterministic paper motes.

const ARC_SEGMENTS := 64
const RIBBON_SEGMENTS := 40
const TICK_COUNT := 48
const MAJOR_TICK_INTERVAL := 4
const MAJOR_TICK_LENGTH := 11.0
const MINOR_TICK_LENGTH := 4.0
const COMPASS_ROTATION_SPEED := 0.12
const INNER_RADIUS_RATIO := 0.87
const REVEAL_FLASH_WIDTH := 0.22
const PARTICLE_ORBIT_SPEED := 0.18
const PARTICLE_DRIFT_PIXELS := 44.0
const PARTICLE_SIZE_PIXELS := 2.0
const SPARK_LENGTH_PIXELS := 7.0
const TAIL_FRACTION := 0.42
const FLIGHT_ARC_PIXELS := 65.0
const IMPACT_STREAK_COUNT := 10
const IMPACT_SPEED_PIXELS := 210.0
const IMPACT_LIFETIME_SECONDS := 1.0
const GLOW_WIDTHS := [20.0, 10.0, 3.0, 1.0]
const GLOW_ALPHAS := [0.025, 0.055, 0.28, 0.8]
const PHYLLOTAXIS_ANGLE := 2.399963
const HALO_LAYERS := 14
const HALO_OPACITY := 0.008
const RING_OPACITY := 0.36
const DRAFT_LINE_OPACITY := 0.16
const PAPER_COLOR := Color("ffe4ae")
const CORE_COLOR := Color("fff8de")
const ENERGY_STREAM_COUNT := 3
const ENERGY_SPEED_RADIANS := 1.6
const ENERGY_ARC_RADIANS := 1.9
const ENERGY_ORBIT_FLATTENING := 0.48
const ENERGY_OPACITY := 0.75
const REVEAL_RAY_COUNT := 12
const REVEAL_RAY_LENGTH := 95.0
const FLECK_COUNT := 26
const FLECK_RISE_PIXELS := 120.0
const FLECK_SPREAD_PIXELS := 150.0
const FLECK_FALL_PIXELS := 70.0
const FLECK_SIZE_PIXELS := 5.0

@export var gold_color := Color("efb459")
@export_range(80.0, 240.0, 1.0) var compass_radius_pixels := 150.0
@export_range(8, 100, 1) var mote_count := 42

var _center := Vector2.ZERO
var _destination := Vector2.ZERO
var _high := Vector2.ZERO
var _clock := 0.0
var _reveal := 0.0
var _alpha := 0.0
var _flight := 0.0
var _impact := -1.0


func _draw() -> void:
	if _alpha > 0.0:
		_draw_halo()
		_draw_compass()
		_draw_energy()
		_draw_motes()
		if _flight > 0.0:
			_draw_flight()
	if _impact >= 0.0:
		_draw_impact()


func present(
	center: Vector2,
	destination: Vector2,
	high: Vector2,
	clock: float,
	reveal: float,
	alpha: float,
	flight: float,
	impact: float
) -> void:
	_center = center
	_destination = destination
	_high = high
	_clock = clock
	_reveal = reveal
	_alpha = alpha
	_flight = flight
	_impact = impact
	queue_redraw()


func _draw_halo() -> void:
	var flash := pow(sin(_reveal * PI), 8.0)
	for layer_index in range(HALO_LAYERS, 0, -1):
		var fraction := float(layer_index) / HALO_LAYERS
		draw_circle(
			_center,
			compass_radius_pixels * fraction,
			Color(gold_color, _alpha * HALO_OPACITY * (1.0 + flash))
		)
	# A single expanding light ring punctuates the paper opening.
	if _reveal > 0.0 and _reveal < 1.0:
		var radius := compass_radius_pixels * (1.0 + _reveal)
		var points := _arc(_center, radius, 0.0, TAU)
		_glow_line(points, _alpha * sin(_reveal * PI) * REVEAL_FLASH_WIDTH)


func _draw_compass() -> void:
	var opacity := _alpha * _reveal * (1.0 - _flight)
	if opacity <= 0.0:
		return
	var rotation_angle := _clock * COMPASS_ROTATION_SPEED
	for quadrant in range(4):
		var angle := quadrant * TAU / 4.0 + rotation_angle
		var points := _arc(_center, compass_radius_pixels, angle, PI / 3.0)
		_glow_line(points, opacity * RING_OPACITY)
	draw_arc(
		_center,
		compass_radius_pixels * INNER_RADIUS_RATIO,
		0.0,
		TAU * _reveal,
		ARC_SEGMENTS,
		Color(gold_color, opacity * RING_OPACITY),
		1.0,
		true
	)
	for tick in range(TICK_COUNT):
		var angle := tick * TAU / TICK_COUNT - rotation_angle
		var direction := Vector2.from_angle(angle)
		var length := MAJOR_TICK_LENGTH if tick % MAJOR_TICK_INTERVAL == 0 else MINOR_TICK_LENGTH
		draw_line(
			_center + direction * compass_radius_pixels,
			_center + direction * (compass_radius_pixels + length),
			Color(PAPER_COLOR, opacity * RING_OPACITY),
			1.0,
			true
		)
	# Drafting corner brackets frame the artwork without crossing its silhouette.
	for corner in range(4):
		var direction := Vector2.from_angle(PI / 4.0 + corner * TAU / 4.0)
		var point := _center + direction * compass_radius_pixels
		var horizontal := Vector2(signf(direction.x) * MAJOR_TICK_LENGTH, 0.0)
		var vertical := Vector2(0.0, signf(direction.y) * MAJOR_TICK_LENGTH)
		draw_polyline(
			PackedVector2Array([point - horizontal, point, point - vertical]),
			Color(PAPER_COLOR, opacity),
			1.0,
			true
		)
		var endpoint := point + direction * PARTICLE_DRIFT_PIXELS
		draw_line(point, endpoint, Color(gold_color, opacity * DRAFT_LINE_OPACITY), 1.0, true)
		_spark(endpoint, PARTICLE_SIZE_PIXELS, opacity)


func _draw_energy() -> void:
	var opacity := _alpha * _reveal * (1.0 - _flight)
	for stream in range(ENERGY_STREAM_COUNT):
		var points := PackedVector2Array()
		var tilt := stream * PI / ENERGY_STREAM_COUNT
		var head := _clock * ENERGY_SPEED_RADIANS + stream * TAU / ENERGY_STREAM_COUNT
		for segment in range(RIBBON_SEGMENTS):
			var fraction := float(segment) / (RIBBON_SEGMENTS - 1)
			var angle := head - ENERGY_ARC_RADIANS * fraction
			var ellipse := Vector2(cos(angle), sin(angle) * ENERGY_ORBIT_FLATTENING)
			points.append(_center + ellipse.rotated(tilt) * compass_radius_pixels)
		_glow_line(points, opacity * ENERGY_OPACITY)
	# Short radial glints, only during the reveal; the reading phase stays calm.
	var flash := pow(sin(_reveal * PI), 4.0) * _alpha
	if flash <= 0.0:
		return
	for ray in range(REVEAL_RAY_COUNT):
		var direction := Vector2.from_angle(ray * TAU / REVEAL_RAY_COUNT)
		var start := _center + direction * compass_radius_pixels
		var end := start + direction * REVEAL_RAY_LENGTH * _reveal
		_glow_line(PackedVector2Array([start, start.lerp(end, 0.5), end]), flash)


func _draw_motes() -> void:
	for index in range(mote_count):
		var seed_angle := float(index) * PHYLLOTAXIS_ANGLE
		var cycle := fposmod(_clock * PARTICLE_ORBIT_SPEED + float(index) / mote_count, 1.0)
		var direction := Vector2.from_angle(seed_angle + _clock * PARTICLE_ORBIT_SPEED)
		var radius := compass_radius_pixels * (1.0 + cycle)
		var position_on_ring := _center + direction * radius
		position_on_ring.y -= cycle * PARTICLE_DRIFT_PIXELS
		var opacity := sin(cycle * PI) * _alpha * (1.0 - _flight)
		if index % MAJOR_TICK_INTERVAL == 0:
			_spark(position_on_ring, SPARK_LENGTH_PIXELS * sin(cycle * PI), opacity)
		else:
			# Thin tumbling paper flecks with continuous size and fade, no random popping.
			var axis := Vector2.from_angle(seed_angle + _clock)
			draw_line(
				position_on_ring - axis * PARTICLE_SIZE_PIXELS,
				position_on_ring + axis * PARTICLE_SIZE_PIXELS,
				Color(PAPER_COLOR, opacity),
				PARTICLE_SIZE_PIXELS * absf(sin(seed_angle + _clock)),
				true
			)


func _draw_flight() -> void:
	var points := PackedVector2Array()
	for segment in range(RIBBON_SEGMENTS):
		var fraction := float(segment) / (RIBBON_SEGMENTS - 1)
		var progress := maxf(0.0, _flight - TAIL_FRACTION * (1.0 - fraction))
		var point := _high.lerp(_destination, progress)
		point.y -= sin(progress * PI) * FLIGHT_ARC_PIXELS
		points.append(point)
	_glow_line(points, _alpha)
	for side: float in [-1.0, 1.0]:
		var companion := PackedVector2Array()
		for segment in range(points.size()):
			var fraction := float(segment) / (points.size() - 1)
			var offset := sin(fraction * PI) * MAJOR_TICK_LENGTH * side
			companion.append(points[segment] + Vector2(offset, 0.0))
		_glow_line(companion, _alpha * RING_OPACITY)
	_spark(_center, SPARK_LENGTH_PIXELS, _alpha)


func _draw_impact() -> void:
	var progress := clampf(_impact / IMPACT_LIFETIME_SECONDS, 0.0, 1.0)
	var opacity := pow(1.0 - progress, 2.0)
	var radius := MAJOR_TICK_LENGTH + _impact * IMPACT_SPEED_PIXELS
	for streak in range(IMPACT_STREAK_COUNT):
		var angle := streak * TAU / IMPACT_STREAK_COUNT
		var points := _arc(_destination, radius, angle, PI / IMPACT_STREAK_COUNT)
		_glow_line(points, opacity)
	for index in range(mote_count):
		var direction := Vector2.from_angle(index * PHYLLOTAXIS_ANGLE)
		var distance := radius * (1.0 + float(index % 3) / 3.0)
		var point := _destination + direction * distance
		_spark(point, SPARK_LENGTH_PIXELS * opacity, opacity)
	_draw_flecks(progress, opacity)


## Paper flecks burst up from Foxy and drift down, as if the rolled plan had unfurled on arrival.
func _draw_flecks(progress: float, opacity: float) -> void:
	for index in range(FLECK_COUNT):
		var seed_angle := float(index) * PHYLLOTAXIS_ANGLE
		var spread := sin(seed_angle * 3.0)
		var burst := 1.0 - pow(1.0 - progress, 2.0)
		var at := _destination + Vector2(spread * FLECK_SPREAD_PIXELS * burst, 0.0)
		at.y -= FLECK_RISE_PIXELS * burst * (0.5 + 0.5 * absf(cos(seed_angle)))
		at.y += FLECK_FALL_PIXELS * progress * progress
		var axis := Vector2.from_angle(seed_angle + _impact * 6.0)
		draw_line(
			at - axis * FLECK_SIZE_PIXELS,
			at + axis * FLECK_SIZE_PIXELS,
			Color(PAPER_COLOR, opacity),
			FLECK_SIZE_PIXELS * 0.6 * absf(sin(seed_angle + _impact * 4.0)) + 1.0,
			true
		)


func _arc(center: Vector2, radius: float, angle: float, sweep: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for segment in range(ARC_SEGMENTS + 1):
		var fraction := float(segment) / ARC_SEGMENTS
		points.append(center + Vector2.from_angle(angle + sweep * fraction) * radius)
	return points


func _glow_line(points: PackedVector2Array, opacity: float) -> void:
	if points.size() < 2 or opacity <= 0.0:
		return
	for layer_index in range(GLOW_WIDTHS.size()):
		var tint := CORE_COLOR if layer_index == GLOW_WIDTHS.size() - 1 else gold_color
		# Segment-wise taper removes square ends; brightness grows toward the moving head.
		for segment in range(1, points.size()):
			var fraction := float(segment) / (points.size() - 1)
			var taper := sin(fraction * PI)
			draw_line(
				points[segment - 1],
				points[segment],
				Color(tint, opacity * GLOW_ALPHAS[layer_index] * taper),
				maxf(1.0, GLOW_WIDTHS[layer_index] * taper),
				true
			)


func _spark(center: Vector2, radius: float, opacity: float) -> void:
	draw_circle(center, radius, Color(gold_color, opacity * GLOW_ALPHAS[1]))
	draw_line(
		center - Vector2(radius, 0.0),
		center + Vector2(radius, 0.0),
		Color(CORE_COLOR, opacity),
		1.0,
		true
	)
	draw_line(
		center - Vector2(0.0, radius),
		center + Vector2(0.0, radius),
		Color(CORE_COLOR, opacity),
		1.0,
		true
	)
