class_name HudPortrait
extends TextureRect
## react cuar Foxy theo HP; timer hình ảnh độc lập với state Hit của Player

const LOW_HP_ANIMATION: StringName = &"low_hp"

@export_range(0.0, 1.0) var low_health_ratio: float = 0.3
@export_range(0.05, 2.0) var hit_duration: float = 0.25
@export var healthy_texture: Texture2D
@export var low_health_texture: Texture2D
@export var hit_texture: Texture2D
@export var dead_texture: Texture2D

var _health_ratio: float = 1.0
var _dead: bool = false
var _hit_remaining: float = 0.0
var _rest_position: Vector2

@onready var _animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer")


func _ready() -> void:
	_rest_position = position
	if healthy_texture == null:
		healthy_texture = texture
	set_process(false)


func _process(delta: float) -> void:
	_hit_remaining = maxf(0.0, _hit_remaining - delta)
	var shake := 2.0 if int(_hit_remaining * 40.0) % 2 == 0 else -2.0
	position = _rest_position + Vector2(shake, 0.0)
	if _hit_remaining == 0.0:
		position = _rest_position
		_update_portrait()
		set_process(false)


func set_health(current: int, maximum: int) -> void:
	_health_ratio = clampf(float(current) / maxf(maximum, 1.0), 0.0, 1.0)
	_dead = maximum > 0 and current <= 0
	if _dead:
		_hit_remaining = 0.0
		position = _rest_position
		set_process(false)
	_update_portrait()


func play_hit_feedback(_amount: int) -> void:
	if _dead:
		return
	_hit_remaining = hit_duration
	set_process(true)
	_update_portrait()


func show_death() -> void:
	_dead = true
	_hit_remaining = 0.0
	position = _rest_position
	set_process(false)
	_update_portrait()


func _update_portrait() -> void:
	# Ưu tiên: chết -> đang trúng đòn -> máu thấp -> khỏe.
	texture = healthy_texture
	modulate = Color.WHITE
	if _dead:
		texture = dead_texture if dead_texture != null else healthy_texture
		modulate = Color(0.45, 0.45, 0.45)
	elif _hit_remaining > 0.0:
		texture = hit_texture if hit_texture != null else healthy_texture
		modulate = Color(1.0, 0.35, 0.35)
	elif _health_ratio <= low_health_ratio:
		texture = low_health_texture if low_health_texture != null else healthy_texture
	_update_low_health_animation()


func _update_low_health_animation() -> void:
	if (
		not is_instance_valid(_animation_player)
		or not _animation_player.has_animation(LOW_HP_ANIMATION)
	):
		return
	if _dead or _health_ratio > low_health_ratio:
		_animation_player.stop()
	elif _hit_remaining > 0.0:
		_animation_player.pause()
	elif not _animation_player.is_playing():
		_animation_player.play(LOW_HP_ANIMATION)
		modulate = Color(1.0, 0.35, 0.35)
		_animation_player.advance(0.0)
