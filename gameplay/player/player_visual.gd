class_name PlayerVisual
extends Node3D

signal animation_finished(animation_name: StringName)

@export var sprite: Sprite3D
@export var animation_player: AnimationPlayer
## Optional sprites for actions that use another sheet/layout, keyed by animation prefix.
@export var action_sprite_paths: Dictionary[StringName, NodePath] = {}

var _action: StringName = &""
var _facing: Vector3 = Vector3.BACK
var _camera: Camera3D
# Lưu tốc độ ban đầu để trả lại sau khi đánh
var _base_animation_speed: float = 1.0
# Bằng 0 thì animation chạy với tốc độ bình thường
var _fitted_duration: float = 0.0
var _held_progress: float = -1.0
var _active_sprite: Sprite3D
var _action_sprites: Dictionary[StringName, Sprite3D] = {}


func _ready() -> void:
	_active_sprite = sprite
	for prefix: StringName in action_sprite_paths:
		var action_sprite := get_node_or_null(action_sprite_paths[prefix]) as Sprite3D
		if action_sprite == null:
			push_error("PlayerVisual: missing sprite for action " + String(prefix))
			continue
		action_sprite.visible = false
		_action_sprites[prefix] = action_sprite
	if is_instance_valid(animation_player):
		_base_animation_speed = animation_player.speed_scale
		animation_player.animation_finished.connect(_on_animation_finished)


func _process(_delta: float) -> void:
	if get_node("/root/HitstopController").is_frozen(get_parent()):
		return
	# Camera đổi góc thì sprite cũng đổi hướng theo
	if not _action.is_empty():
		_update_directional_animation()


# Mỗi hành động cần đủ 3 animation: down, up và side
func has_directional_animation(action: StringName) -> bool:
	if not is_instance_valid(animation_player):
		return false
	for suffix in ["down", "up", "side"]:
		if not animation_player.has_animation(String(action) + "_" + suffix):
			return false
	return true


func has_attack_animation(action: StringName) -> bool:
	if not has_directional_animation(action) or animation_player.speed_scale <= 0.0:
		return false
	for suffix in ["down", "up", "side"]:
		var animation := animation_player.get_animation(String(action) + "_" + suffix)
		# Đòn đánh phải có nội dung và không được lặp
		if animation.loop_mode != Animation.LOOP_NONE:
			return false
		if animation.length <= 0.0:
			return false
		if animation.get_track_count() == 0:
			return false
	return true


func play_animation(animation_name: StringName, restart: bool = false) -> bool:
	# Phát theo tên cụ thể thì không tự đổi hướng nữa
	_action = &""
	return _play(animation_name, restart)


func play_directional(
	action: StringName, facing: Vector3, camera: Camera3D = null, restart: bool = false
) -> bool:
	_action = action
	# Đứng yên thì giữ hướng nhìn cũ
	if not facing.is_zero_approx():
		_facing = facing
	_camera = camera
	return _update_directional_animation(restart)


# Cho animation chạy vừa thời gian đòn đánh sau khi tính tốc độ vũ khí
func fit_animation_duration(duration: float) -> bool:
	if not is_instance_valid(animation_player):
		return false
	if not is_finite(duration) or duration <= 0.0:
		return false
	var animation_name := animation_player.assigned_animation
	if not animation_player.has_animation(animation_name):
		return false
	var animation := animation_player.get_animation(animation_name)
	if animation.length <= 0.0:
		return false
	_fitted_duration = duration
	_update_animation_speed()
	return true


## Hold a drawn pose while gameplay owns the charge timer; safe across direction changes.
func hold_animation_pose(progress: float) -> void:
	_held_progress = clampf(progress, 0.0, 1.0)
	var animation := animation_player.get_animation(animation_player.assigned_animation)
	animation_player.seek(animation.length * _held_progress, true)
	animation_player.pause()


## Play just the release/recovery portion without changing shared animation resources.
func play_animation_from(progress: float, remaining_seconds: float) -> bool:
	_held_progress = -1.0
	var start := clampf(progress, 0.0, 0.99)
	if not fit_animation_duration(remaining_seconds / (1.0 - start)):
		return false
	var animation := animation_player.get_animation(animation_player.assigned_animation)
	animation_player.seek(animation.length * start, true)
	return true


# Trả tốc độ cũ để idle, run không bị ảnh hưởng bởi tốc độ đánh
func reset_animation_speed() -> void:
	_fitted_duration = 0.0
	_held_progress = -1.0
	if is_instance_valid(animation_player):
		animation_player.speed_scale = _base_animation_speed


## Full duration at the current playback speed; zero when no clip is assigned.
func get_current_animation_duration() -> float:
	if not is_instance_valid(animation_player):
		return 0.0
	var animation_name := animation_player.assigned_animation
	if not animation_player.has_animation(animation_name):
		return 0.0
	var animation := animation_player.get_animation(animation_name)
	return animation.length / maxf(absf(animation_player.speed_scale), 0.01)


func _update_directional_animation(restart: bool = false) -> bool:
	var screen_direction := _get_screen_direction()
	var suffix := "down"
	if absf(screen_direction.x) > absf(screen_direction.z):
		suffix = "side"
	elif screen_direction.z < 0.0:
		suffix = "up"

	var animation_name := String(_action) + "_" + suffix
	if not _play(animation_name, restart):
		return false

	# Sprite side vẽ sang phải, muốn nhìn trái thì lật ảnh
	if is_instance_valid(_active_sprite):
		_active_sprite.flip_h = false
		if suffix == "side" and screen_direction.x < 0.0:
			_active_sprite.flip_h = true
	return true


# Đổi hướng thế giới sang hướng nhìn trên màn hình
func _get_screen_direction() -> Vector3:
	var active_camera := _camera
	if not is_instance_valid(active_camera):
		active_camera = get_viewport().get_camera_3d()
	if not is_instance_valid(active_camera):
		return _facing

	var camera_right := active_camera.global_basis.x
	var camera_back := active_camera.global_basis.z
	camera_right.y = 0.0
	camera_back.y = 0.0

	var screen_direction := Vector3.ZERO
	screen_direction.x = _facing.dot(camera_right.normalized())
	screen_direction.z = _facing.dot(camera_back.normalized())
	return screen_direction


func _play(animation_name: StringName, restart: bool) -> bool:
	if not is_instance_valid(animation_player):
		return false
	if not animation_player.has_animation(animation_name):
		return false
	_select_action_sprite(animation_name)

	# Không phát lại cùng animation mỗi frame, kể cả khi nó đã chạy xong
	if animation_player.assigned_animation == animation_name and not restart:
		return true

	var was_playing := animation_player.is_playing()
	var progress: float = -1.0
	if not restart and _fitted_duration > 0.0:
		progress = _get_animation_progress()

	if restart:
		animation_player.stop()
	animation_player.play(animation_name)
	_update_animation_speed()
	if _held_progress >= 0.0:
		var held_animation := animation_player.get_animation(animation_name)
		animation_player.seek(held_animation.length * _held_progress, true)
		animation_player.pause()
		return true

	# Đổi hướng giữa đòn thì tiếp tục ở cùng phần trăm thời gian
	if progress >= 0.0:
		var animation := animation_player.get_animation(animation_name)
		animation_player.seek(animation.length * progress, true)
		if not was_playing:
			animation_player.pause()
	return true


func _select_action_sprite(animation_name: StringName) -> void:
	var selected := sprite
	for prefix: StringName in _action_sprites:
		if String(animation_name).begins_with(String(prefix) + "_"):
			if is_instance_valid(_action_sprites[prefix]):
				selected = _action_sprites[prefix]
			break
	if _active_sprite == selected:
		return
	if is_instance_valid(sprite):
		sprite.visible = sprite == selected
	for candidate: Sprite3D in _action_sprites.values():
		if is_instance_valid(candidate):
			candidate.visible = candidate == selected
	_active_sprite = selected


# Trả tiến độ từ 0 đến 1, hoặc -1 nếu chưa có animation hợp lệ
func _get_animation_progress() -> float:
	var animation_name := animation_player.assigned_animation
	if not animation_player.has_animation(animation_name):
		return -1.0
	var animation := animation_player.get_animation(animation_name)
	if animation.length <= 0.0:
		return -1.0

	var elapsed := animation_player.current_animation_position
	return clampf(elapsed / animation.length, 0.0, 1.0)


func _update_animation_speed() -> void:
	if _fitted_duration <= 0.0:
		return
	var animation := animation_player.get_animation(animation_player.assigned_animation)
	animation_player.speed_scale = animation.length / _fitted_duration


func _on_animation_finished(animation_name: StringName) -> void:
	animation_finished.emit(animation_name)
