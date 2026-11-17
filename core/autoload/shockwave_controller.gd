extends CanvasLayer
## Reusable screen-space refraction wave. Works during pause and hitstop.

@export_range(0.05, 3.0, 0.05) var maximum_duration := 2.0
@export_range(0.0, 0.1, 0.001) var maximum_strength := 0.08
var _rect: ColorRect
var _material: ShaderMaterial
var _started_usec := 0
var _duration := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
	uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
	uniform vec2 center = vec2(0.5);
	uniform float progress = 0.0;
	uniform float strength = 0.02;
	uniform float aspect = 1.777;
	uniform float max_radius = 1.3;
	uniform vec4 tint : source_color = vec4(0.34, 1.0, 0.8, 1.0);
	void fragment() {
		vec2 diff = (SCREEN_UV - center) * vec2(aspect, 1.0);
		float dist = length(diff);
		float radius = mix(0.01, max_radius, progress);
		float band = exp(-pow((dist - radius) / 0.065, 2.0));
		float fade = pow(1.0 - progress, 0.55) * smoothstep(0.0, 0.05, progress);
		vec2 dir = diff / max(dist, 0.0001);
		vec2 offset = dir / vec2(aspect, 1.0) * band * strength * fade;
		vec3 scene = texture(screen_texture, clamp(SCREEN_UV - offset, vec2(0.001), vec2(0.999))).rgb;
		vec3 light = tint.rgb * band * fade * 0.26;
		COLOR = vec4(scene + light, 1.0);
	}"""
	_material = ShaderMaterial.new()
	_material.shader = shader
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _material
	_rect.hide()
	add_child(_rect)
	set_process(false)


## Coordinates are viewport pixels. A new request replaces the active wave.
func request_screen(
	position: Vector2,
	duration: float = 0.65,
	strength: float = 0.022,
	tint: Color = Color("5dffd1")
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
	_material.set_shader_parameter("max_radius", corner_offset.length() * 1.12)
	_material.set_shader_parameter("strength", minf(strength, maximum_strength))
	_material.set_shader_parameter("tint", tint)
	_material.set_shader_parameter("progress", 0.0)
	_rect.show()
	set_process(true)


## Project any visible world position through the active camera.
func request_world(
	position: Vector3,
	duration: float = 0.65,
	strength: float = 0.022,
	tint: Color = Color("5dffd1")
) -> void:
	var camera := get_viewport().get_camera_3d()
	if not is_instance_valid(camera) or camera.is_position_behind(position):
		return
	request_screen(camera.unproject_position(position), duration, strength, tint)


func _process(_delta: float) -> void:
	var progress := float(Time.get_ticks_usec() - _started_usec) / 1000000.0 / _duration
	if progress >= 1.0:
		cancel()
		return
	_material.set_shader_parameter("progress", clampf(progress, 0.0, 1.0))


func cancel() -> void:
	if is_instance_valid(_rect):
		_rect.hide()
	_duration = 0.0
	set_process(false)
