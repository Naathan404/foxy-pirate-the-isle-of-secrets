extends TextureProgressBar


var _mask_texture: Texture2D
var _alpha_mask: BitMap
var _stat_text: String = ""


func _has_point(point: Vector2) -> bool:
	if texture_progress == null or radial_fill_degrees <= 0.0 or ratio <= 0.0:
		return false
	if _mask_texture != texture_progress:
		_mask_texture = texture_progress
		var image := texture_progress.get_image()
		if image == null or image.is_empty():
			_alpha_mask = null
			return false
		if image.is_compressed():
			image.decompress()
		_alpha_mask = BitMap.new()
		_alpha_mask.create_from_image_alpha(image, 0.1)
	if _alpha_mask == null:
		return false

	# TextureProgressBar chỉ kéo ảnh theo size khi bật Nine Patch Stretch.
	# Point đã ở tọa độ local nên vẫn đúng khi HUD hoặc bar được scale.
	var texture_size = texture_progress.get_size()
	var drawn_size = size if nine_patch_stretch else texture_size
	var local_point = point - texture_progress_offset
	if not Rect2(Vector2.ZERO, drawn_size).has_point(local_point):
		return false
	var uv = local_point / drawn_size
	var pixel := Vector2i((uv * Vector2(_alpha_mask.get_size())).floor())
	if not _alpha_mask.get_bitv(pixel):
		return false

	var center := (Vector2(0.5, 0.5) + radial_center_offset / texture_size).clamp(
		Vector2.ZERO, Vector2.ONE
	)
	var direction = uv - center
	var angle = fposmod(rad_to_deg(direction.angle()) + 90.0, 360.0)
	var sweep = radial_fill_degrees * ratio
	if fill_mode == FILL_COUNTER_CLOCKWISE:
		return fposmod(radial_initial_angle - angle, 360.0) <= sweep
	if fill_mode == FILL_CLOCKWISE_AND_COUNTER_CLOCKWISE:
		return absf(wrapf(angle - radial_initial_angle, -180.0, 180.0)) <= sweep * 0.5
	return fposmod(angle - radial_initial_angle, 360.0) <= sweep


func set_stat_tooltip(text: String) -> void:
	_stat_text = text


func get_stat_tooltip() -> String:
	return _stat_text
