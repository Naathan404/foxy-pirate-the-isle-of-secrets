class_name SeaMood
extends Node
## Blends a room's lagoon, sky, sun and screen grade towards a SeaPalette over time.
## The room's materials are local to the scene, so other rooms keep their own colours.

## SeaPalette properties that are shader parameters of the same name.
const LAGOON_KEYS: Array[String] = [
	"deep_color",
	"lagoon_color",
	"shallow_color",
	"reef_color",
	"caustic_color",
	"foam_color",
	"caustic_strength",
]
const GRADE_KEYS: Array[String] = [
	"shadow_tint",
	"highlight_tint",
	"saturation",
	"vignette_color",
	"vignette_strength",
]

## The void quad whose QuadMesh carries the coral_lagoon material.
@export var lagoon: MeshInstance3D
@export var world_environment: WorldEnvironment
@export var sun: DirectionalLight3D
## The RoomAtmosphere grade (a CanvasItem with the coral_grade material).
@export var grade: CanvasItem
@export var start_palette: SeaPalette

var _palette: SeaPalette
var _tween: Tween


func _ready() -> void:
	if start_palette != null:
		_apply(_values(start_palette))
		_palette = start_palette


func get_palette() -> SeaPalette:
	return _palette


## Starts from whatever is on screen now, so a blend can be redirected halfway.
func blend_to(palette: SeaPalette, seconds: float) -> void:
	if palette == null or palette == _palette:
		return
	_palette = palette
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var from := _read()
	var to := _values(palette)
	if seconds <= 0.0:
		_apply(to)
		return
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(_apply_mix.bind(from, to), 0.0, 1.0, seconds)


func _apply_mix(weight: float, from: Dictionary, to: Dictionary) -> void:
	var mixed := {}
	for key: String in to:
		mixed[key] = lerp(from[key], to[key], weight)
	_apply(mixed)


func _values(palette: SeaPalette) -> Dictionary:
	var values := {}
	for key: String in LAGOON_KEYS:
		values["lagoon/" + key] = palette.get(key)
	for key: String in GRADE_KEYS:
		values["grade/" + key] = palette.get(key)
	values["sky/background_color"] = palette.background_color
	values["sky/ambient_color"] = palette.ambient_color
	values["sky/ambient_energy"] = palette.ambient_energy
	values["sky/glow_intensity"] = palette.glow_intensity
	values["sun/color"] = palette.sun_color
	values["sun/energy"] = palette.sun_energy
	return values


func _read() -> Dictionary:
	var values := {}
	var lagoon_material := _lagoon_material()
	for key: String in LAGOON_KEYS:
		values["lagoon/" + key] = (
			lagoon_material.get_shader_parameter(key) if lagoon_material else null
		)
	var grade_material := _grade_material()
	for key: String in GRADE_KEYS:
		values["grade/" + key] = (
			grade_material.get_shader_parameter(key) if grade_material else null
		)
	var environment := _environment()
	if environment != null:
		values["sky/background_color"] = environment.background_color
		values["sky/ambient_color"] = environment.ambient_light_color
		values["sky/ambient_energy"] = environment.ambient_light_energy
		values["sky/glow_intensity"] = environment.glow_intensity
	if sun != null:
		values["sun/color"] = sun.light_color
		values["sun/energy"] = sun.light_energy
	# Anything the room does not have yet starts at the target value.
	var target := _values(_palette)
	for key: String in target:
		if values.get(key) == null:
			values[key] = target[key]
	return values


func _apply(values: Dictionary) -> void:
	var lagoon_material := _lagoon_material()
	if lagoon_material != null:
		for key: String in LAGOON_KEYS:
			lagoon_material.set_shader_parameter(key, values["lagoon/" + key])
	var grade_material := _grade_material()
	if grade_material != null:
		for key: String in GRADE_KEYS:
			grade_material.set_shader_parameter(key, values["grade/" + key])
	var environment := _environment()
	if environment != null:
		environment.background_color = values["sky/background_color"]
		environment.ambient_light_color = values["sky/ambient_color"]
		environment.ambient_light_energy = values["sky/ambient_energy"]
		environment.glow_intensity = values["sky/glow_intensity"]
	if sun != null:
		sun.light_color = values["sun/color"]
		sun.light_energy = values["sun/energy"]


func _lagoon_material() -> ShaderMaterial:
	if lagoon == null:
		return null
	if lagoon.material_override is ShaderMaterial:
		return lagoon.material_override as ShaderMaterial
	var mesh := lagoon.mesh as PrimitiveMesh
	return mesh.material as ShaderMaterial if mesh != null else null


func _grade_material() -> ShaderMaterial:
	return grade.material as ShaderMaterial if grade != null else null


func _environment() -> Environment:
	return world_environment.environment if world_environment != null else null
