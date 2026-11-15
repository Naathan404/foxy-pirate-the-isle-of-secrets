extends Node
## Player-owned overlay outlives the octopus and merges consecutive splashes.

const INK_SHADER: Shader = preload("res://gameplay/player/effects/ink_overlay.gdshader")
const OVERLAY_LAYER := 2
const HIT_COVERAGE := 0.125
const FULL_COVERAGE := 1.0

var _overlay: ColorRect
var _material: ShaderMaterial
var _tween: Tween
var _fatal_active := false
var _random := RandomNumberGenerator.new()
var coverage := 0.0:
	set(value):
		coverage = value
		if _material != null:
			_material.set_shader_parameter("coverage", value)
var opacity := 0.0:
	set(value):
		opacity = value
		if _material != null:
			_material.set_shader_parameter("opacity", value)


func _ready() -> void:
	_random.randomize()
	var layer := CanvasLayer.new()
	layer.layer = OVERLAY_LAYER
	add_child(layer)
	_overlay = ColorRect.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = INK_SHADER
	_overlay.material = _material
	layer.add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.hide()


func splash(fatal: bool, ink_color: Color, spread_time: float, hold_time: float, fade_time: float, strength: float) -> void:
	if _fatal_active and not fatal:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_fatal_active = fatal
	_material.set_shader_parameter("ink_color", ink_color)
	_material.set_shader_parameter("splash_seed", _random.randf_range(0.0, 1000.0))
	var viewport_size := get_viewport().get_visible_rect().size
	_material.set_shader_parameter("screen_aspect", viewport_size.x / maxf(viewport_size.y, 1.0))
	_overlay.show()
	_tween = create_tween().set_ignore_time_scale(true)
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "coverage", FULL_COVERAGE if fatal else HIT_COVERAGE, spread_time)
	_tween.parallel().tween_property(self, "opacity", strength, spread_time)
	_tween.tween_interval(hold_time)
	_tween.tween_property(self, "opacity", 0.0, fade_time).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(_clear)


func _clear() -> void:
	_overlay.hide()
	coverage = 0.0
	_fatal_active = false
