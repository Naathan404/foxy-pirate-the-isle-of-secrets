class_name BackdropSprite
extends Sprite3D
## Large scenery standing in the water around an arena: pillars, sea stacks, giant moss.
## No collision and no gameplay. The texture's bottom edge is the base, so the node sits where
## the object meets the water; `sway` reuses the destructible props' wind shader for kelp and moss.

const WIND_SHADER: Shader = preload("res://world/objects/destructible_wind.gdshader")

@export var sway: bool = false
@export_range(0.0, 1.0, 0.01) var sway_amplitude: float = 0.08
@export_range(0.0, 10.0, 0.1) var sway_speed: float = 1.4
@export_range(0.0, 1.0, 0.01) var sway_gust: float = 0.15
## Share of the height that stays still at the base.
@export_range(0.0, 1.0, 0.01) var sway_root_height: float = 0.2


func _ready() -> void:
	if texture == null:
		return
	offset = Vector2(0.0, texture.get_height() * 0.5)
	if not sway:
		return
	var material := ShaderMaterial.new()
	material.shader = WIND_SHADER
	material.set_shader_parameter("sprite_texture", texture)
	material.set_shader_parameter("frame_uv", Vector4(0.0, 0.0, 1.0, 1.0))
	material.set_shader_parameter("sprite_width", texture.get_width() * pixel_size)
	material.set_shader_parameter("wind_amplitude", sway_amplitude)
	material.set_shader_parameter("wind_speed", sway_speed)
	material.set_shader_parameter("gust_strength", sway_gust)
	material.set_shader_parameter("root_height", sway_root_height)
	material.set_shader_parameter("wind_phase", fposmod(float(get_instance_id()), TAU))
	material.set_shader_parameter("horizontal_uv_direction", -1.0 if flip_h else 1.0)
	material.set_shader_parameter("vertical_uv_direction", 1.0)
	material_override = material
