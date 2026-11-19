class_name BlubberbeardVisual
extends Sprite3D
## Điều khiển sprite 4 hướng và toàn bộ animation chiến đấu của Captain Blubberbeard.

enum Pose { IDLE, WINDUP, ACTIVE, STAGGERED, RECOVERY }
enum Clip {
	IDLE,
	MOVE,
	BARREL_THROW,
	INFLATE_WINDUP,
	INFLATE_BURST,
	ANCHOR_WINDUP,
	ANCHOR_SLAM,
	SKYDIVE_LAUNCH,
	SKYDIVE_GLIDE,
	SKYDIVE_LOCK,
	SKYDIVE_DIVE,
	SKYDIVE_IMPACT,
	WHIRLWIND_WINDUP,
	WHIRLWIND_SPIN,
	WHIRLWIND_BRAKE,
	VENOM_SPIT,
	COUNTER_SHOCK,
	STAGGERED,
	HIT,
	DEATH,
}
enum FacingDir { DOWN = 0, SIDE = 1, UP = 2 }

const IDLE_4DIR_SHEET := preload(
	"res://assets/sprites/bosses/blubberbeard/blubberbeard_idle_4dir.png"
)
const MOVE_4DIR_SHEET := preload(
	"res://assets/sprites/bosses/blubberbeard/blubberbeard_move_4dir.png"
)
const INFLATE_4DIR_SHEET := preload(
	"res://assets/sprites/bosses/blubberbeard/blubberbeard_inflate_4dir.png"
)
const CHARGE_PREP_4DIR_SHEET := preload(
	"res://assets/sprites/bosses/blubberbeard/blubberbeard_charge_prep_4dir.png"
)
const ATTACKS_SHEET := preload("res://assets/sprites/bosses/blubberbeard/blubberbeard_attacks.png")
const HIT_DEATH_SHEET := preload(
	"res://assets/sprites/bosses/blubberbeard/blubberbeard_hit_death.png"
)
const SKYDIVE_SHEET := preload("res://assets/sprites/bosses/blubberbeard/blubberbeard_skydive.png")
const WHIRLWIND_SHEET := preload(
	"res://assets/sprites/bosses/blubberbeard/blubberbeard_anchor_whirlwind.png"
)
const VENOM_SPIT_4DIR_SHEET := preload(
	"res://assets/sprites/bosses/blubberbeard/blubberbeard_venom_spit_4dir.png"
)

const CELL_SIZE := 400.0
# Offset in pixels from cell center to the hoisted barrel in attacks frame (1, 0).
const BARREL_HAND_OFFSET_PX := Vector2(106.5, 115.5)
const THROW_RELEASE_PROGRESS := 0.35
const RECOVERY_ANIMATION_TIME := 0.45
const HURT_DURATION := 0.65
const HURT_FLASH_DURATION := 0.22
const ENRAGED_SCALE := 1.1
const SPIKY_HOLD_SCALE := 1.32
const WHIRLWIND_SPIN_FRAMES := [1, 2, 3, 4, 5]
const BASE_SCENE_PIXEL_SIZE := 0.032

@export_range(1.0, 24.0, 0.5) var idle_fps: float = 5.0
@export_range(1.0, 24.0, 0.5) var move_fps: float = 7.5
@export_range(1.0, 30.0, 0.5) var whirlwind_fps: float = 15.0

var pose: Pose = Pose.IDLE
var clip: Clip = Clip.IDLE
var moving: bool = false:
	set(value):
		if moving == value:
			return
		moving = value
		if pose == Pose.IDLE and _burst_left <= 0.0 and not _dying:
			_set_clip(Clip.MOVE if moving else Clip.IDLE)
			_update_active_frame()
var windup_progress: float = 0.0:
	set(value):
		windup_progress = value
		if pose == Pose.WINDUP and not _dying:
			if _kind == BlubberbeardSkillData.Kind.POWDER_BARREL and windup_progress >= 0.96:
				if clip == Clip.BARREL_THROW:
					_set_clip(Clip.MOVE if moving else Clip.IDLE)
			_update_active_frame()
var airborne_height: float = 0.0
var enraged: bool = false

var _kind: int = 0
var _clock: float = 0.0
var _clip_time: float = 0.0
var _hit_flash: float = 0.0
var _hit_clip_left: float = 0.0
var _hit_clip_duration: float = HURT_DURATION
var _burst_left: float = 0.0
var _recovery_duration: float = RECOVERY_ANIMATION_TIME
var _stagger_duration: float = 1.25
var _spiky_hold_total: float = 1.25
var _facing: Vector3 = Vector3.BACK
var _lean: float = 1.0
var _rest_position: Vector3
var _rest_scale: Vector3
var _rest_pixel_size: float
var _base_position: Vector3
var _base_pixel_size: float
var _dying: bool = false
var _death_time: float = 0.0
var _impact_left: float = 0.0
var _impact_duration: float = 0.0
var _impact_power: float = 0.0


func _ready() -> void:
	_base_position = position
	_base_pixel_size = pixel_size
	_rest_position = position
	_rest_scale = scale
	_rest_pixel_size = pixel_size
	_apply_clip_frame(Clip.IDLE, 0.0)


func set_base_size_scale(size_scale: float) -> void:
	var clamped := clampf(size_scale, 0.4, 2.5)
	_rest_pixel_size = _base_pixel_size * clamped
	_rest_position = Vector3(_base_position.x, _base_position.y * clamped, _base_position.z)
	pixel_size = _rest_pixel_size


func get_active_size_multiplier() -> float:
	var mult := ENRAGED_SCALE if enraged else 1.0
	if pose == Pose.ACTIVE and clip == Clip.INFLATE_BURST:
		mult *= SPIKY_HOLD_SCALE
	return mult


func _process(delta: float) -> void:
	if _dying:
		_death_time += maxf(0.0, delta)
		_apply_clip_frame(Clip.DEATH, _death_time)
		return
	var owner_boss := get_parent() as BossBase
	var hitstop := get_node_or_null("/root/HitstopController")
	if hitstop != null and hitstop.is_frozen(owner_boss):
		return
	var step := maxf(0.0, delta)
	_clock += step
	_clip_time += step
	_hit_flash = maxf(0.0, _hit_flash - step)
	_hit_clip_left = maxf(0.0, _hit_clip_left - step)
	_impact_left = maxf(0.0, _impact_left - step)
	if pose == Pose.RECOVERY and _clip_time >= _recovery_duration:
		pose = Pose.IDLE
		_set_clip(Clip.MOVE if moving else Clip.IDLE)
	elif pose == Pose.STAGGERED and _clip_time >= _stagger_duration:
		pose = Pose.IDLE
		_set_clip(Clip.MOVE if moving else Clip.IDLE)
	if _burst_left > 0.0:
		_burst_left = maxf(0.0, _burst_left - step)
		if _burst_left <= 0.0 and (pose == Pose.IDLE or clip == Clip.INFLATE_BURST):
			pose = Pose.IDLE
			_set_clip(Clip.MOVE if moving else Clip.IDLE)
	if pose == Pose.IDLE and _burst_left <= 0.0:
		var wanted := Clip.MOVE if moving else Clip.IDLE
		if clip != wanted:
			_set_clip(wanted)
	elif pose == Pose.WINDUP and _kind == BlubberbeardSkillData.Kind.POWDER_BARREL:
		if windup_progress >= 0.96 and clip == Clip.BARREL_THROW:
			_set_clip(Clip.MOVE if moving else Clip.IDLE)

	var size := ENRAGED_SCALE if enraged else 1.0
	var breathing := sin(_clock * (5.0 if enraged else 3.0)) * 0.02
	var desired_scale := _rest_scale * size * Vector3(1.0 + breathing, 1.0 - breathing, 1.0)
	var desired_position := _rest_position
	desired_position.y += _rest_position.y * (size - 1.0) + airborne_height
	var desired_rotation := 0.0
	match pose:
		Pose.WINDUP:
			var anticipation := sin(windup_progress * PI * 0.5)
			desired_scale *= Vector3(1.0 + 0.08 * anticipation, 1.0 - 0.07 * anticipation, 1.0)
			desired_rotation = -0.06 * anticipation * _lean
			if (
				_kind != BlubberbeardSkillData.Kind.POWDER_BARREL
				or windup_progress < THROW_RELEASE_PROGRESS
			):
				desired_position.x += sin(_clock * 32.0) * 0.05 * anticipation
		Pose.ACTIVE:
			if clip == Clip.WHIRLWIND_SPIN:
				desired_scale *= Vector3(1.05, 0.96, 1.0)
				desired_rotation = sin(_clock * 28.0) * 0.08
			elif clip == Clip.SKYDIVE_DIVE:
				desired_scale *= Vector3(0.95, 1.08, 1.0)
				desired_rotation = 0.0
			elif clip == Clip.INFLATE_BURST:
				var pulse := 1.0 + sin(_clock * 14.0) * 0.03
				desired_scale *= SPIKY_HOLD_SCALE * pulse
				desired_position.y += _rest_position.y * (SPIKY_HOLD_SCALE - 1.0) * 0.72
			else:
				desired_scale *= Vector3(1.04, 0.96, 1.0)
				desired_position.y += sin(_clock * 8.0) * 0.14
		Pose.STAGGERED, Pose.RECOVERY:
			if pose == Pose.STAGGERED or clip == Clip.WHIRLWIND_BRAKE:
				var pant := sin(_clock * 9.0)
				desired_scale *= Vector3(1.06 + pant * 0.035, 0.92 - pant * 0.04, 1.0)
				desired_rotation = (-0.06 + pant * 0.04) * _lean
			else:
				desired_scale *= Vector3(1.05, 0.94, 1.0)
				desired_rotation = -0.05 * _lean
	if _impact_left > 0.0 and _impact_duration > 0.0:
		var weight := _impact_left / _impact_duration
		desired_scale *= Vector3(1.0 + _impact_power * weight, 1.0 - _impact_power * weight, 1.0)
		desired_rotation += sin(_clock * 40.0) * _impact_power * 0.7 * weight
	var blend := 1.0 - exp(-14.0 * step)
	scale = scale.lerp(desired_scale, blend)
	position = position.lerp(desired_position, blend)
	rotation.z = lerp_angle(rotation.z, desired_rotation, blend)
	var flash_weight := _hit_flash / HURT_FLASH_DURATION
	modulate = _phase_color().lerp(Color(2.0, 1.65, 1.55), flash_weight)
	_update_active_frame()


func begin_windup(kind: int) -> void:
	_kind = kind
	windup_progress = 0.0
	_burst_left = 0.0
	_hit_clip_left = 0.0
	pose = Pose.WINDUP
	match kind:
		BlubberbeardSkillData.Kind.POWDER_BARREL:
			_set_clip(Clip.BARREL_THROW)
		BlubberbeardSkillData.Kind.SKY_DIVE:
			_set_clip(Clip.SKYDIVE_LAUNCH)
		BlubberbeardSkillData.Kind.SPIKY_INFLATION:
			_set_clip(Clip.INFLATE_WINDUP)
		BlubberbeardSkillData.Kind.ANCHOR_SLAM:
			_set_clip(Clip.ANCHOR_WINDUP)
		BlubberbeardSkillData.Kind.ANCHOR_WHIRLWIND:
			_set_clip(Clip.WHIRLWIND_WINDUP)
		BlubberbeardSkillData.Kind.VENOM_SPIT:
			_set_clip(Clip.VENOM_SPIT)
		_:
			_set_clip(Clip.IDLE)
	_update_active_frame()


func begin_skydive_glide() -> void:
	pose = Pose.ACTIVE
	_burst_left = 0.0
	_set_clip(Clip.SKYDIVE_GLIDE)
	_update_active_frame()


func begin_skydive_lock() -> void:
	pose = Pose.WINDUP
	windup_progress = 0.0
	_burst_left = 0.0
	_set_clip(Clip.SKYDIVE_LOCK)
	_update_active_frame()


func begin_skydive_dive() -> void:
	pose = Pose.ACTIVE
	_burst_left = 0.0
	_set_clip(Clip.SKYDIVE_DIVE)
	_update_active_frame()


func begin_whirlwind_spin(direction: Vector3) -> void:
	face_direction(direction)
	pose = Pose.ACTIVE
	_burst_left = 0.0
	_set_clip(Clip.WHIRLWIND_SPIN)
	_update_active_frame()


func begin_counter_shock() -> void:
	_burst_left = 0.0
	pose = Pose.WINDUP
	_set_clip(Clip.COUNTER_SHOCK)
	_update_active_frame()


func begin_spike_burst(hold_duration: float = 1.25) -> void:
	pose = Pose.ACTIVE
	_spiky_hold_total = maxf(0.4, hold_duration)
	_burst_left = _spiky_hold_total
	_hit_clip_left = 0.0
	_set_clip(Clip.INFLATE_BURST)
	_update_active_frame()


func begin_venom_burst() -> void:
	pose = Pose.IDLE
	_burst_left = 0.36
	_hit_clip_left = 0.0
	_set_clip(Clip.VENOM_SPIT)
	windup_progress = 1.0
	_update_active_frame()


func face_direction(direction: Vector3) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if not flat.is_zero_approx():
		_facing = flat.normalized()
	_lean = -1.0 if _get_screen_direction().x < 0.0 else 1.0
	_update_active_frame()


func begin_recovery(kind: int, duration: float = RECOVERY_ANIMATION_TIME) -> void:
	airborne_height = 0.0
	_hit_clip_left = 0.0
	_burst_left = 0.0
	_recovery_duration = maxf(RECOVERY_ANIMATION_TIME, duration)
	if kind == BlubberbeardSkillData.Kind.SKY_DIVE:
		pose = Pose.RECOVERY
		_set_clip(Clip.SKYDIVE_IMPACT)
	elif kind == BlubberbeardSkillData.Kind.ANCHOR_SLAM:
		pose = Pose.RECOVERY
		_set_clip(Clip.ANCHOR_SLAM)
	elif kind == BlubberbeardSkillData.Kind.ANCHOR_WHIRLWIND:
		pose = Pose.RECOVERY
		_set_clip(Clip.WHIRLWIND_BRAKE)
	elif kind == BlubberbeardSkillData.Kind.VENOM_SPIT:
		begin_venom_burst()
	else:
		pose = Pose.IDLE
		_set_clip(Clip.MOVE if moving else Clip.IDLE)
	_update_active_frame()


func set_enraged(value: bool) -> void:
	enraged = value
	if pose == Pose.IDLE and _burst_left <= 0.0:
		_set_clip(Clip.MOVE if moving else Clip.IDLE)


func flash_hit() -> void:
	_hit_flash = HURT_FLASH_DURATION
	impact(0.16, 0.35)
	_hit_clip_duration = (
		HURT_FLASH_DURATION if pose in [Pose.WINDUP, Pose.ACTIVE] else HURT_DURATION
	)
	_hit_clip_left = _hit_clip_duration
	_update_active_frame()


func begin_staggered(duration_seconds: float) -> void:
	airborne_height = 0.0
	_hit_clip_left = 0.0
	_burst_left = 0.0
	_stagger_duration = maxf(0.2, duration_seconds)
	pose = Pose.STAGGERED
	_set_clip(Clip.STAGGERED)
	impact(0.28, 0.32)
	_update_active_frame()


func impact(power: float, duration: float) -> void:
	_impact_power = clampf(power, 0.0, 0.5)
	_impact_duration = maxf(duration, 0.01)
	_impact_left = _impact_duration


func play_death(finished: Callable) -> void:
	_dying = true
	_death_time = 0.0
	_hit_flash = 0.0
	_hit_clip_left = 0.0
	airborne_height = 0.0
	pixel_size = _rest_pixel_size
	_apply_clip_frame(Clip.DEATH, 0.0)
	var tween := create_tween()
	tween.tween_interval(0.95)
	tween.tween_property(self, "modulate:a", 0.0, 0.45).set_ease(Tween.EASE_IN)
	tween.tween_callback(finished)


func get_barrel_release_world_position() -> Vector3:
	var dir_x := -1.0 if flip_h else 1.0
	var local_offset := Vector3(
		BARREL_HAND_OFFSET_PX.x * dir_x * pixel_size, BARREL_HAND_OFFSET_PX.y * pixel_size, 0.0
	)
	return to_global(local_offset)


func get_venom_release_world_position() -> Vector3:
	var flat := Vector3(_facing.x, 0.0, _facing.z)
	if flat.is_zero_approx():
		flat = Vector3.BACK
	flat = flat.normalized()
	var root_pos := (
		(get_parent() as Node3D).global_position if get_parent() is Node3D else global_position
	)
	var ratio := _rest_pixel_size / BASE_SCENE_PIXEL_SIZE
	return root_pos + flat * (1.35 * ratio) + Vector3.UP * (2.4 * ratio)


func _set_clip(next_clip: Clip) -> void:
	if clip == next_clip:
		return
	clip = next_clip
	_clip_time = 0.0


func _update_active_frame() -> void:
	pixel_size = _rest_pixel_size
	if _hit_clip_left > 0.0 and pose in [Pose.IDLE, Pose.RECOVERY]:
		var hit_progress := 1.0 - _hit_clip_left / _hit_clip_duration
		_apply_clip_frame(Clip.HIT, hit_progress * HURT_DURATION)
		return
	_apply_clip_frame(clip, _clip_time)


func _apply_clip_frame(active_clip: Clip, time_in_clip: float) -> void:
	var dir_row := _resolve_facing_row(active_clip)
	match active_clip:
		Clip.IDLE:
			_set_sheet(IDLE_4DIR_SHEET, 4, 3)
			frame = dir_row * 4 + (int(time_in_clip * idle_fps) % 4)
		Clip.MOVE:
			_set_sheet(MOVE_4DIR_SHEET, 4, 3)
			frame = dir_row * 4 + (int(time_in_clip * move_fps) % 4)
		Clip.BARREL_THROW:
			_set_sheet(ATTACKS_SHEET, 4, 3)
			if windup_progress < 0.16:
				frame = 0
			elif windup_progress < THROW_RELEASE_PROGRESS:
				frame = 1
			elif windup_progress < 0.58:
				frame = 2
			else:
				frame = 3
		Clip.INFLATE_WINDUP:
			_set_sheet(INFLATE_4DIR_SHEET, 4, 3)
			var col := 0
			if windup_progress >= 0.90:
				col = 2
			elif windup_progress >= 0.45:
				col = 1
			frame = dir_row * 4 + col
		Clip.INFLATE_BURST:
			_set_sheet(INFLATE_4DIR_SHEET, 4, 3)
			var exhale_threshold := _spiky_hold_total * 0.8
			frame = dir_row * 4 + (2 if time_in_clip < exhale_threshold else 3)
		Clip.ANCHOR_WINDUP:
			_set_sheet(CHARGE_PREP_4DIR_SHEET, 4, 3)
			frame = dir_row * 4 + (0 if windup_progress < 0.45 else 1)
		Clip.ANCHOR_SLAM:
			_set_sheet(CHARGE_PREP_4DIR_SHEET, 4, 3)
			frame = dir_row * 4 + (2 if time_in_clip < 0.14 else 3)
		Clip.SKYDIVE_LAUNCH:
			_set_sheet(SKYDIVE_SHEET, 4, 2)
			frame = 0 if windup_progress < 0.42 else 1
		Clip.SKYDIVE_GLIDE:
			_set_sheet(SKYDIVE_SHEET, 4, 2)
			frame = 2 + (int(time_in_clip * 6.0) % 2)
		Clip.SKYDIVE_LOCK:
			_set_sheet(SKYDIVE_SHEET, 4, 2)
			frame = 4
		Clip.SKYDIVE_DIVE:
			_set_sheet(SKYDIVE_SHEET, 4, 2)
			frame = 5
		Clip.SKYDIVE_IMPACT:
			_set_sheet(SKYDIVE_SHEET, 4, 2)
			frame = 6 if time_in_clip < 0.24 else 7
		Clip.WHIRLWIND_WINDUP:
			_set_sheet(WHIRLWIND_SHEET, 4, 2)
			frame = 0
		Clip.WHIRLWIND_SPIN:
			_set_sheet(WHIRLWIND_SHEET, 4, 2)
			var idx := int(time_in_clip * whirlwind_fps) % WHIRLWIND_SPIN_FRAMES.size()
			frame = WHIRLWIND_SPIN_FRAMES[idx]
		Clip.WHIRLWIND_BRAKE, Clip.STAGGERED:
			_set_sheet(WHIRLWIND_SHEET, 4, 2)
			frame = 6 if time_in_clip < 0.22 else 7
		Clip.VENOM_SPIT:
			_set_sheet(VENOM_SPIT_4DIR_SHEET, 4, 3)
			var vcol := 0
			if _burst_left > 0.0:
				vcol = 2 if _burst_left > 0.18 else 3
			elif windup_progress >= 0.85:
				vcol = 2
			elif windup_progress >= 0.42:
				vcol = 1
			frame = dir_row * 4 + vcol
		Clip.COUNTER_SHOCK:
			_set_sheet(HIT_DEATH_SHEET, 4, 2)
			frame = 0 if int(time_in_clip * 16.0) % 2 == 0 else 1
		Clip.HIT:
			_set_sheet(HIT_DEATH_SHEET, 4, 2)
			frame = mini(3, int(time_in_clip / HURT_DURATION * 4.0))
		Clip.DEATH:
			_set_sheet(HIT_DEATH_SHEET, 4, 2)
			frame = 4 + mini(3, int(time_in_clip / 0.85 * 4.0))


func _resolve_facing_row(active_clip: Clip) -> int:
	var screen_dir := _get_screen_direction()
	_lean = -1.0 if screen_dir.x < 0.0 else 1.0
	var single_row_clips := [
		Clip.BARREL_THROW,
		Clip.SKYDIVE_LAUNCH,
		Clip.SKYDIVE_GLIDE,
		Clip.SKYDIVE_LOCK,
		Clip.SKYDIVE_DIVE,
		Clip.SKYDIVE_IMPACT,
		Clip.WHIRLWIND_WINDUP,
		Clip.WHIRLWIND_SPIN,
		Clip.WHIRLWIND_BRAKE,
		Clip.COUNTER_SHOCK,
		Clip.STAGGERED,
		Clip.HIT,
		Clip.DEATH,
	]
	if active_clip in single_row_clips:
		if active_clip in [Clip.SKYDIVE_GLIDE, Clip.WHIRLWIND_SPIN, Clip.SKYDIVE_DIVE]:
			flip_h = screen_dir.x < -0.15
		else:
			flip_h = screen_dir.x < -0.05
		return FacingDir.DOWN
	if absf(screen_dir.x) > absf(screen_dir.z):
		flip_h = screen_dir.x < 0.0
		return FacingDir.SIDE
	flip_h = false
	if screen_dir.z < 0.0:
		return FacingDir.UP
	return FacingDir.DOWN


func _get_screen_direction() -> Vector3:
	if not is_inside_tree():
		return _facing
	var viewport := get_viewport()
	var camera := viewport.get_camera_3d() if viewport != null else null
	if not is_instance_valid(camera):
		return _facing
	var camera_right: Vector3 = camera.global_basis.x
	var camera_back: Vector3 = camera.global_basis.z
	camera_right.y = 0.0
	camera_back.y = 0.0
	if camera_right.is_zero_approx() or camera_back.is_zero_approx():
		return _facing
	return Vector3(
		_facing.dot(camera_right.normalized()), 0.0, _facing.dot(camera_back.normalized())
	)


func _set_sheet(sheet: Texture2D, cols: int, rows: int) -> void:
	if texture != sheet:
		texture = sheet
	if hframes != cols:
		hframes = cols
	if vframes != rows:
		vframes = rows


func _phase_color() -> Color:
	return Color(1.0, 0.58, 0.52) if enraged else Color.WHITE
