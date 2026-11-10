class_name LowHealthVignette
extends Node
## Persistent screen edge warning driven only by the player's health ratio.

const VIGNETTE_SHADER: Shader = preload(
	"res://gameplay/player/effects/low_health_vignette.gdshader"
)
const FULL_CYCLE_RADIANS: float = TAU

@export var health: HealthComponent

@export_group("Low Health Vignette")
@export_range(0.01, 1.0, 0.01) var health_threshold: float = 0.30
@export var edge_color: Color = Color(0.8, 0.025, 0.015, 1.0)
@export_range(0.0, 1.0, 0.01) var edge_start: float = 0.35
@export_range(0.0, 1.0, 0.01) var base_strength: float = 0.38
@export_range(0.0, 1.0, 0.01) var pulse_strength: float = 0.12
@export_range(0.1, 10.0, 0.1) var breath_cycle_seconds: float = 1.8
@export_range(0.0, 2.0, 0.01) var fade_in_seconds: float = 0.3
@export_range(0.0, 2.0, 0.01) var fade_out_seconds: float = 0.55

var _overlay: ColorRect
var _material: ShaderMaterial
var _transition: Tween
var _visibility: float = 0.0
var _breath_time: float = 0.0
var _active: bool = false


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	_overlay = ColorRect.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = VIGNETTE_SHADER
	_overlay.material = _material
	layer.add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.hide()
	_material.set_shader_parameter("edge_color", edge_color)
	_material.set_shader_parameter("edge_start", edge_start)
	if is_instance_valid(health):
		health.hp_changed.connect(_on_hp_changed)
		_on_hp_changed(health.get_current_hp(), health.get_max_hp())


func _process(delta: float) -> void:
	if not _overlay.visible:
		return
	_breath_time += delta
	var phase := _breath_time * FULL_CYCLE_RADIANS / breath_cycle_seconds
	var strength := base_strength + pulse_strength * 0.5 * (1.0 - cos(phase))
	_material.set_shader_parameter("strength", clampf(strength * _visibility, 0.0, 1.0))


func _on_hp_changed(current_hp: float, max_hp: float) -> void:
	var should_show := max_hp > 0.0 and current_hp > 0.0 and current_hp / max_hp <= health_threshold
	if should_show == _active:
		return
	_active = should_show
	if _transition != null and _transition.is_valid():
		_transition.kill()
	if should_show:
		_breath_time = 0.0
		_overlay.show()
	_transition = create_tween().set_ignore_time_scale(true)
	(
		_transition
		. tween_property(
			self,
			"_visibility",
			1.0 if should_show else 0.0,
			fade_in_seconds if should_show else fade_out_seconds
		)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	if not should_show:
		_transition.tween_callback(_hide_if_inactive)


func _hide_if_inactive() -> void:
	if not _active:
		_overlay.hide()
