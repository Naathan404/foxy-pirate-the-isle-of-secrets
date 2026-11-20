class_name BlubberbeardSkydiveController
extends Node3D
## Điều khiển cú nhảy parabol hạng nặng đến thẳng vị trí Player.

const PROPS_SHEET := preload("res://assets/sprites/bosses/blubberbeard/anchor_whirlwind_props.png")
const SKYDIVE_RETICLE_FRAME := 7
const HIGH_AIR_THRESHOLD_METERS := 2.2

var target_position: Vector3 = Vector3.ZERO
var is_high_airborne: bool = false

var _boss: BossBase
var _visual: BlubberbeardVisual
var _reticle: Sprite3D
var _shadow: MeshInstance3D
var _ground_y: float = 0.0
var _leap_elapsed: float = 0.0
var _leap_duration: float = 0.82
var _peak_height: float = 5.4
var _start_pos: Vector3 = Vector3.ZERO


func setup(owner_boss: BossBase, boss_visual: BlubberbeardVisual) -> void:
	_boss = owner_boss
	_visual = boss_visual
	_build_markers()
	hide_all()


func begin_windup(ground_y: float) -> void:
	_ground_y = ground_y
	_leap_elapsed = 0.0
	is_high_airborne = false
	_visual.airborne_height = 0.0
	_shadow.visible = true
	_reticle.visible = false
	update_shadow(0.0)


func begin_leap(
	target_node: Node3D,
	max_range: float,
	peak_height: float,
	leap_duration: float,
	impact_radius: float,
	body_scale: float = 1.0
) -> Vector3:
	_peak_height = maxf(1.5, peak_height)
	_leap_duration = maxf(0.25, leap_duration)
	_leap_elapsed = 0.0
	_start_pos = _boss.global_position
	_start_pos.y = _ground_y
	var dest := (
		target_node.global_position if is_instance_valid(target_node) else _boss.global_position
	)
	var delta_xz := dest - _boss.global_position
	delta_xz.y = 0.0
	if delta_xz.length() > max_range:
		delta_xz = delta_xz.normalized() * max_range
	target_position = Vector3(
		_boss.global_position.x + delta_xz.x, _ground_y, _boss.global_position.z + delta_xz.z
	)
	_reticle.global_position = target_position + Vector3.UP * 0.05
	_reticle.pixel_size = (impact_radius * 2.05) / 360.0
	_reticle.visible = true
	if is_instance_valid(_shadow):
		var cyl := _shadow.mesh as CylinderMesh
		if cyl != null:
			cyl.top_radius = 1.45 * body_scale
			cyl.bottom_radius = 1.45 * body_scale
	_shadow.visible = true
	return target_position


func tick_leap(delta: float) -> bool:
	var prev_t := _leap_elapsed / _leap_duration
	_leap_elapsed = minf(_leap_elapsed + maxf(0.0, delta), _leap_duration)
	var t := _leap_elapsed / _leap_duration
	_visual.airborne_height = 4.0 * _peak_height * t * (1.0 - t)
	is_high_airborne = _visual.airborne_height > HIGH_AIR_THRESHOLD_METERS
	_update_parabolic_pose(t)
	var step_xz := (target_position - _start_pos) * (t - prev_t)
	step_xz.y = 0.0
	var collision := _boss.move_and_collide(step_xz)
	if collision != null:
		var remain := collision.get_remainder()
		remain.y = 0.0
		_boss.move_and_collide(remain.slide(collision.get_normal()))
	update_shadow(_visual.airborne_height)
	if is_instance_valid(_reticle):
		_reticle.rotate_y(delta * 1.8)
	if t >= 1.0:
		target_position = Vector3(_boss.global_position.x, _ground_y, _boss.global_position.z)
		_visual.airborne_height = 0.0
		hide_all()
		return true
	return false


func hide_all() -> void:
	is_high_airborne = false
	if is_instance_valid(_reticle):
		_reticle.visible = false
	if is_instance_valid(_shadow):
		_shadow.visible = false


func update_shadow(height: float) -> void:
	if not is_instance_valid(_shadow) or not is_instance_valid(_boss):
		return
	_shadow.global_position = Vector3(
		_boss.global_position.x, _ground_y + 0.04, _boss.global_position.z
	)
	var s := clampf(1.25 - height * 0.08, 0.55, 1.35)
	_shadow.scale = Vector3(s, 1.0, s)


func _update_parabolic_pose(progress: float) -> void:
	if progress < 0.28:
		if _visual.clip != BlubberbeardVisual.Clip.SKYDIVE_LAUNCH:
			_visual.begin_windup(BlubberbeardSkillData.Kind.SKY_DIVE)
		_visual.windup_progress = 0.85
	elif progress < 0.55:
		if _visual.clip != BlubberbeardVisual.Clip.SKYDIVE_GLIDE:
			_visual.begin_skydive_glide()
	elif progress < 0.72:
		if _visual.clip != BlubberbeardVisual.Clip.SKYDIVE_LOCK:
			_visual.begin_skydive_lock()
	else:
		if _visual.clip != BlubberbeardVisual.Clip.SKYDIVE_DIVE:
			_visual.begin_skydive_dive()


func _build_markers() -> void:
	_shadow = MeshInstance3D.new()
	_shadow.name = "SkydiveGroundShadow"
	_shadow.top_level = true
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.45
	cyl.bottom_radius = 1.45
	cyl.height = 0.02
	_shadow.mesh = cyl
	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.albedo_color = Color(0.03, 0.04, 0.07, 0.56)
	_shadow.material_override = shadow_mat
	add_child(_shadow)

	_reticle = Sprite3D.new()
	_reticle.name = "SkydiveLockReticle"
	_reticle.top_level = true
	_reticle.texture = PROPS_SHEET
	_reticle.hframes = 4
	_reticle.vframes = 2
	_reticle.frame = SKYDIVE_RETICLE_FRAME
	_reticle.rotation.x = -PI * 0.5
	_reticle.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_reticle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_reticle)
