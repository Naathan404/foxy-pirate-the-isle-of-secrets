extends Node2D
## Sparse screen-space leaves and curved wind trails. All sizes are reference pixels.
@export_range(0, 40) var leaf_count: int = 12
@export_range(0, 12) var trail_count: int = 4
@export var reference_size := Vector2(1920, 1080)
@export var wind_velocity := Vector2(85, 24)
@export var leaf_color := Color(0.48, 0.38, 0.19, 0.55)
@export var trail_color := Color(0.85, 0.86, 0.73, 0.10)
@export_range(2.0, 20.0) var leaf_size: float = 7.0
@export_range(30.0, 300.0) var trail_length: float = 160.0
@export_range(0.0, 60.0) var sway: float = 22.0
@export_range(0.1, 4.0) var sway_speed: float = 0.8
@export_range(0.5, 12.0) var gust_period: float = 6.0
const TRAIL_SEGMENTS := 20
const WRAP_MARGIN := 100.0
var _elapsed := 0.0
var _seeds: Array[Vector2] = []

func _ready() -> void:
    var random := RandomNumberGenerator.new()
    random.randomize()
    for index in range(leaf_count + trail_count):
        _seeds.append(Vector2(random.randf(), random.randf()))

func _process(delta: float) -> void:
    _elapsed += delta
    queue_redraw()

func _draw() -> void:
    var viewport_size := get_viewport_rect().size
    var ratio := viewport_size / reference_size
    for index in range(_seeds.size()):
        var seed := _seeds[index]
        var phase := seed.x * TAU
        var position_ref := seed * reference_size + wind_velocity * _elapsed
        position_ref.y += sin(_elapsed * sway_speed + phase) * sway
        position_ref.x = fposmod(position_ref.x + WRAP_MARGIN, reference_size.x + WRAP_MARGIN * 2.0) - WRAP_MARGIN
        position_ref.y = fposmod(position_ref.y + WRAP_MARGIN, reference_size.y + WRAP_MARGIN * 2.0) - WRAP_MARGIN
        if index < leaf_count:
            var angle := _elapsed * sway_speed + phase
            var shape := PackedVector2Array()
            var flutter := 0.35 + 0.65 * absf(sin(angle))
            for point in [Vector2(-1, 0), Vector2(0, -0.45 * flutter), Vector2(1, 0), Vector2(0, 0.45 * flutter)]:
                shape.append((position_ref + point.rotated(angle) * leaf_size) * ratio)
            draw_colored_polygon(shape, leaf_color)
        else:
            var points := PackedVector2Array()
            for step in range(TRAIL_SEGMENTS + 1):
                var progress := float(step) / TRAIL_SEGMENTS
                var offset := Vector2(-progress * trail_length, sin(progress * PI) * sway * 0.5)
                points.append((position_ref + offset) * ratio)
            var color := trail_color
            color.a *= pow(maxf(0.0, sin(_elapsed * TAU / gust_period + phase)), 2.0)
            draw_polyline(points, color, maxf(1.0, ratio.y), true)
