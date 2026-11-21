class_name FlatTideWarningOverlay
extends CanvasLayer
## Screen-edge warning for an incoming flat tide: a red glow pulses on every side of the screen
## the water will come from. FlatTideController owns it and feeds directions and strengths.

const OVERLAY_SHADER := preload("res://world/gimmick/flat_tide/flat_tide_warning_overlay.gdshader")
## Same layer as the player's other vignettes: above the world, below the HUD.
const OVERLAY_LAYER := 0
## Must match MAX_DIRECTIONS in the shader.
const MAX_DIRECTIONS := 4

var _rect: ColorRect
var _material: ShaderMaterial
var _pulse_phase: float = 0.0
var _flow_phase: float = 0.0


func _ready() -> void:
	layer = OVERLAY_LAYER
	_material = ShaderMaterial.new()
	_material.shader = OVERLAY_SHADER
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _material
	add_child(_rect)
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.hide()


func configure(color: Color, edge_width: float) -> void:
	_material.set_shader_parameter("warning_color", color)
	_material.set_shader_parameter("edge_width", edge_width)


## `directions` point at the screen edges the water comes from (y down), each with its own
## entry in `strengths`; extra entries beyond MAX_DIRECTIONS are ignored. `pulse_hz` sets how
## fast the glow breathes; `delta` comes from the tide clock so pause freezes it.
func show_warning(
	directions: PackedVector2Array,
	strengths: PackedFloat32Array,
	pulse_hz: float,
	flow_speed: float,
	delta: float
) -> void:
	var slot_directions := PackedVector2Array()
	var slot_strengths := PackedFloat32Array()
	slot_directions.resize(MAX_DIRECTIONS)
	slot_strengths.resize(MAX_DIRECTIONS)
	var any := false
	for index in range(mini(MAX_DIRECTIONS, mini(directions.size(), strengths.size()))):
		slot_directions[index] = directions[index]
		slot_strengths[index] = clampf(strengths[index], 0.0, 1.0)
		any = any or slot_strengths[index] > 0.0
	if not any:
		hide_warning()
		return
	_pulse_phase = fmod(_pulse_phase + delta * pulse_hz * TAU, TAU)
	_flow_phase = fmod(_flow_phase + delta * flow_speed * TAU, TAU)
	_material.set_shader_parameter("directions", slot_directions)
	_material.set_shader_parameter("strengths", slot_strengths)
	_material.set_shader_parameter("pulse", 0.5 - 0.5 * cos(_pulse_phase))
	_material.set_shader_parameter("flow_phase", _flow_phase)
	_rect.show()


func hide_warning() -> void:
	if _rect.visible:
		_rect.hide()
	_pulse_phase = 0.0
