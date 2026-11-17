extends Node
## Screen-space atmosphere sits below HUD; water fades in without replacing health feedback.

const ATMOSPHERE_SHADER: Shader = preload(
	"res://gameplay/player/effects/environment_atmosphere.gdshader"
)

@export var player: Player
@export_group("Ambient")
@export var ambient_enabled: bool = true
@export var ambient_tint: Color = Color(1.0, 0.72, 0.43, 1.0)
@export_range(0.0, 0.3, 0.005) var ambient_strength: float = 0.035
@export_range(0.0, 0.3, 0.005) var mote_strength: float = 0.05
@export_range(0.0, 3.0, 0.05) var motion_speed: float = 0.45
@export_group("Shallow Water")
@export var water_enabled: bool = true
@export var water_tint: Color = Color(0.07, 0.53, 0.70, 1.0)
@export_range(0.0, 0.5, 0.01) var water_tint_strength: float = 0.08
@export_range(0.0, 0.7, 0.01) var water_edge_strength: float = 0.22
@export_range(0.0, 0.5, 0.01) var water_shimmer_strength: float = 0.13
@export_range(0.01, 3.0, 0.05, "suffix:s") var water_fade_in: float = 0.4
@export_range(0.01, 3.0, 0.05, "suffix:s") var water_fade_out: float = 0.65
## Time continuously in water before visibility reaches its minimum.
@export_range(0.1, 12.0, 0.1, "suffix:s") var water_full_obscuration_time: float = 12.0

var _water_amount := 0.0
var _water_elapsed := 0.0
var _water_pressure := 0.0
var _material: ShaderMaterial
var _overlay: ColorRect


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.name = "AtmosphereLayer"
	layer.layer = 0
	add_child(layer)
	_overlay = ColorRect.new()
	_overlay.name = "AtmosphereOverlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = ATMOSPHERE_SHADER
	_overlay.material = _material
	layer.add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_refresh_settings()


func _process(delta: float) -> void:
	var wet := (
		water_enabled
		and is_instance_valid(player)
		and not player.dead
		and player.environment_is_water
	)
	var target := 1.0 if wet else 0.0
	var duration := water_fade_in if wet else water_fade_out
	_water_amount = move_toward(_water_amount, target, maxf(delta, 0.0) / maxf(duration, 0.01))
	if wet:
		_water_elapsed = minf(_water_elapsed + maxf(delta, 0.0), water_full_obscuration_time)
		_water_pressure = _water_elapsed / maxf(water_full_obscuration_time, 0.1)
	else:
		_water_elapsed = 0.0
		_water_pressure = move_toward(
			_water_pressure, 0.0, maxf(delta, 0.0) / maxf(water_fade_out, 0.01)
		)
	_material.set_shader_parameter("water_amount", _water_amount)
	_material.set_shader_parameter("water_pressure", _water_pressure)


## Call after changing exported settings at runtime.
func _refresh_settings() -> void:
	_material.set_shader_parameter("ambient_tint", ambient_tint)
	_material.set_shader_parameter("ambient_strength", ambient_strength if ambient_enabled else 0.0)
	_material.set_shader_parameter("mote_strength", mote_strength if ambient_enabled else 0.0)
	_material.set_shader_parameter("motion_speed", motion_speed)
	_material.set_shader_parameter("water_tint", water_tint)
	_material.set_shader_parameter("water_tint_strength", water_tint_strength)
	_material.set_shader_parameter("water_edge_strength", water_edge_strength)
	_material.set_shader_parameter("water_shimmer_strength", water_shimmer_strength)
