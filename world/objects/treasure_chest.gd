class_name TreasureChest
extends DestructibleProp
## Rương giữ nguyên sau khi mở; dùng chung máu, hurtbox và flash với vật thể phá được.

const CAMERA_ZOOM_TWEEN_META := &"treasure_chest_zoom_tween"
const CAMERA_ZOOM_BASE_META := &"treasure_chest_zoom_base"

@export_group("Chest State")
## Ảnh hiển thị sau khi rương hết máu.
@export var depleted_texture: Texture2D = preload("res://assets/sprites/objects/chest_opened.png")

@export_group("Chest Hit Feedback")
## Hitstop khi trúng đòn và khi mở rương, tính bằng giây.
@export_range(0.0, 0.3, 0.005, "suffix:s") var chest_hitstop: float = 0.045
@export_range(0.0, 0.3, 0.005, "suffix:s") var open_hitstop: float = 0.1
## Cường độ rung camera theo pixel và thời gian rung.
@export_range(0.0, 20.0, 0.1) var chest_shake: float = 2.0
@export_range(0.0, 20.0, 0.1) var open_shake: float = 6.0
@export_range(0.0, 1.0, 0.01, "suffix:s") var chest_shake_duration: float = 0.14
@export_range(0.0, 1.0, 0.01, "suffix:s") var open_shake_duration: float = 0.22
## Góc lắc của sprite sau đòn thường và đòn mở rương.
@export_range(0.0, 45.0, 0.5, "degrees") var wobble_degrees: float = 9.0
@export_range(0.0, 60.0, 0.5, "degrees") var open_wobble_degrees: float = 18.0
@export_range(0.01, 1.0, 0.01, "suffix:s") var wobble_step_seconds: float = 0.07
## Tỉ lệ góc khi lắc ngược lại trước khi về vị trí ban đầu.
@export_range(0.0, 1.0, 0.05) var wobble_return_ratio: float = 0.6
## Hệ số scale khi mở rương; feedback đòn thường dùng Hit Scale.
@export_range(1.0, 2.0, 0.01) var open_scale: float = 1.3
## Hệ số thời gian flash khi mở rương.
@export_range(1.0, 4.0, 0.1) var open_flash_duration_multiplier: float = 1.5

@export_group("Camera Punch")
## Hệ số FOV hoặc kích thước camera khi zoom; nhỏ hơn 1 là zoom gần.
@export_range(0.5, 1.0, 0.01) var zoom_factor: float = 0.9
@export_range(0.0, 1.0, 0.01, "suffix:s") var zoom_in_seconds: float = 0.1
@export_range(0.0, 2.0, 0.01, "suffix:s") var zoom_out_seconds: float = 0.3

@export_group("Gold Burst")
## Số xu được chọn ngẫu nhiên trong khoảng này; mỗi xu có giá trị 1 vàng.
@export_range(0, 1000, 1) var gold_min: int = 10
@export_range(0, 1000, 1) var gold_max: int = 20
## Vị trí bắt đầu theo tọa độ cục bộ của rương.
@export var gold_origin_offset: Vector3 = Vector3.ZERO
## Chiều cao và thời gian bay của xu; trail và điểm rơi dùng hệ pickup hiện có.
@export_range(0.0, 10.0, 0.1, "suffix:m") var gold_flight_height: float = 2.0
@export_range(0.05, 3.0, 0.05, "suffix:s") var gold_flight_duration: float = 0.8

var _wobble: Tween
var _rest_rotation: Vector3
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	super()
	if is_instance_valid(visual_root):
		_rest_rotation = visual_root.rotation


func receive_damage(damage: DamageContext) -> float:
	if _destroyed or damage == null or damage.source_team != CombatTeams.PLAYER:
		return 0.0
	var applied := _health.take_damage(damage.amount_hp)
	if applied <= 0.0:
		return 0.0
	var opening := not _health.is_alive()
	if opening:
		_destroyed = true
		_hurtbox.enabled = false
		_hurtbox.set_deferred("monitorable", false)
		if visual_root is Sprite3D and depleted_texture != null:
			(visual_root as Sprite3D).texture = depleted_texture
	damaged.emit(applied)
	var flash_duration := hit_flash_duration
	if opening:
		hit_flash_duration *= open_flash_duration_multiplier
	_play_hit_feedback()
	hit_flash_duration = flash_duration
	if opening and is_instance_valid(visual_root):
		visual_root.scale = _visual_scale * open_scale
	_play_wobble(open_wobble_degrees if opening else wobble_degrees)
	get_node("/root/HitstopController").request(open_hitstop if opening else chest_hitstop)
	get_node("/root/ScreenShakeController").request(
		open_shake if opening else chest_shake,
		open_shake_duration if opening else chest_shake_duration
	)
	if opening:
		_punch_camera()
		_drop_gold()
		destroyed.emit()
	return applied


func _play_wobble(angle_degrees: float) -> void:
	if not is_instance_valid(visual_root):
		return
	if _wobble != null and _wobble.is_valid():
		_wobble.kill()
	var angle := deg_to_rad(angle_degrees)
	_wobble = create_tween().set_ignore_time_scale(true)
	_wobble.tween_property(visual_root, "rotation:z", _rest_rotation.z + angle, wobble_step_seconds)
	_wobble.tween_property(visual_root, "rotation:z", _rest_rotation.z - angle * wobble_return_ratio, wobble_step_seconds)
	_wobble.tween_property(visual_root, "rotation:z", _rest_rotation.z, wobble_step_seconds)


func _punch_camera() -> void:
	var camera := get_viewport().get_camera_3d()
	if not is_instance_valid(camera):
		return
	var property := "size" if camera.projection == Camera3D.PROJECTION_ORTHOGONAL else "fov"
	var original := float(camera.get(property))
	var previous := camera.get_meta(CAMERA_ZOOM_TWEEN_META, null) as Tween
	if previous != null and previous.is_valid():
		original = float(camera.get_meta(CAMERA_ZOOM_BASE_META, original))
		previous.kill()
	# Bind to the camera so the reset still completes if the chest leaves the tree.
	var tween := camera.create_tween().set_ignore_time_scale(true)
	camera.set_meta(CAMERA_ZOOM_TWEEN_META, tween)
	camera.set_meta(CAMERA_ZOOM_BASE_META, original)
	tween.tween_property(camera, property, original * zoom_factor, zoom_in_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(camera, property, original, zoom_out_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func():
		if is_instance_valid(camera) and camera.get_meta(CAMERA_ZOOM_TWEEN_META, null) == tween:
			camera.remove_meta(CAMERA_ZOOM_TWEEN_META)
			camera.remove_meta(CAMERA_ZOOM_BASE_META)
	)


func _drop_gold() -> void:
	var pool := GoldPickupPool.for_scene(self)
	if pool == null:
		return
	var count := _random.randi_range(mini(gold_min, gold_max), maxi(gold_min, gold_max))
	var angle := _random.randf_range(0.0, TAU)
	pool.spawn_gold(
		to_global(gold_origin_offset), count, Vector3(cos(angle), 0.0, sin(angle)),
		gold_flight_height, gold_flight_duration
	)
