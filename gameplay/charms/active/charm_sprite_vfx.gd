class_name CharmSpriteVfx
extends Sprite3D
## Animated world-space atlas sprite; execution owns travel and hit timing.

const SHEET_SHADER: Shader = preload("res://gameplay/charms/active/charm_sprite_vfx.gdshader")
const COLUMNS: int = 4
const ROWS: int = 3

var externally_driven: bool = false
var _row: int = 0
var _seconds: float = 0.2
var _elapsed: float = 0.0
var _loop: bool = false
var _direction: Vector3 = Vector3.ZERO


static func spawn(
	parent: Node3D,
	at: Vector3,
	sheet: Texture2D,
	row: int,
	width: float,
	seconds: float,
	direction: Vector3 = Vector3.ZERO,
	loop: bool = false,
	pivot: Vector2 = Vector2(0.5, 0.5)
) -> CharmSpriteVfx:
	var effect := CharmSpriteVfx.new()
	effect.texture = sheet
	effect.hframes = COLUMNS
	effect.vframes = ROWS
	effect.pixel_size = width / (float(sheet.get_width()) / COLUMNS)
	effect.offset = (
		Vector2(0.5 - pivot.x, pivot.y - 0.5)
		* Vector2(float(sheet.get_width()) / COLUMNS, float(sheet.get_height()) / ROWS)
	)
	effect._seconds = maxf(0.01, seconds)
	effect._direction = direction
	effect._loop = loop
	effect._row = row
	effect.shaded = false
	effect.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = SHEET_SHADER
	material.set_shader_parameter("atlas_texture", sheet)
	effect.material_override = material
	parent.add_child(effect)
	effect.global_position = at
	effect.sample(row, 0.0)
	return effect


func _process(delta: float) -> void:
	_face_direction()
	if externally_driven:
		return
	_elapsed += maxf(0.0, delta)
	var progress := _elapsed / _seconds
	if _loop:
		progress = fposmod(progress, 1.0)
	sample(_row, progress)
	if not _loop and progress >= 1.0:
		queue_free()


func sample(row: int, progress: float, direction: Vector3 = Vector3.ZERO) -> void:
	_row = clampi(row, 0, ROWS - 1)
	frame = _row * COLUMNS + mini(COLUMNS - 1, int(clampf(progress, 0.0, 1.0) * COLUMNS))
	if not direction.is_zero_approx():
		_direction = direction
	_face_direction()


func _face_direction() -> void:
	var camera := get_viewport().get_camera_3d()
	if not is_instance_valid(camera):
		return
	var angle := 0.0
	if not _direction.is_zero_approx():
		angle = atan2(_direction.dot(camera.global_basis.y), _direction.dot(camera.global_basis.x))
	global_basis = camera.global_basis.orthonormalized() * Basis(Vector3.BACK, angle)
