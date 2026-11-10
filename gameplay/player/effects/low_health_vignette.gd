class_name LowHealthVignette
extends Node
## Màu viền phản ánh máu thấp hoặc trạng thái đứng trong nước.

const VIGNETTE_SHADER: Shader = preload(
	"res://gameplay/player/effects/low_health_vignette.gdshader"
)
const FULL_CYCLE_RADIANS: float = TAU

@export var health: HealthComponent
## Nhân vật cung cấp trạng thái đang đứng trong nước.
@export var player: Player

@export_group("Low Health Vignette")
@export_range(0.01, 1.0, 0.01) var health_threshold: float = 0.30
@export var edge_color: Color = Color(0.8, 0.025, 0.015, 1.0)
@export_range(0.0, 1.0, 0.01) var edge_start: float = 0.35
@export_range(0.0, 1.0, 0.01) var base_strength: float = 0.38
@export_range(0.0, 1.0, 0.01) var pulse_strength: float = 0.12
@export_range(0.1, 10.0, 0.1) var breath_cycle_seconds: float = 1.8
@export_range(0.0, 2.0, 0.01) var fade_in_seconds: float = 0.3
@export_range(0.0, 2.0, 0.01) var fade_out_seconds: float = 0.55

@export_group("Water Vignette")
## Màu viền khi Foxy đứng trong nước và không bị thấp máu.
@export var water_edge_color: Color = Color(0.04, 0.42, 0.7, 1.0)
## Độ đậm viền xanh khi đứng trong nước.
@export_range(0.0, 1.0, 0.01) var water_strength: float = 0.3

var _overlay: ColorRect
var _material: ShaderMaterial
var _transition: Tween
var _visibility: float = 0.0
var _breath_time: float = 0.0
var _active: bool = false
var _water_active: bool = false
var _alive: bool = true
var _visible_requested: bool = false


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
	var in_water := is_instance_valid(player) and player.environment_is_water and _alive
	if in_water != _water_active:
		_water_active = in_water
		_update_display()
	if not _overlay.visible:
		return
	_breath_time += delta
	var phase := _breath_time * FULL_CYCLE_RADIANS / breath_cycle_seconds
	var strength := (
		base_strength + pulse_strength * 0.5 * (1.0 - cos(phase))
		if _active else water_strength
	)
	_material.set_shader_parameter("strength", clampf(strength * _visibility, 0.0, 1.0))


func _on_hp_changed(current_hp: float, max_hp: float) -> void:
	_alive = max_hp > 0.0 and current_hp > 0.0
	_active = _alive and current_hp / max_hp <= health_threshold
	_water_active = is_instance_valid(player) and player.environment_is_water and _alive
	_update_display()


func _update_display() -> void:
	var should_show := _active or _water_active
	if should_show:
		_material.set_shader_parameter("edge_color", edge_color if _active else water_edge_color)
	if should_show == _visible_requested:
		return
	_visible_requested = should_show
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
	if not _visible_requested:
		_overlay.hide()
