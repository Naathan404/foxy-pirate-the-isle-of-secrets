class_name VenomThornSegment
extends Node3D
## Một đốt rễ gai trồi từ mặt đất thuộc chiêu ThornTendril: cảnh báo -> trồi kích hitbox -> thu.

enum Stage {
	TELEGRAPH,
	ACTIVE,
	RETRACT,
}

const ELITE_ROOTS_SHEET := preload(
	"res://assets/sprites/enemies/venom_vine/venom_vine_elite_roots.png"
)
const VFX_SCRIPT := preload("res://gameplay/enemies/venom_vine/venom_vine_vfx.gd")

const GROUND_OFFSET_METERS := 0.035
const HITBOX_HEIGHT_METERS := 1.55
const CELL_HEIGHT_PX := 384.0
const SPRITE_BASE_OFFSET_Y := 152.0
const MOUND_DESIGN_SPAN_PX := 315.0
const FRAME_TELEGRAPH_MOUND := 4
const FRAME_EMERGE_TWINS := 5
const FRAME_PEAK_BRAMBLE := 6
const FRAME_RETRACT_DISSOLVE := 7

var _source: Node
var _source_team: int = CombatTeams.ENEMY
var _visual_radius_meters: float = 0.9
var _hitbox_radius_meters: float = 0.68
var _damage_hp: float = 1.0
var _knockback_multiplier: float = 0.75
var _telegraph_seconds: float = 0.44
var _active_seconds: float = 0.18
var _retract_seconds: float = 0.24
var _remaining_seconds: float = 0.44
var _stage: Stage = Stage.TELEGRAPH
var _clock_seconds: float = 0.0

var _thorn_sprite: Sprite3D
var _hitbox: HitBox


func setup(
	owner_node: Node,
	owner_team: int,
	world_pos: Vector3,
	visual_radius_meters: float,
	hitbox_radius_meters: float,
	damage_hp: float,
	knockback_multiplier: float = 0.75,
	telegraph_seconds: float = 0.44,
	active_seconds: float = 0.18,
	retract_seconds: float = 0.24
) -> void:
	_source = owner_node
	_source_team = owner_team
	position = world_pos
	_visual_radius_meters = maxf(0.35, visual_radius_meters)
	# Hitbox luôn nhỏ hơn vùng cảnh báo visual để người chơi né công bằng.
	_hitbox_radius_meters = clampf(hitbox_radius_meters, 0.2, _visual_radius_meters * 0.88)
	_damage_hp = maxf(0.0, damage_hp)
	_knockback_multiplier = maxf(0.0, knockback_multiplier)
	_telegraph_seconds = maxf(0.15, telegraph_seconds)
	_active_seconds = maxf(0.08, active_seconds)
	_retract_seconds = maxf(0.1, retract_seconds)
	_remaining_seconds = _telegraph_seconds


func _ready() -> void:
	_build_thorn_sprite()
	_build_hitbox()


func _physics_process(delta: float) -> void:
	var step := maxf(0.0, delta)
	_clock_seconds += step
	_remaining_seconds = maxf(0.0, _remaining_seconds - step)
	match _stage:
		Stage.TELEGRAPH:
			_update_telegraph()
			if _remaining_seconds <= 0.0:
				_begin_active()
		Stage.ACTIVE:
			_update_active()
			if _remaining_seconds <= 0.0:
				_begin_retract()
		Stage.RETRACT:
			_update_retract()
			if _remaining_seconds <= 0.0:
				queue_free()


func get_visual_radius() -> float:
	return _visual_radius_meters


func get_hitbox_radius() -> float:
	return _hitbox_radius_meters


func is_active_window() -> bool:
	return _stage == Stage.ACTIVE


func _begin_active() -> void:
	_stage = Stage.ACTIVE
	_remaining_seconds = _active_seconds
	if is_instance_valid(_thorn_sprite):
		_thorn_sprite.frame = FRAME_EMERGE_TWINS
		_thorn_sprite.position = Vector3(0.0, GROUND_OFFSET_METERS, 0.0)
		_thorn_sprite.scale = Vector3(1.12, 1.38, 1.12)
		_thorn_sprite.modulate = Color(1.12, 0.96, 1.24, 1.0)
	var parent := get_parent()
	if is_instance_valid(parent) and not parent.is_queued_for_deletion():
		(
			VFX_SCRIPT
			. spawn_one_shot_spray(
				parent,
				"ThornEruptSplash",
				global_position + Vector3.UP * 0.25,
				Vector3.UP,
				{
					"spread": 48.0,
					"vel_min": 2.6,
					"vel_max": 4.8,
					"gravity_y": -9.0,
					"count": 14,
					"lifetime": 0.42,
					"start_color": Color(0.95, 0.58, 1.0, 0.94),
					"end_color": Color(0.52, 0.16, 0.9, 0.0),
					"col": 2,
					"purple": true,
				}
			)
		)
		VFX_SCRIPT.spawn_dirt_dust_burst(
			parent, "ThornEruptDirt", global_position, Vector3.UP, 12, 0.48
		)
	if is_instance_valid(_hitbox) and _damage_hp > 0.0:
		var context := DamageContext.new()
		context.source = _source if is_instance_valid(_source) else self
		context.source_team = _source_team
		context.base_amount_hp = _damage_hp
		context.amount_hp = _damage_hp
		context.tag = &"elite_thorn_tendril"
		context.origin = global_position
		context.knockback_multiplier = _knockback_multiplier
		_hitbox.monitoring = true
		_hitbox.begin_attack_with_context(context, HitBox.RehitPolicy.ONCE_PER_ATTACK)
		_hitbox.sample_shape()


func _begin_retract() -> void:
	_stage = Stage.RETRACT
	_remaining_seconds = _retract_seconds
	if is_instance_valid(_thorn_sprite):
		_thorn_sprite.frame = FRAME_RETRACT_DISSOLVE
		_thorn_sprite.modulate = Color.WHITE
	var parent := get_parent()
	if is_instance_valid(parent) and not parent.is_queued_for_deletion():
		VFX_SCRIPT.spawn_dirt_dust_burst(
			parent, "ThornRetractDirt", global_position, Vector3.UP, 6, 0.34
		)
	if is_instance_valid(_hitbox):
		_hitbox.end_attack()
		_hitbox.monitoring = false


func _update_telegraph() -> void:
	var progress := clampf(1.0 - _remaining_seconds / _telegraph_seconds, 0.0, 1.0)
	if is_instance_valid(_thorn_sprite):
		var tremor := 0.032 * progress * sin(_clock_seconds * 44.0)
		var pulse := 0.5 + 0.5 * sin(_clock_seconds * 22.0)
		_thorn_sprite.position = Vector3(tremor, GROUND_OFFSET_METERS, 0.0)
		_thorn_sprite.scale = Vector3.ONE * lerpf(0.72, 1.14, progress)
		_thorn_sprite.modulate = Color(
			lerpf(0.95, 1.18, pulse * progress),
			lerpf(0.82, 0.92, pulse),
			lerpf(1.02, 1.32, pulse * progress),
			lerpf(0.68, 1.0, progress)
		)


func _update_active() -> void:
	if not is_instance_valid(_thorn_sprite):
		return
	var progress := clampf(1.0 - _remaining_seconds / _active_seconds, 0.0, 1.0)
	var sway := sin(_clock_seconds * 11.0) * 0.045
	if progress < 0.18:
		var spring := ease(progress / 0.18, 0.45)
		_thorn_sprite.frame = FRAME_EMERGE_TWINS
		_thorn_sprite.scale = Vector3(
			lerpf(1.18, 1.08, spring), lerpf(0.72, 1.34, spring), lerpf(1.18, 1.08, spring)
		)
	else:
		_thorn_sprite.frame = FRAME_PEAK_BRAMBLE
		var settle := clampf((progress - 0.18) / 0.16, 0.0, 1.0)
		var throb := 1.08 + 0.05 * sin(_clock_seconds * 9.0)
		_thorn_sprite.scale = Vector3(
			lerpf(1.08, 1.04, settle), lerpf(1.34, throb, settle), lerpf(1.08, 1.04, settle)
		)
		_thorn_sprite.modulate = Color(1.06, 0.94, 1.18, 1.0)
	_thorn_sprite.position = Vector3(sway, GROUND_OFFSET_METERS, 0.0)


func _update_retract() -> void:
	if not is_instance_valid(_thorn_sprite):
		return
	var ratio := clampf(_remaining_seconds / _retract_seconds, 0.0, 1.0)
	_thorn_sprite.position = Vector3(0.0, GROUND_OFFSET_METERS - (1.0 - ratio) * 0.18, 0.0)
	_thorn_sprite.scale = Vector3(lerpf(0.75, 1.04, ratio), maxf(0.28, ratio * 1.05), 1.0)
	_thorn_sprite.modulate.a = ratio


func _build_thorn_sprite() -> void:
	_thorn_sprite = Sprite3D.new()
	_thorn_sprite.name = "ThornEruptSprite"
	_thorn_sprite.texture = ELITE_ROOTS_SHEET
	_thorn_sprite.hframes = 4
	_thorn_sprite.vframes = 2
	_thorn_sprite.frame = FRAME_TELEGRAPH_MOUND
	_thorn_sprite.offset = Vector2(0.0, SPRITE_BASE_OFFSET_Y)
	_thorn_sprite.pixel_size = (_visual_radius_meters * 2.0) / MOUND_DESIGN_SPAN_PX
	_thorn_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_thorn_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_thorn_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_thorn_sprite.position = Vector3(0.0, GROUND_OFFSET_METERS, 0.0)
	if randf() < 0.5:
		_thorn_sprite.flip_h = true
	add_child(_thorn_sprite)


func _build_hitbox() -> void:
	_hitbox = HitBox.new()
	_hitbox.name = "ThornHitBox"
	_hitbox.actor = _source if is_instance_valid(_source) else self
	_hitbox.team = _source_team
	_hitbox.collision_layer = CombatLayers.ENEMY_ATTACK
	_hitbox.collision_mask = CombatLayers.PLAYER_HURTBOX
	_hitbox.monitoring = false
	_hitbox.monitorable = false

	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = _hitbox_radius_meters
	shape.height = HITBOX_HEIGHT_METERS
	col.shape = shape
	col.position = Vector3(0.0, HITBOX_HEIGHT_METERS * 0.5, 0.0)
	_hitbox.add_child(col)
	add_child(_hitbox)
