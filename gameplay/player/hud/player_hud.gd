extends CanvasLayer


@export_group("Stat Components")
@export var health: HealthComponent
@export var stamina: StaminaComponent

@export_group("Arc Layout")
# Hướng bắt đầu của bar
@export_range(0.0, 360.0) var initial_angle: float = 200.0
# Độ dài lớn nhất của cung bar
@export_range(1.0, 360.0) var maximum_arc: float = 225.0
# thông số tối đa
@export_range(1.0, 1000.0) var health_at_full_arc: float = 20.0
@export_range(1.0, 10000.0) var stamina_at_full_arc: float = 1000.0

@export_group("Portrait Reaction")
# Phần trăm hp để chuyển reaction
@export_range(0.0, 1.0) var low_health_ratio: float = 0.3
## Thời gian reaction của ảnh HUD
@export_range(0.05, 2.0) var hit_duration: float = 0.25
# ảnh reaction, null khi chưa có
@export var healthy_texture: Texture2D
@export var low_health_texture: Texture2D
@export var hit_texture: Texture2D
@export var dead_texture: Texture2D

# Nền, fill, bóng
@onready var health_capacity: TextureProgressBar = $HealthCapacity
@onready var health_fill: TextureProgressBar = $HealthFill
@onready var health_shadow: TextureProgressBar = $HealthShadow
@onready var stamina_capacity: TextureProgressBar = $StaminaCapacity
@onready var stamina_fill: TextureProgressBar = $StaminaFill
@onready var stamina_shadow: TextureProgressBar = $StaminaShadow
@onready var portrait: TextureRect = $Portrait

var _health_ratio: float = 1.0
var _dead: bool = false
var _hit_remaining: float = 0.0
var _portrait_position: Vector2


func _ready() -> void:
	_portrait_position = portrait.position
	if healthy_texture == null:
		healthy_texture = portrait.texture
	if is_instance_valid(health):
		health.hp_changed.connect(_on_hp_changed)
		health.damaged.connect(_on_damaged)
		health.died.connect(_on_died)
	if is_instance_valid(stamina):
		stamina.stamina_changed.connect(_on_stamina_changed)

	_sync_stats.call_deferred()


# sync trạng thái
func _sync_stats() -> void:
	if is_instance_valid(health):
		_on_hp_changed(health.get_current_hp(), health.get_max_hp())
	if is_instance_valid(stamina):
		_on_stamina_changed(stamina.get_current_sp(), stamina.get_max_sp())


func _process(delta: float) -> void:
	if _hit_remaining <= 0.0:
		return
	_hit_remaining = maxf(0.0, _hit_remaining - delta)
	var shake = 2.0 if int(_hit_remaining * 40.0) % 2 == 0 else -2.0
	portrait.position = _portrait_position + Vector2(shake, 0.0)
	if _hit_remaining == 0.0:
		portrait.position = _portrait_position
		_update_portrait()


func _on_hp_changed(current: int, maximum: int) -> void:
	_update_arc(health_capacity, health_fill, health_shadow, current, maximum, health_at_full_arc)
	_health_ratio = clampf(float(current) / maxf(maximum, 1.0), 0.0, 1.0)
	_dead = maximum > 0 and current <= 0
	_update_portrait()


func _on_stamina_changed(current: float, maximum: float) -> void:
	_update_arc(stamina_capacity, stamina_fill, stamina_shadow, current, maximum, stamina_at_full_arc)


# Update visual cuar bar, dùng chung cho tất cả các bar hp và stamina
func _update_arc(
	capacity: TextureProgressBar, fill: TextureProgressBar, shadow: TextureProgressBar,
	current: float, maximum: float, points_at_full_arc: float
) -> void:

	var degrees = maximum_arc * clampf(maximum / maxf(points_at_full_arc, 1.0), 0.0, 1.0)

	# Đồng bộ góc và giá trị
	for bar: TextureProgressBar in [capacity, fill, shadow]:
		bar.radial_initial_angle = initial_angle
		bar.radial_fill_degrees = degrees
		bar.max_value = maxf(maximum, 1.0)

	# Nền và shadow luôn đầy, fill được fill theo giá trị value hiện tại
	capacity.value = maxf(maximum, 0.0)
	shadow.value = maxf(maximum, 0.0)
	fill.value = clampf(current, 0.0, maxf(maximum, 0.0))


func _on_damaged(_amount: int) -> void:
	if _dead:
		return
	_hit_remaining = hit_duration
	_update_portrait()


func _on_died() -> void:
	_dead = true
	_hit_remaining = 0.0
	portrait.position = _portrait_position
	_update_portrait()


func _update_portrait() -> void:
	# Ưu tiên: chết --> đang trúng đòn --> máu thấp --> khỏe.
	# đặt lại ảnh/màu trước khi update
	portrait.texture = healthy_texture
	portrait.modulate = Color.WHITE

	if _dead:
		portrait.texture = dead_texture if dead_texture != null else healthy_texture
		portrait.modulate = Color(0.45, 0.45, 0.45)
	elif _hit_remaining > 0.0:
		portrait.texture = hit_texture if hit_texture != null else healthy_texture
		portrait.modulate = Color(1.0, 0.35, 0.35)
	elif _health_ratio <= low_health_ratio:
		portrait.texture = low_health_texture if low_health_texture != null else healthy_texture
		portrait.modulate = Color(1.0, 0.65, 0.65)
