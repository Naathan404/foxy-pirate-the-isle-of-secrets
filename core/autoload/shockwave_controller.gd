extends CanvasLayer
## Reusable screen-space refraction wave. Works during pause and hitstop.

const SHOCKWAVE_SHADER := preload("res://core/autoload/shockwave.gdshader")
const OVERLAY_LAYER := 90
const DEFAULT_DURATION := 0.65
const DEFAULT_STRENGTH := 0.022
const DEFAULT_TINT := Color("5dffd1")
const FULL_SCREEN_PADDING := 1.12
const MIN_RADIUS := 0.02
const MIN_BAND_WIDTH := 0.008
const MAX_BAND_WIDTH := 0.065
const BAND_RADIUS_RATIO := 0.18
const LOCAL_LIGHT_STRENGTH := 0.08
const FULL_SCREEN_LIGHT_STRENGTH := 0.26
const MICROSECONDS_PER_SECOND := 1000000.0

@export_range(0.05, 3.0, 0.05) var maximum_duration := 2.0
@export_range(0.0, 0.1, 0.001) var maximum_strength := 0.08
var _rect: ColorRect
var _material: ShaderMaterial
var _started_usec := 0
var _duration := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = OVERLAY_LAYER
	_material = ShaderMaterial.new()
	_material.shader = SHOCKWAVE_SHADER
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _material
	_rect.hide()
	add_child(_rect)
	set_process(false)


## Coordinates and optional radius are viewport pixels. Radius 0 covers the screen.
## A new request replaces the active wave.
func request_screen(
	position: Vector2,
	duration: float = DEFAULT_DURATION,
	strength: float = DEFAULT_STRENGTH,
	tint: Color = DEFAULT_TINT,
	radius_pixels: float = 0.0
) -> void:
	if duration <= 0.0 or strength <= 0.0 or not is_instance_valid(_rect):
		return
	var size := get_viewport().get_visible_rect().size
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_duration = minf(duration, maximum_duration)
	_started_usec = Time.get_ticks_usec()
	_material.set_shader_parameter("center", position / size)
	_material.set_shader_parameter("aspect", size.x / size.y)
	var center := position / size
	var corner_offset := Vector2(
		maxf(absf(center.x), absf(1.0 - center.x)) * size.x / size.y,
		maxf(absf(center.y), absf(1.0 - center.y))
	)
	var radius := corner_offset.length() * FULL_SCREEN_PADDING
	if radius_pixels > 0.0:
		radius = maxf(MIN_RADIUS, radius_pixels / size.y)
	_material.set_shader_parameter("max_radius", radius)
	_material.set_shader_parameter(
		"band_width", clampf(radius * BAND_RADIUS_RATIO, MIN_BAND_WIDTH, MAX_BAND_WIDTH)
	)
	_material.set_shader_parameter("local_wave", 1.0 if radius_pixels > 0.0 else 0.0)
	_material.set_shader_parameter(
		"light_strength",
		LOCAL_LIGHT_STRENGTH if radius_pixels > 0.0 else FULL_SCREEN_LIGHT_STRENGTH
	)
	_material.set_shader_parameter("strength", minf(strength, maximum_strength))
	_material.set_shader_parameter("tint", tint)
	_material.set_shader_parameter("progress", 0.0)
	_rect.show()
	set_process(true)


## Project any visible world position through the active camera.
func request_world(
	position: Vector3,
	duration: float = DEFAULT_DURATION,
	strength: float = DEFAULT_STRENGTH,
	tint: Color = DEFAULT_TINT,
	radius_pixels: float = 0.0
) -> void:
	var camera := get_viewport().get_camera_3d()
	if not is_instance_valid(camera) or camera.is_position_behind(position):
		return
	request_screen(camera.unproject_position(position), duration, strength, tint, radius_pixels)


func _process(_delta: float) -> void:
	var progress := (
		float(Time.get_ticks_usec() - _started_usec) / MICROSECONDS_PER_SECOND / _duration
	)
	if progress >= 1.0:
		cancel()
		return
	_material.set_shader_parameter("progress", clampf(progress, 0.0, 1.0))


func cancel() -> void:
	if is_instance_valid(_rect):
		_rect.hide()
	_duration = 0.0
	set_process(false)
