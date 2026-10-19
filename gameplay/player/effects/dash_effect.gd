extends Node3D

@export var player: Player
@export var sprite: Sprite3D

# Ghost effect
@export var ghost_interval: float = 0.04
@export var ghost_lifetime: float = 0.16
@export var ghosts: Array[Sprite3D] = []

@export var ghost_color: Color = Color(0.6, 0.85, 1.0, 0.4)

var _dashing: bool = false
var _ghost_timer: float = 0.0
var _next_ghost: int = 0
var _ghost_tweens: Array[Tween] = []

@onready var dash_particle: GPUParticles3D = $DashParticle


func _ready() -> void:
	_ghost_tweens.resize(ghosts.size())

	for g in ghosts:
		if not is_instance_valid(g):
			continue

		g.top_level = true
		g.hide()
		g.shaded = false
		g.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(delta: float) -> void:
	if not _dashing:
		return
	_ghost_timer -= delta
	if _ghost_timer <= 0.0:
		_show_next_ghost()
		_ghost_timer = ghost_interval



func _show_next_ghost() -> void:
	if ghosts.is_empty() or not is_instance_valid(sprite):
		return

	var index = _next_ghost
	_next_ghost += 1
	if _next_ghost >= ghosts.size():
		_next_ghost = 0

	var g = ghosts[index]
	if not is_instance_valid(g):
		return
	
	var old_tween = _ghost_tweens[index]
	if old_tween != null:
		old_tween.kill()

	g.texture = sprite.texture
	g.hframes = sprite.hframes
	g.vframes = sprite.vframes
	g.frame = sprite.frame
	g.pixel_size = sprite.pixel_size
	g.offset = sprite.offset
	g.centered = sprite.centered
	g.flip_h = sprite.flip_h
	g.global_transform = sprite.global_transform

	g.modulate = ghost_color
	g.show()

	var tween = g.create_tween()
	_ghost_tweens[index] = tween
	tween.tween_property(g, "modulate:a", 0.25, ghost_lifetime)
	tween.tween_callback(g.hide)


### Signal dash started and finished
func _on_foxy_dash_started() -> void:
	if not is_instance_valid(player):
		return

	# Bụi bay ngược hướng dash và hơi nhấc lên khỏi mặt đất
	var direction := -player.last_facing_direction
	direction.y = 0.15
	direction = direction.normalized()
	var material := dash_particle.process_material as ParticleProcessMaterial
	if material != null:
		material.direction = dash_particle.global_basis.inverse() * direction
	dash_particle.emitting = true

	_dashing = true
	_ghost_timer = 0.0


func _on_foxy_dash_finished(_interrupted: bool) -> void:
	# Ngừng tạo bụi mới, bụi cũ vẫn tự mờ hết
	dash_particle.emitting = false
	_dashing = false
